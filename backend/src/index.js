require('dotenv').config();
const express = require('express');
const cors    = require('cors');

const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' }));

// ── Health ────────────────────────────────────────────────────────────────────
app.get('/health', (req, res) => res.json({ status: 'ok', service: 'FaceAttend API' }));

// ── Auth ──────────────────────────────────────────────────────────────────────
app.use('/api/auth', require('./routes/auth'));

// ── Core features ─────────────────────────────────────────────────────────────
app.use('/api/face',          require('./routes/face'));
app.use('/api/attendance',    require('./routes/attendance'));

// ── New routes ────────────────────────────────────────────────────────────────
app.use('/api/organisations',  require('./routes/organisations'));
app.use('/api/invitations',    require('./routes/invitations'));
app.use('/api/users',          require('./routes/users'));
app.use('/api/classes',        require('./routes/classes'));
app.use('/api/sessions',       require('./routes/sessions'));
app.use('/api/messages',       require('./routes/messages'));
app.use('/api/notifications',  require('./routes/notifications'));
app.use('/api/dashboard',      require('./routes/dashboard'));
app.use('/api/reports',        require('./routes/reports'));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`FaceAttend API on port ${PORT}`));