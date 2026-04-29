require('dotenv').config();
const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const employeeRoutes = require('./src/routes/employeeRoute');
app.use('/api/employees', employeeRoutes);

// Load routes
const authRoutes = require('./src/routes/authRoute');
const fileRoutes = require('./src/routes/fileRoute');

app.use('/api/auth', authRoutes);
app.use('/api/files', fileRoutes);

// Simple health check for Render VPS deployment
app.get('/health', (req, res) => res.status(200).json({ status: 'ok' }));

const PORT = process.env.PORT || 8000;

app.listen(PORT, () => {
    console.log(`🚀 PostgreSQL/Supabase Server running on port ${PORT}`);
});
