-- Run this in your Supabase SQL Editor to set up the tables and storage

-- 1. Create employees table
CREATE TABLE IF NOT EXISTS public.employees (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role_id TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    display_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    role TEXT NOT NULL,
    department TEXT NOT NULL,
    phone TEXT,
    place TEXT,
    address TEXT,
    blood_group TEXT,
    company_number TEXT,
    date_of_joining TEXT,
    company_email TEXT,
    bank_account TEXT,
    ifsc TEXT,
    photo_url TEXT,
    is_admin BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable Row Level Security
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to view all employees
CREATE POLICY "Authenticated users can view employees"
    ON public.employees FOR SELECT
    TO authenticated
    USING (true);

-- Allow authenticated users to insert/update (this can be restricted to admins later)
CREATE POLICY "Authenticated users can update employees"
    ON public.employees FOR ALL
    TO authenticated
    USING (true);

-- 2. Set up Storage for photos
-- Note: Supabase UI is recommended for storage creation if this script fails
INSERT INTO storage.buckets (id, name, public) 
VALUES ('employee-photos', 'employee-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING (bucket_id = 'employee-photos');

CREATE POLICY "Authenticated Insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'employee-photos');

CREATE POLICY "Authenticated Update"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'employee-photos');

CREATE POLICY "Authenticated Delete"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'employee-photos');
