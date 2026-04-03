const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { pool } = require('../db');

router.post('/register', async (req, res) => {
  try {
    const { name, email, password, role = 'student' } = req.body;
    
    const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
    if (existing.rows.length > 0) {
      return res.status(400).json({ error: 'User already exists' });
    }
    
    const hashed = await bcrypt.hash(password, 10);
    const user = await pool.query(
      'INSERT INTO users (name, email, password, role) VALUES ($1, $2, $3, $4) RETURNING id, name, email, role',
      [name, email, hashed, role]
    );
    
    const token = jwt.sign({ userId: user.rows[0].id }, process.env.JWT_SECRET || 'faceattend2026');
    
    res.json({ user: user.rows[0], token });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    const user = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (user.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid email' });
    }
    const valid = await bcrypt.compare(password, user.rows[0].password_hash || user.rows[0].password);

    if (!valid) {
      return res.status(401).json({ error: 'Invalid password' });
    }
    
    
    const token = jwt.sign({ userId: user.rows[0].id }, process.env.JWT_SECRET || 'faceattend2026');
    
    res.json({
      user: { id: user.rows[0].id, name: user.rows[0].name, email: user.rows[0].email, role: user.rows[0].role },
      token
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
