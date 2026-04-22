const express = require('express');
const router  = express.Router();
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');

function requireRole(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: `Access denied. Required: ${roles.join(' or ')}` });
    }
    next();
  };
}

// GET /api/organisations — superadmin sees all, admin sees own
router.get('/', authenticateToken, async (req, res) => {
  try {
    let result;
    if (req.user.role === 'superadmin') {
      result = await pool.query(
        `SELECT o.*, 
           COUNT(DISTINCT u.id) FILTER (WHERE u.role='admin')   AS admin_count,
           COUNT(DISTINCT u.id) FILTER (WHERE u.role='teacher') AS teacher_count,
           COUNT(DISTINCT u.id) FILTER (WHERE u.role='student') AS student_count
         FROM organisations o
         LEFT JOIN users u ON u.org_id = o.id
         GROUP BY o.id
         ORDER BY o.created_at DESC`
      );
    } else if (req.user.role === 'admin') {
      result = await pool.query(
        'SELECT * FROM organisations WHERE id=$1',
        [req.user.org_id]
      );
    } else {
      return res.status(403).json({ error: 'Access denied' });
    }
    res.json({ organisations: result.rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/organisations — superadmin creates org + admin account
router.post('/', authenticateToken, requireRole('superadmin'), async (req, res) => {
  const client = await pool.connect();
  try {
    const { name, address, email, phone, adminName, adminEmail, adminPassword } = req.body;
    if (!name || !email || !adminName || !adminEmail || !adminPassword) {
      return res.status(400).json({ error: 'name, email, adminName, adminEmail, adminPassword required' });
    }
    await client.query('BEGIN');

    const org = await client.query(
      'INSERT INTO organisations (name, address, email, phone) VALUES ($1,$2,$3,$4) RETURNING *',
      [name, address, email, phone]
    );

    const bcrypt = require('bcrypt');
    const hash   = await bcrypt.hash(adminPassword, 12);
    const admin  = await client.query(
      `INSERT INTO users (name, email, password_hash, role, org_id, is_active, joined_at)
       VALUES ($1,$2,$3,'admin',$4,TRUE,NOW()) RETURNING id, name, email, role`,
      [adminName, adminEmail, hash, org.rows[0].id]
    );

    await client.query('COMMIT');
    res.json({ organisation: org.rows[0], admin: admin.rows[0] });
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: err.message });
  } finally {
    client.release();
  }
});

// DELETE /api/organisations/:id — superadmin only
router.delete('/:id', authenticateToken, requireRole('superadmin'), async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('DELETE FROM session_invites WHERE session_id IN (SELECT s.id FROM sessions s JOIN classes c ON s.class_id=c.id WHERE c.org_id=$1)', [req.params.id]);
    await client.query('DELETE FROM attendance WHERE session_id IN (SELECT s.id FROM sessions s JOIN classes c ON s.class_id=c.id WHERE c.org_id=$1)', [req.params.id]);
    await client.query('DELETE FROM sessions WHERE class_id IN (SELECT id FROM classes WHERE org_id=$1)', [req.params.id]);
    await client.query('DELETE FROM enrolments WHERE class_id IN (SELECT id FROM classes WHERE org_id=$1)', [req.params.id]);
    await client.query('DELETE FROM classes WHERE org_id=$1', [req.params.id]);
    await client.query('DELETE FROM invitations WHERE org_id=$1', [req.params.id]);
    await client.query('DELETE FROM messages WHERE org_id=$1', [req.params.id]);
    await client.query('DELETE FROM notifications WHERE user_id IN (SELECT id FROM users WHERE org_id=$1)', [req.params.id]);
    await client.query('DELETE FROM face_embeddings WHERE user_id IN (SELECT id FROM users WHERE org_id=$1)', [req.params.id]);
    await client.query('DELETE FROM users WHERE org_id=$1', [req.params.id]);
    await client.query('DELETE FROM organisations WHERE id=$1', [req.params.id]);
    await client.query('COMMIT');
    res.json({ deleted: true, orgId: req.params.id });
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: err.message });
  } finally {
    client.release();
  }
});

// GET /api/organisations/:id — superadmin or own admin
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== 'superadmin' && req.user.org_id !== parseInt(req.params.id)) {
      return res.status(403).json({ error: 'Access denied' });
    }
    const result = await pool.query('SELECT * FROM organisations WHERE id=$1', [req.params.id]);
    if (!result.rows.length) return res.status(404).json({ error: 'Organisation not found' });
    res.json({ organisation: result.rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
