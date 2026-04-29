const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const multer = require('multer');
const xlsx = require('xlsx');

// Multer setup for file uploads (Excel & face image)
const upload = multer({ storage: multer.memoryStorage() });

/**
 * POST /api/employees/import
 * Accepts the "Cognito Employee Details.xlsx" file.
 * Parses all 3 sheets: IT, NON-IT, Intern
 * Each sheet has slightly different column headers — handled below.
 * Upserts each employee into the `users` table.
 */
router.post('/import', upload.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).json({ message: 'Excel file required' });
  try {
    const workbook = xlsx.read(req.file.buffer, { type: 'buffer' });
    const bcrypt = require('bcryptjs');
    const allResults = [];

    // ── Photo filename → role_id mapping for face sync ──────────────
    const photoMap = {
      '2603IT01': 'Alugolu Eswara Satya Dattathreya.jpg',
      '2603IT02': 'Bonam Bharathi.jpg',
      '2603IT03': 'Surapaneni Eswara Sai Teja.jpg',
      '2602NT01': 'Gulimi Mounika.jpg',
      '2602NT02': null,  // Gonna Bhanuprakash — no photo provided
      '2604NT03': 'Keerthi Priyanka.jpg',
      '2604IN01': 'Burra Phanindra.jpg',
      '2604IN02': 'Boddu Aravind.jpg',
      '2604IN03': 'Pillanam Veera Kumar.jpg',
      '2604IN04': 'Patta Kanchana.jpg',
      '2604IN05': 'Barre Syam surya venkata sai kumar.jpg',
      '2604IN06': 'Pindi Tarun Simhachalam.jpg',
    };

    for (const sheetName of workbook.SheetNames) {
      const sheet = workbook.Sheets[sheetName];
      const rows = xlsx.utils.sheet_to_json(sheet, { header: 1 });

      if (rows.length < 2) continue; // Skip empty sheets

      // Determine department from sheet name
      let department = 'IT';
      if (sheetName.toUpperCase().includes('NON')) department = 'Non-IT';
      else if (sheetName.toUpperCase().includes('INTERN')) department = 'Intern';

      // Get header row (row 0)
      const headers = rows[0].map(h => (h || '').toString().trim().toUpperCase());

      // Find column indices by header name
      const findCol = (keywords) => headers.findIndex(h =>
        keywords.some(kw => h.includes(kw.toUpperCase()))
      );

      const colName = findCol(['NAME OF EMPLOYE', 'NAME']);
      const colDOJ = findCol(['DATE OF JOINING']);
      const colRole = findCol(['ROLE']);
      const colId = findCol(['ID']);
      const colPlace = findCol(['PLACE']);
      const colAddress = findCol(['ADDRESS']);
      const colPhone = findCol(['PHONE NUMBER']);
      const colBlood = findCol(['BLOOD GROUP']);
      const colEmail = findCol(['EMAIL', 'E- MAIL', 'E-MAIL']);
      const colCompNum = findCol(['COMPANY NUMBER']);
      const colBankAcc = findCol(['BANK ACCOUNT']);
      const colIfsc = findCol(['IFSC']);

      // Process data rows (skip header)
      for (let i = 1; i < rows.length; i++) {
        const row = rows[i];
        if (!row || row.length === 0 || !row[0]) continue; // skip empty rows

        const roleId = (colId >= 0 ? (row[colId] || '') : '').toString().trim();
        if (!roleId) continue;

        const name = (colName >= 0 ? (row[colName] || '') : '').toString().trim();
        if (!name) continue;

        const passwordHash = await bcrypt.hash('Cognito@111', 10);
        const phone = (colPhone >= 0 ? (row[colPhone] || '') : '').toString().trim();
        const place = (colPlace >= 0 ? (row[colPlace] || '') : '').toString().trim();
        const address = (colAddress >= 0 ? (row[colAddress] || '') : '').toString().trim();
        const bloodGroup = (colBlood >= 0 ? (row[colBlood] || '') : '').toString().trim();
        const companyNumber = (colCompNum >= 0 ? (row[colCompNum] || '') : '').toString().trim();
        const emailRaw = (colEmail >= 0 ? (row[colEmail] || '') : '').toString().trim();
        const bankAccount = (colBankAcc >= 0 ? (row[colBankAcc] || '') : '').toString().trim();
        const ifsc = (colIfsc >= 0 ? (row[colIfsc] || '') : '').toString().trim();

        // Handle role — in NON-IT sheet, role & DOJ columns are swapped
        let role = department === 'Intern' ? 'Intern' : '';
        let dateOfJoining = null;

        if (department === 'Non-IT') {
          // NON-IT sheet has: S.NO, NAME, Date of Joining, Role, ID...
          // But the data shows Role and DOJ are in swapped positions
          const dojRaw = (colDOJ >= 0 ? (row[colDOJ] || '') : '').toString().trim();
          const roleRaw = (colRole >= 0 ? (row[colRole] || '') : '').toString().trim();
          
          // Check which one looks like a date
          if (dojRaw && !dojRaw.match(/^\d{2}-\d{2}-\d{4}$/) && !dojRaw.match(/^\d+$/)) {
            // DOJ column contains the role name
            role = dojRaw;
            // Role column contains the date (as serial or string)
            if (roleRaw) {
              const serial = parseInt(roleRaw);
              if (serial > 40000) {
                // Excel date serial number
                const epoch = new Date(1900, 0, serial - 1);
                dateOfJoining = epoch;
              } else {
                dateOfJoining = new Date(roleRaw);
              }
            }
          } else {
            role = roleRaw;
            if (dojRaw) dateOfJoining = new Date(dojRaw);
          }
        } else if (department === 'IT') {
          role = (colRole >= 0 ? (row[colRole] || '') : '').toString().trim();
          const dojRaw = (colDOJ >= 0 ? (row[colDOJ] || '') : '').toString().trim();
          if (dojRaw) dateOfJoining = new Date(dojRaw);
        } else {
          // Intern sheet — DOJ can be date string or serial
          const dojRaw = (colDOJ >= 0 ? (row[colDOJ] || '') : '').toString().trim();
          if (dojRaw) {
            const serial = parseInt(dojRaw);
            if (serial > 40000) {
              const epoch = new Date(1900, 0, serial - 1);
              dateOfJoining = epoch;
            } else {
              dateOfJoining = new Date(dojRaw);
            }
          }
        }

        // Parse email — some cells contain multiple emails separated by spaces
        const emails = emailRaw.split(/\s+/).filter(e => e.includes('@'));
        const primaryEmail = emails.find(e => e.includes('cognito.')) || emails[0] || '';
        const companyEmail = emails.find(e => e.includes('cognitoinsights')) || '';

        // Photo URL from mapping
        const photoFilename = photoMap[roleId.toUpperCase()] || null;
        const photoUrl = photoFilename
            ? `employees/${photoFilename}`
            : null;

        const userData = {
          role_id: roleId,
          name,
          display_name: name.split(' ').slice(-2).join(' ') || name,
          email: primaryEmail,
          password: passwordHash,
          role: role || department,
          department,
          phone,
          place,
          address,
          blood_group: bloodGroup,
          company_number: companyNumber,
          date_of_joining: dateOfJoining,
          company_email: companyEmail || null,
          photo_url: photoUrl,
          is_admin: false,
        };

        const { data, error } = await supabase
          .from('users')
          .upsert(userData, { onConflict: 'role_id' });

        if (error) {
          console.error(`Error upserting ${roleId}:`, error.message);
        } else {
          allResults.push({ roleId, name, department, status: 'ok' });
        }
      }
    }

    res.json({
      message: `Imported ${allResults.length} employees across ${workbook.SheetNames.length} sheets`,
      sheets: workbook.SheetNames,
      employees: allResults,
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: 'Import failed', error: e.message });
  }
});

/**
 * GET /api/employees
 * Returns all employees, grouped by department.
 */
router.get('/', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('users')
      .select('id, role_id, name, display_name, email, role, department, phone, place, address, blood_group, company_number, date_of_joining, company_email, photo_url, is_admin, face_embedding')
      .order('department')
      .order('role_id');

    if (error) throw error;

    // Group by department
    const grouped = {
      IT: data.filter(u => u.department === 'IT'),
      'Non-IT': data.filter(u => u.department === 'Non-IT'),
      Intern: data.filter(u => u.department === 'Intern'),
    };

    res.json({ employees: data, grouped, total: data.length });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: 'Failed to fetch employees', error: e.message });
  }
});

/**
 * GET /api/employees/department/:dept
 * Returns employees for a specific department (IT, Non-IT, Intern).
 */
router.get('/department/:dept', async (req, res) => {
  try {
    const dept = req.params.dept;
    const { data, error } = await supabase
      .from('users')
      .select('id, role_id, name, display_name, email, role, department, phone, place, photo_url, face_embedding')
      .eq('department', dept)
      .order('role_id');

    if (error) throw error;
    res.json({ department: dept, employees: data, count: data.length });
  } catch (e) {
    res.status(500).json({ message: 'Failed to fetch department', error: e.message });
  }
});

/**
 * POST /api/employees/face/:roleId
 * Stores a facial embedding vector for the employee by role_id.
 * Expected body: { embedding: [float, ...] }  // length 192
 */
router.post('/face/:roleId', async (req, res) => {
  const roleId = req.params.roleId;
  const { embedding } = req.body;
  if (!Array.isArray(embedding) || embedding.length === 0) {
    return res.status(400).json({ message: 'Embedding array required (192 dimensions)' });
  }
  if (embedding.length !== 192) {
    return res.status(400).json({ message: `Expected 192 dimensions, got ${embedding.length}` });
  }

  try {
    const embeddingString = `[${embedding.join(',')}]`;
    const { error } = await supabase
      .from('users')
      .update({ face_embedding: embeddingString })
      .eq('role_id', roleId);

    if (error) throw error;
    res.json({ success: true, message: `Face embedding saved for ${roleId}` });
  } catch (e) {
    res.status(500).json({ message: 'Failed to store embedding', error: e.message });
  }
});

/**
 * GET /api/employees/:roleId
 * Returns employee data by role_id (excluding password).
 */
router.get('/:roleId', async (req, res) => {
  const roleId = req.params.roleId;
  try {
    const { data: user, error } = await supabase
      .from('users')
      .select('id, role_id, name, display_name, email, role, department, phone, place, address, blood_group, company_number, date_of_joining, company_email, photo_url, is_admin, face_embedding')
      .eq('role_id', roleId)
      .single();

    if (error) return res.status(404).json({ message: 'Employee not found' });
    res.json({ employee: user });
  } catch (e) {
    res.status(500).json({ message: 'Failed to fetch employee', error: e.message });
  }
});

/**
 * GET /api/employees/face-status/all
 * Returns face registration status for all employees.
 * Used by admin dashboard to verify face sync consistency.
 */
router.get('/face-status/all', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('users')
      .select('role_id, name, department, photo_url, face_embedding')
      .eq('is_admin', false)
      .order('department')
      .order('role_id');

    if (error) throw error;

    const status = data.map(u => ({
      roleId: u.role_id,
      name: u.name,
      department: u.department,
      hasPhoto: !!u.photo_url,
      hasFaceEmbedding: !!u.face_embedding && u.face_embedding.length > 0,
      photoFile: u.photo_url,
    }));

    const summary = {
      total: status.length,
      withPhoto: status.filter(s => s.hasPhoto).length,
      withEmbedding: status.filter(s => s.hasFaceEmbedding).length,
      fullyRegistered: status.filter(s => s.hasPhoto && s.hasFaceEmbedding).length,
    };

    res.json({ status, summary });
  } catch (e) {
    res.status(500).json({ message: 'Failed to fetch face status', error: e.message });
  }
});

module.exports = router;
