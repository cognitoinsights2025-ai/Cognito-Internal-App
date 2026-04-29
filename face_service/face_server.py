"""
Cognito Face Recognition Microservice
Uses DeepFace with ArcFace model for 99.8%+ accuracy face verification.
Runs on port 5050, called by the Flutter app for face login.

STRICT MODE: No auto-pass, no fallbacks, enforce face detection.
"""

import os
import io
import base64
import requests
from flask import Flask, request, jsonify
from flask_cors import CORS
from PIL import Image
from deepface import DeepFace
from supabase import create_client, Client

app = Flask(__name__)
CORS(app)

# ── Configuration ──────────────────────────────────────────────────
MODEL_NAME = "ArcFace"       
DETECTOR_BACKEND = "retinaface"  
DISTANCE_METRIC = "cosine"   
STRICT_THRESHOLD = 0.40

# Supabase Initialization — set these via environment variables
SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://ffrlwuorwotketzkmdwo.supabase.co")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def _get_photo_path(role_id: str) -> str | None:
    # Query Supabase for the employee's photo URL
    try:
        response = supabase.table("employees").select("photo_url").eq("role_id", role_id).execute()
        if len(response.data) > 0:
            photo_url = response.data[0].get("photo_url")
            if photo_url:
                # Download the image temporarily
                temp_path = f"/tmp/{role_id}_ref.jpg"
                res = requests.get(photo_url)
                if res.status_code == 200:
                    with open(temp_path, "wb") as f:
                        f.write(res.content)
                    return temp_path
    except Exception as e:
        print(f"Error fetching photo path from Supabase for {role_id}: {e}")
    return None


def _base64_to_temp_path(b64_string: str) -> str:
    if "," in b64_string:
        b64_string = b64_string.split(",", 1)[1]
    img_data = base64.b64decode(b64_string)
    img = Image.open(io.BytesIO(img_data))
    if img.mode != "RGB":
        img = img.convert("RGB")
    temp_path = "/tmp/cognito_live_capture.jpg"
    img.save(temp_path, "JPEG", quality=95)
    return temp_path


@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "ok",
        "model": MODEL_NAME,
        "detector": DETECTOR_BACKEND,
        "strict_threshold": STRICT_THRESHOLD,
        "mode": "supabase_connected"
    })


@app.route("/verify", methods=["POST"])
def verify_face():
    """
    Verify a live captured face against the registered employee photo.
    """
    data = request.get_json()
    if not data:
        return jsonify({"error": "JSON body required"}), 400

    role_id = data.get("role_id", "").strip()
    image_b64 = data.get("image", "")

    if not role_id or not image_b64:
        return jsonify({"error": "role_id and image required"}), 400

    ref_path = _get_photo_path(role_id)
    if not ref_path:
        return jsonify({
            "verified": False,
            "distance": 1.0,
            "confidence": 0.0,
            "message": f"No reference photo for {role_id}"
        }), 404

    try:
        live_path = _base64_to_temp_path(image_b64)

        result = DeepFace.verify(
            img1_path=ref_path,
            img2_path=live_path,
            model_name=MODEL_NAME,
            detector_backend=DETECTOR_BACKEND,
            distance_metric=DISTANCE_METRIC,
            enforce_detection=True,   
            align=True,
        )

        distance = result.get("distance", 1.0)
        verified = distance <= STRICT_THRESHOLD
        confidence = max(0, (1 - distance) * 100)

        print(f"{'✅' if verified else '❌'} {role_id}: distance={distance:.4f}, confidence={confidence:.1f}%")

        # Cleanup
        if os.path.exists(live_path):
            os.remove(live_path)
        if os.path.exists(ref_path):
            os.remove(ref_path)

        return jsonify({
            "verified": verified,
            "distance": round(distance, 4),
            "threshold": STRICT_THRESHOLD,
            "confidence": round(confidence, 1),
            "model": MODEL_NAME,
            "detector": DETECTOR_BACKEND,
            "role_id": role_id,
            "message": "Face verified ✓" if verified else "Face REJECTED ✗",
        })

    except Exception as e:
        error_msg = str(e)
        print(f"❌ Error for {role_id}: {error_msg}")
        try:
            if os.path.exists("/tmp/cognito_live_capture.jpg"): os.remove("/tmp/cognito_live_capture.jpg")
            if ref_path and os.path.exists(ref_path): os.remove(ref_path)
        except: pass

        msg = "No face detected." if "face" in error_msg.lower() or "detect" in error_msg.lower() else f"Error: {error_msg}"
        return jsonify({
            "verified": False, "distance": 1.0, "threshold": STRICT_THRESHOLD,
            "confidence": 0.0, "model": MODEL_NAME, "role_id": role_id, "message": msg,
        })


@app.route("/register", methods=["POST"])
def register_face():
    """
    Register a new employee's face photo to Supabase.
    """
    data = request.get_json()
    role_id = data.get("role_id", "").strip()
    name = data.get("name", "").strip()
    image_b64 = data.get("image", "")

    if not role_id or not name or not image_b64:
        return jsonify({"error": "Missing fields"}), 400

    try:
        if "," in image_b64:
            image_b64 = image_b64.split(",", 1)[1]

        img_data = base64.b64decode(image_b64)
        img = Image.open(io.BytesIO(img_data))
        if img.mode != "RGB":
            img = img.convert("RGB")

        if img.height > 800:
            ratio = 800 / img.height
            img = img.resize((int(img.width * ratio), 800), Image.LANCZOS)

        filepath = f"/tmp/{name}.jpg"
        img.save(filepath, "JPEG", quality=95)

        # Verify a face can be detected
        try:
            DeepFace.extract_faces(
                img_path=filepath,
                detector_backend=DETECTOR_BACKEND,
                enforce_detection=True,
            )
        except Exception as face_err:
            if os.path.exists(filepath): os.remove(filepath)
            return jsonify({"success": False, "error": f"No face detected", "message": "Please upload a clear photo."}), 400

        # Upload to Supabase Storage
        file_name = f"{role_id}_{name}.jpg"
        with open(filepath, 'rb') as f:
            try:
                supabase.storage.from_("employee-photos").upload(file_name, f, {"content-type": "image/jpeg"})
            except Exception as e:
                if 'Duplicate' not in str(e): raise e

        photo_url = supabase.storage.from_("employee-photos").get_public_url(file_name)

        # Update DB record
        try:
            supabase.table("employees").update({"photo_url": photo_url}).eq("role_id", role_id).execute()
        except:
            pass # might not exist yet if added concurrently, or handle differently

        if os.path.exists(filepath): os.remove(filepath)

        return jsonify({"success": True, "role_id": role_id, "filename": file_name, "message": f"Face registered for {name}"})

    except Exception as e:
        print(f"❌ Registration error: {e}")
        return jsonify({"success": False, "error": str(e), "message": "Failed to register face"}), 500


@app.route("/preload", methods=["POST"])
def preload_model():
    try:
        DeepFace.build_model(MODEL_NAME)
        return jsonify({"status": "ok", "message": f"{MODEL_NAME} model loaded"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


if __name__ == "__main__":
    print("=" * 60)
    print("  🧠 Cognito Face Recognition Service — STRICT MODE (Supabase)")
    print("=" * 60)
    try:
        DeepFace.build_model(MODEL_NAME)
        print("✅ ArcFace model loaded!")
    except Exception as e:
        print(f"⚠️  Model pre-load: {e}")
    app.run(host="0.0.0.0", port=5050, debug=False)
