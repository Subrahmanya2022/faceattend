require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { pool } = require('./db');
const authRoutes = require('./routes/auth');
const faceRoutes = require('./routes/face');


const app = express();
app.use(cors());

app.use(express.json({ limit: '50mb' }));

app.get('/health', (req, res) => res.json({ status: 'FaceAttend API LIVE' }));
app.use('/api/auth', authRoutes);
app.use('/api/face', faceRoutes);
app.use('/api/attendance', require('./routes/attendance'));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 FaceAttend API on port ${PORT}`);
});
