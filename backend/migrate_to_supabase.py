import os
import mimetypes
from supabase import create_client, Client

# --- Configuration ---
# Set SUPABASE_SERVICE_KEY env var before running: export SUPABASE_SERVICE_KEY="your-key"
SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://ffrlwuorwotketzkmdwo.supabase.co")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")
BUCKET_NAME = "employee-photos"

# Ensure you are running this from the backend folder
PHOTOS_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "cognito_app", "assets", "images", "employees"
)

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Hardcoded data from AuthService
EMPLOYEES = [
    {
        "name": "Alugolu Eswara Satya Dattathreya", "displayName": "Satya Dattathreya", "email": "cognito.2603it01@gmail.com",
        "roleId": "2603IT01", "role": "Tech Lead", "department": "IT", "phone": "9347989890", "place": "Pithapuram",
        "address": "2-1-106/b, Agraharam, Pithapuram", "bloodGroup": "B+", "companyNumber": "8309913259",
        "dateOfJoining": "23-03-2026", "companyEmail": "satya.alugolu@cognitoinsights.tech", "bankAccount": "10209905953",
        "ifsc": "IDFB0081036", "photoAsset": "Alugolu Eswara Satya Dattathreya.jpg"
    },
    {
        "name": "Bonam Bharathi", "displayName": "Bonam Bharathi", "email": "cognito.2603it02@gmail.com",
        "roleId": "2603IT02", "role": "Support Developer", "department": "IT", "phone": "8465057123", "place": "Amalapuram",
        "address": "Door no - 2-25, Mamidikudurru, nagaram, Dr B.R.ambedkar Konaseema, AP", "bloodGroup": "O+", "companyNumber": "8328614232",
        "dateOfJoining": "23-03-2026", "companyEmail": "bonam.bharathi@cognitoinsights.tech", "bankAccount": "18198100004136",
        "ifsc": "BARB0APPANA", "photoAsset": "Bonam Bharathi.jpg"
    },
    {
        "name": "Surapaneni Eswara Sai Teja", "displayName": "Sai Teja", "email": "cognito.2604it03@gmail.com",
        "roleId": "2603IT03", "role": "Support Developer", "department": "IT", "phone": "709793789", "place": "Rajahmundry",
        "address": "69-27-4, Gandhipuram-4, lalacheruvu, opposite sindhur express car wash", "bloodGroup": "B+", "companyNumber": "7013497025",
        "dateOfJoining": "29-03-2026", "companyEmail": "teja.surapaneni@cognitoinsights.tech", "bankAccount": "926010009588967",
        "ifsc": "UTIB0002978", "photoAsset": "Surapaneni Eswara Sai Teja.jpg"
    },
    {
        "name": "Gonna Bhanuprakash", "displayName": "Bhanuprakash", "email": "cognito.2602nt02@gmail.com",
        "roleId": "2602NT02", "role": "R&D", "department": "Non-IT", "phone": "7671032823", "place": "Dowleswaram",
        "address": "Door no - 18-567, Yerrakonda, Nethajinagar-2, Dowlaiswaram, Rajamanhendravaram Rural, East godavari, AP", "bloodGroup": "B+", "companyNumber": "8328083753",
        "dateOfJoining": "20-02-2026", "companyEmail": "prakash.gonna@cognitoinsights.ai", "bankAccount": "010410100183708",
        "ifsc": "UBIN0801046", "photoAsset": "Gonna Bhanuprakash.jpg"
    },
    {
        "name": "Gulimi Mounika", "displayName": "Gulimi Mounika", "email": "cognito.2602nt01@gmail.com",
        "roleId": "2602NT01", "role": "Front Desk Officer", "department": "Non-IT", "phone": "6300032320", "place": "Rajahmundry",
        "address": "Door no - 4-23/6, rajeswari convent street, danavari peta, chagallu, East Godavari, AP", "bloodGroup": "O+", "companyNumber": "7989924436",
        "dateOfJoining": "01-02-2026", "companyEmail": "mounika.gulimi@cognitoinsights.ai", "bankAccount": "010010100099940",
        "ifsc": "UBIN0801003", "photoAsset": "Gulimi Mounika.jpg"
    },
    {
        "name": "Keerthi Priyanka", "displayName": "Keerthi Priyanka", "email": "cognito.2604nt03@gmail.com",
        "roleId": "2604NT03", "role": "Digital Marketer", "department": "Non-IT", "phone": "7981963860", "place": "Rajahmundry",
        "address": "Door no - 50-5-11, Nehru Nagar, Rajahmundry, East Godavari, AP", "bloodGroup": "O+", "companyNumber": "7989925188",
        "dateOfJoining": "03-04-2026", "companyEmail": "cognito.2604nt03@gmail.com", "bankAccount": "35279368375",
        "ifsc": "SBIN0010785", "photoAsset": "Keerthi Priyanka.jpg"
    },
    {
        "name": "Burra Phanindra", "displayName": "Burra Phanindra", "email": "cognito.2604in01@gmail.com",
        "roleId": "2604IN01", "role": "Intern", "department": "Intern", "phone": "9908435356", "place": "Rajahmundry",
        "address": "Door no - 1-16-6, Dharvada veedhi, rajamhmundry rural, East godavari, AP", "bloodGroup": "B+", "companyNumber": "8919070994",
        "dateOfJoining": "01-04-2026", "companyEmail": "cognito.2604in01@gmail.com", "photoAsset": "Burra Phanindra.jpg", "bankAccount": "", "ifsc": ""
    },
    {
        "name": "Boddu Aravind", "displayName": "Boddu Aravind", "email": "cognito.2604in02@gmail.com",
        "roleId": "2604IN02", "role": "Intern", "department": "Intern", "phone": "9392806950", "place": "Rajahmundry",
        "address": "Door no- 89-2-5/1 opp.swimming pool road, gayatri nagar morampudi(rural) east godavari", "bloodGroup": "B+", "companyNumber": "7989553138",
        "dateOfJoining": "01-04-2026", "companyEmail": "cognito.2604in02@gmail.com", "bankAccount": "140112010000999",
        "ifsc": "UBIN0814016", "photoAsset": "Boddu Aravind.jpg"
    },
    {
        "name": "Pillanam Veera Kumar", "displayName": "Veera Kumar", "email": "cognito.2604in03@gmail.com",
        "roleId": "2604IN03", "role": "Intern", "department": "Intern", "phone": "7981264265", "place": "Rajahmundry",
        "address": "Door no - 43-14-15/1, syamalamba temple street, geeta apsara, rajamandry arban, East godavari, AP", "bloodGroup": "O+", "companyNumber": "8919056966",
        "dateOfJoining": "01-04-2026", "companyEmail": "cognito.2604in03@gmail.com", "photoAsset": "Pillanam Veera Kumar.jpg", "bankAccount": "", "ifsc": ""
    },
    {
        "name": "Patta Kanchana", "displayName": "Patta Kanchana", "email": "cognito.2604in04@gmail.com",
        "roleId": "2604IN04", "role": "Intern", "department": "Intern", "phone": "8096053599", "place": "Kakinada",
        "address": "Door no - 3-55/1 ramannapalem, tallarevu, patavala, kakinada, AP", "bloodGroup": "A+", "companyNumber": "7989548005",
        "dateOfJoining": "03-04-2026", "companyEmail": "cognito.2604in04@gmail.com", "photoAsset": "Patta Kanchana.jpg", "bankAccount": "", "ifsc": ""
    },
    {
        "name": "Barre Syam Surya Venkata Sai Kumar", "displayName": "Sai Kumar", "email": "cognito.2604in05@gmail.com",
        "roleId": "2604IN05", "role": "Intern", "department": "Intern", "phone": "7337262831", "place": "Razole",
        "address": "Door no - 5-58 Appaniramunilanka, pallipalem, sakhinetipalle, Razole, A.P, 533252", "bloodGroup": "O+", "companyNumber": "",
        "dateOfJoining": "20-04-2026", "companyEmail": "cognito.2604in05@gmail.com", "photoAsset": "Barre Syam surya venkata sai kumar.jpg", "bankAccount": "", "ifsc": ""
    },
    {
        "name": "Pindi Tarun Simhachalam", "displayName": "Tarun Simhachalam", "email": "cognito.2604in06@gmail.com",
        "roleId": "2604IN06", "role": "Intern", "department": "Intern", "phone": "9492231892", "place": "Narisipatnam",
        "address": "Door no- 5-31, K.U.Gudem Village, Narsipatnam, Amalapuram post, AP, 531117", "bloodGroup": "O+", "companyNumber": "",
        "dateOfJoining": "20-04-2026", "companyEmail": "cognito.2604in06@gmail.com", "photoAsset": "Pindi Tarun Simhachalam.jpg", "bankAccount": "", "ifsc": ""
    },
    {
        "name": "Rugada Mayuri", "displayName": "Rugada Mayuri", "email": "cognito.2604in07@gmail.com",
        "roleId": "2604IN07", "role": "Intern", "department": "Intern", "phone": "", "place": "",
        "address": "", "bloodGroup": "Unknown", "companyNumber": "",
        "dateOfJoining": "28-04-2026", "companyEmail": "cognito.2604in07@gmail.com", "photoAsset": "Rugada Mayuri.jpg", "bankAccount": "", "ifsc": ""
    },
    {
        "name": "Admin", "displayName": "Administrator", "email": "cognitoinsights2025@gmail.com",
        "roleId": "ADMIN", "role": "Administrator", "department": "Management", "phone": "+91 90000 00000", "place": "Amalapuram",
        "address": "Cognito Insights Solutions Pvt Ltd, Amalapuram, E.G. Dist., AP – 533201", "bloodGroup": "", "companyNumber": "",
        "dateOfJoining": "01/01/2024", "companyEmail": "admin@cognitoinsights.in", "photoAsset": None, "bankAccount": "", "ifsc": "",
        "isAdmin": True
    }
]

def migrate():
    print("Starting migration to Supabase...")
    for emp in EMPLOYEES:
        # 1. Upload photo to storage
        photo_url = None
        if emp.get("photoAsset"):
            photo_path = os.path.join(PHOTOS_DIR, emp["photoAsset"])
            if os.path.exists(photo_path):
                file_name = f"{emp['roleId']}_{emp['photoAsset']}"
                mime_type, _ = mimetypes.guess_type(photo_path)
                with open(photo_path, 'rb') as f:
                    print(f"Uploading {file_name}...")
                    try:
                        # Upload to Supabase Storage
                        supabase.storage.from_(BUCKET_NAME).upload(
                            path=file_name,
                            file=f,
                            file_options={"content-type": mime_type}
                        )
                    except Exception as e:
                        if 'Duplicate' not in str(e):
                            print(f"Failed to upload {file_name}: {e}")
                
                # Get public URL
                res = supabase.storage.from_(BUCKET_NAME).get_public_url(file_name)
                photo_url = res
            else:
                print(f"Photo not found locally: {photo_path}")

        # 2. Create Auth User
        password = "Cognito@111"
        if emp.get("isAdmin"):
            password = "Cognito@2025"

        try:
            auth_res = supabase.auth.admin.create_user({
                "email": emp["email"],
                "password": password,
                "email_confirm": True
            })
            user_id = auth_res.user.id
            print(f"Created Auth User for {emp['email']}")
        except Exception as e:
            # Maybe user already exists, let's list users and find the ID
            print(f"User {emp['email']} might exist: {e}")
            try:
                # Assuming the user was already created, we skip, or we should fetch them.
                # The python admin API list_users() returns a page.
                users = supabase.auth.admin.list_users()
                user_id = next((u.id for u in users if u.email == emp["email"]), None)
                if not user_id:
                    print(f"Could not find user ID for {emp['email']}.")
                    continue
            except Exception as inner_e:
                 print(f"Could not fetch user ID for {emp['email']}: {inner_e}")
                 continue

        # 3. Insert into public.employees
        record = {
            "id": user_id,
            "role_id": emp["roleId"],
            "name": emp["name"],
            "display_name": emp["displayName"],
            "email": emp["email"],
            "role": emp["role"],
            "department": emp["department"],
            "phone": emp["phone"],
            "place": emp["place"],
            "address": emp["address"],
            "blood_group": emp["bloodGroup"],
            "company_number": emp["companyNumber"],
            "date_of_joining": emp["dateOfJoining"],
            "company_email": emp["companyEmail"],
            "bank_account": emp.get("bankAccount"),
            "ifsc": emp.get("ifsc"),
            "photo_url": photo_url,
            "is_admin": emp.get("isAdmin", False)
        }

        print(f"Inserting DB record for {emp['roleId']}...")
        try:
            supabase.table("employees").upsert(record).execute()
        except Exception as e:
            print(f"Failed to insert record for {emp['roleId']}: {e}")

    print("Migration complete!")

if __name__ == "__main__":
    migrate()
