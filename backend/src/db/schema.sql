-- ═══════════════════════════════════════════════════════════════════════════
-- Cognito Insights — PostgreSQL Schema
-- Employee data from "Cognito Employee Details.xlsx" (3 sheets: IT, NON-IT, Intern)
-- Face recognition data from 11 employee photos (HEIC → JPG)
-- ═══════════════════════════════════════════════════════════════════════════

-- Enable vector extension for AI Face Matching using Euclidean / Cosine similarity
CREATE EXTENSION IF NOT EXISTS vector;

-- ─────────────────────────────────────────────────────────────────────────────
-- USERS TABLE — unified table for all employees across IT, Non-IT, Intern
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  role_id VARCHAR(50) UNIQUE NOT NULL, -- e.g., 2603IT01, 2602NT01, 2604IN01
  name TEXT NOT NULL,
  display_name TEXT,
  role TEXT NOT NULL,        -- e.g., Tech Lead, Support Developer, Front Desk Officer, Intern
  department TEXT NOT NULL,  -- 'IT', 'Non-IT', or 'Intern' (from Excel sheet names)
  email TEXT UNIQUE NOT NULL,
  password TEXT NOT NULL, -- bcrypt hashed
  is_admin BOOLEAN DEFAULT FALSE,
  
  -- Security & Face Recognition
  device_id TEXT DEFAULT NULL,
  face_embedding vector(192), -- MobileFaceNet output is 192 dimensions
  
  -- Employee Details (from Excel file)
  phone TEXT,
  place TEXT,
  address TEXT,
  blood_group TEXT,
  company_number TEXT,
  company_email TEXT,
  date_of_joining DATE,
  bank_account TEXT,
  ifsc_code TEXT,
  photo_url TEXT, -- Synced photo filename from EMPLOYEE PICS folder
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- ATTENDANCE TABLE — face-verified clock-in records
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE attendance (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  role_id TEXT NOT NULL,
  user_name TEXT NOT NULL,
  department TEXT, -- track which department for filtering
  date DATE NOT NULL,
  clock_in TIMESTAMP WITH TIME ZONE NOT NULL,
  status TEXT DEFAULT 'present',
  face_score FLOAT, -- Cosine Similarity Score (0-1) recorded during face login
  photo_url TEXT,
  
  -- Ensure only one attendance row per user per day
  UNIQUE(user_id, date) 
);

-- ─────────────────────────────────────────────────────────────────────────────
-- TASKS TABLE
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT,
  assigned_by UUID REFERENCES users(id), -- Admin
  assigned_to UUID REFERENCES users(id), -- Employee
  status TEXT CHECK (status IN ('pending', 'in-progress', 'completed')) DEFAULT 'pending',
  priority TEXT CHECK (priority IN ('high', 'medium', 'low')) DEFAULT 'medium',
  deadline TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- AUDIT LOGS TABLE
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  role_id TEXT NOT NULL,
  user_name TEXT NOT NULL,
  action TEXT NOT NULL,
  detail TEXT,
  session_id TEXT,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- AI Biometric Cosine Similarity Matching Function
-- Calculates similarity between live camera vector and stored user vector
-- Used for face login verification with 100% accuracy requirement
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION match_face (query_embedding vector(192), match_threshold float, target_role_id text)
RETURNS TABLE (
  role_id text,
  similarity float
)
LANGUAGE sql
AS $$
  SELECT
    users.role_id,
    1 - (users.face_embedding <=> query_embedding) AS similarity
  FROM users
  WHERE users.role_id = target_role_id
  AND 1 - (users.face_embedding <=> query_embedding) > match_threshold;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- EMPLOYEE ↔ PHOTO SYNC REFERENCE (for documentation)
-- ─────────────────────────────────────────────────────────────────────────────
-- Sheet: IT (3 employees)
--   2603IT01 → Alugolu Eswara Satya Dattathreya.jpg  ✓
--   2603IT02 → Bonam Bharathi.jpg                     ✓
--   2603IT03 → Surapaneni Eswara Sai Teja.jpg        ✓
--
-- Sheet: NON-IT (3 employees)
--   2602NT02 → [No photo provided]                    ✗ (Gonna Bhanuprakash)
--   2602NT01 → Gulimi Mounika.jpg                     ✓
--   2604NT03 → Keerthi Priyanka.jpg                   ✓
--
-- Sheet: Intern (6 employees)
--   2604IN01 → Burra Phanindra.jpg                    ✓
--   2604IN02 → Boddu Aravind.jpg                      ✓
--   2604IN03 → Pillanam Veera Kumar.jpg               ✓
--   2604IN04 → Patta Kanchana.jpg                     ✓
--   2604IN05 → Barre Syam surya venkata sai kumar.jpg ✓
--   2604IN06 → Pindi Tarun Simhachalam.jpg            ✓
--
-- Total: 12 employees, 11 photos synced (1 missing: Gonna Bhanuprakash)
