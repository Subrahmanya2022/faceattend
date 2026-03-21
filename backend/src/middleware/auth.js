const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASS
});

const authenticateToken = async (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Token required' });
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const result = await pool.query('SELECT * FROM users WHERE id = $1', [decoded.userId]);
    if (result.rows.length === 0) return res.status(401).json({ error: 'Invalid token' });
    req.user = result.rows[0];
    next();
  } catch {
    res.status(403).json({ error: 'Invalid token' });
  }
};

module.exports = { authenticateToken };
