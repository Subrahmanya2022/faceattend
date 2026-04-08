const express = require('express');
const router  = express.Router();
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const bcrypt = require('bcrypt');

function requireRole(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Access denied' });
    }
    next();
  };
}

// GET /api/users — list users in same org
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { role } = req.query;
    let query, params;

    if (req.user.role === 'superadmin') {
      query  = `SELECT id, name, email, role, org_id, is_active, created_at
                FROM users WHERE role != 'superadmin'
                ${role ? "AND role=$1" : ""}
                ORDER BY created_at DESC`;
      params = role ? [role] : [];
    } else if (req.user.role === 'admin') {
      query  = `SELECT id, name, email, role, org_id, is_active, created_at
                FROM users WHERE org_id=$1
                ${role ? "AND role=$2" : ""}
                ORDER BY created_at DESC`;
      params = role ? [req.user.org_id, role] : [req.user.org_id];
    } else {
      return res.status(403).json({ error: 'Access denied' });
    }

    const result = await pool.query(query, params);
    res.json({ users: result.rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/users/:id — get single user
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, name, email, role, org_id, is_active, created_at FROM users WHERE id=$1',
      [req.params.id]
    );
    if (!result.rows.length) return res.status(404).json({ error: 'User not found' });

    const user = result.rows[0];
    if (req.user.role !== 'superadmin' && user.org_id !== req.user.org_id) {
      return res.status(403).json({ error: 'Access denied' });
    }
    res.json({ user });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PATCH /api/users/:id — update user (admin or self)
router.patch('/:id', authenticateToken, async (req, res) => {
  try {
    const { name, email, password } = req.body;
    const isSelf  = req.user.id === parseInt(req.params.id);
    const isAdmin = ['admin','superadmin'].includes(req.user.role);

    if (!isSelf && !isAdmin) {
      return res.status(403).json({ error: 'Access denied' });
    }

    const updates = [];
    const values  = [];
    let   idx     = 1;

    if (name)     { updates.push(`name=$${idx++}`);          values.push(name); }
    if (email)    { updates.push(`email=$${idx++}`);         values.push(email); }
    if (password) {
      const hash = await bcrypt.hash(password, 12);
      updates.push(`password_hash=$${idx++}`);
      values.push(hash);
    }

    if (!updates.length) return res.status(400).json({ error: 'Nothing to update' });

    values.push(req.params.id);
    const result = await pool.query(
      `UPDATE users SET ${updates.join(',')} WHERE id=$${idx} RETURNING id, name, email, role`,
      values
    );
    res.json({ user: result.rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/users/:id — admin deletes user in their org
router.delete('/:id', authenticateToken, requireRole('admin','superadmin'), async (req, res) => {
  try {
    const user = await pool.query('SELECT * FROM users WHERE id=$1', [req.params.id]);
    if (!user.rows.length) return res.status(404).json({ error: 'User not found' });

    if (req.user.role === 'admin' && user.rows[0].org_id !== req.user.org_id) {
      return res.status(403).json({ error: 'Access denied' });
    }
    if (user.rows[0].role === 'superadmin') {
      return res.status(403).json({ error: 'Cannot delete superadmin' });
    }

    await pool.query('DELETE FROM users WHERE id=$1', [req.params.id]);
    res.json({ deleted: true, userId: req.params.id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PATCH /api/users/:id/toggle — admin activates or deactivates user
router.patch('/:id/toggle', authenticateToken, requireRole('admin','superadmin'), async (req, res) => {
  try {
    const result = await pool.query(
      'UPDATE users SET is_active = NOT is_active WHERE id=$1 RETURNING id, name, is_active',
      [req.params.id]
    );
    res.json({ user: result.rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
