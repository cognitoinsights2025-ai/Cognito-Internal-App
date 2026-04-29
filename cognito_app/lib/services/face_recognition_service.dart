import 'dart:convert';
import 'package:http/http.dart' as http;

/// Client for the Cognito Face Recognition microservice (Python/ArcFace).
/// Communicates with the face_service running on localhost:5050.
class FaceRecognitionService {
  static final FaceRecognitionService _instance = FaceRecognitionService._();
  factory FaceRecognitionService() => _instance;
  FaceRecognitionService._();

  /// Base URL of the Python face recognition service
  static const String _baseUrl = 'http://localhost:5050';

  /// Verify a captured face against the registered employee photo.
  ///
  /// Returns a [FaceVerifyResult] with verified status, confidence score, etc.
  /// The [imageBase64] should be a base64-encoded JPEG of the captured frame.
  Future<FaceVerifyResult> verifyFace({
    required String roleId,
    required String imageBase64,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'role_id': roleId,
          'image': imageBase64,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return FaceVerifyResult(
          verified: data['verified'] ?? false,
          confidence: (data['confidence'] ?? 0.0).toDouble(),
          distance: (data['distance'] ?? 1.0).toDouble(),
          threshold: (data['threshold'] ?? 0.68).toDouble(),
          model: data['model'] ?? 'ArcFace',
          message: data['message'] ?? '',
        );
      } else if (response.statusCode == 404) {
        return FaceVerifyResult(
          verified: false,
          confidence: 0.0,
          distance: 1.0,
          threshold: 0.68,
          model: 'ArcFace',
          message: 'No reference photo registered for this employee',
        );
      } else {
        final data = jsonDecode(response.body);
        return FaceVerifyResult(
          verified: false,
          confidence: 0.0,
          distance: 1.0,
          threshold: 0.68,
          model: 'ArcFace',
          message: data['message'] ?? 'Verification failed',
        );
      }
    } catch (e) {
      return FaceVerifyResult(
        verified: false,
        confidence: 0.0,
        distance: 1.0,
        threshold: 0.68,
        model: 'ArcFace',
        message: 'Face service unavailable: $e',
        serviceError: true,
      );
    }
  }

  /// Check if the face recognition service is running.
  Future<bool> isServiceAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Register a new employee's face photo for recognition.
  /// Returns a map with 'success' (bool) and 'message' (String).
  Future<Map<String, dynamic>> registerFace({
    required String roleId,
    required String name,
    required String imageBase64,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'role_id': roleId,
          'name': name,
          'image': imageBase64,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      return {
        'success': data['success'] == true,
        'message': data['message'] ?? 'Unknown result',
        'filename': data['filename'] ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Face service unavailable: $e',
      };
    }
  }
}

/// Result of a face verification attempt.
class FaceVerifyResult {
  final bool verified;
  final double confidence;  // 0-100% (100 = identical)
  final double distance;    // 0-1 cosine distance (0 = identical)
  final double threshold;   // ArcFace threshold
  final String model;       // Model used (ArcFace)
  final String message;     // Human-readable result
  final bool serviceError;  // True if the service was unreachable

  const FaceVerifyResult({
    required this.verified,
    required this.confidence,
    required this.distance,
    required this.threshold,
    required this.model,
    required this.message,
    this.serviceError = false,
  });
}
