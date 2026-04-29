const { createClient } = require('@supabase/supabase-js');

// Create a single supabase client for interacting with your database
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY; // Requires service_role key to bypass RLS in the server

if (!supabaseUrl || !supabaseServiceKey) {
    console.warn("⚠️ SUPABASE_URL or SUPABASE_SERVICE_KEY is missing. Supabase not connected.");
}

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
    auth: {
        autoRefreshToken: false,
        persistSession: false
    }
});

module.exports = supabase;
