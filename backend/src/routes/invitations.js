const express = require('express');
const router  = express.Router();
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { sendInvitationEmail } = require('../config/email');
const { v4: uuidv4 } = require('uuid');
const bcrypt = require('bcrypt');

// POST /api/invitations — admin invites teacher or student
router.post('/', authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== 'admin' && req.user.role !== 'superadmin') {
      return res.status(403).json({ error: 'Only admin can send invitations' });
    }

    const { name, email, role, classId } = req.body;
    if (!name || !email || !role) {
      return res.status(400).json({ error: 'name, email and role required' });
    }
    if (!['teacher','student'].includes(role)) {
      return res.status(400).json({ error: 'role must be teacher or student' });
    }

    // Check email not already registered
    const existing = await pool.query('SELECT id FROM users WHERE email=$1', [email]);
    if (existing.rows.length) {
      return res.status(400).json({ error: 'Email already registered' });
    }

    // Generate token and temp password
    const token    = uuidv4();
    const tempPass = Math.random().toString(36).slice(-8) + 'A1!';
    const expires  = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

    // Get org info
    const org = await pool.query(
      'SELECT * FROM organisations WHERE id=$1', [req.user.org_id]
    );
    if (!org.rows.length) {
      return res.status(404).json({ error: 'Organisation not found' });
    }

    // Save invitation
    await pool.query(
      `INSERT INTO invitations (org_id, email, name, role, class_id, invited_by, token, temp_pass, expires_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
      [req.user.org_id, email, name, role, classId || null,
       req.user.id, token, tempPass, expires]
    );

    // Send email
    try {
      await sendInvitationEmail(email, name, role, org.rows[0].name, tempPass, token);
    } catch (emailErr) {
      console.error('Email send failed:', emailErr.message);
    }

    res.json({
      success:   true,
      message:   `Invitation sent to ${email}`,
      token,
      tempPass,
      expiresAt: expires
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/invitations/accept/:token — user accepts invite
router.get('/accept/:token', async (req, res) => {
  const client = await pool.connect();
  try {
    const invite = await pool.query(
      `SELECT * FROM invitations
       WHERE token=$1 AND status='pending' AND expires_at > NOW()`,
      [req.params.token]
    );
    if (!invite.rows.length) {
      return res.status(400).json({ error: 'Invalid or expired invitation' });
    }

    const inv  = invite.rows[0];
    const hash = await bcrypt.hash(inv.temp_pass, 12);

    await client.query('BEGIN');

    // Create user account
    const user = await client.query(
      `INSERT INTO users (name, email, password_hash, role, org_id, is_active, invited_at, joined_at)
       VALUES ($1,$2,$3,$4,$5,TRUE,$6,NOW())
       RETURNING id, name, email, role, org_id`,
      [inv.name, inv.email, hash, inv.role, inv.org_id, inv.created_at]
    );

    // If student and classId provided, enrol them
    if (inv.role === 'student' && inv.class_id) {
      await client.query(
        'INSERT INTO enrolments (class_id, student_id) VALUES ($1,$2) ON CONFLICT DO NOTHING',
        [inv.class_id, user.rows[0].id]
      );
    }

    // Mark invitation accepted
    await client.query(
      "UPDATE invitations SET status='accepted' WHERE id=$1",
      [inv.id]
    );

    await client.query('COMMIT');

    res.json({
      success:  true,
      message:  'Account activated. You can now login with your email and temporary password.',
      user:     user.rows[0]
    });
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: err.message });
  } finally {
    client.release();
  }
});

// GET /api/invitations — admin views their sent invitations
router.get('/', authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== 'admin' && req.user.role !== 'superadmin') {
      return res.status(403).json({ error: 'Access denied' });
    }
    const result = await pool.query(
      `SELECT i.*, u.name AS invited_by_name
       FROM invitations i
       LEFT JOIN users u ON i.invited_by = u.id
       WHERE i.org_id=$1
       ORDER BY i.created_at DESC`,
      [req.user.org_id]
    );
    res.json({ invitations: result.rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
