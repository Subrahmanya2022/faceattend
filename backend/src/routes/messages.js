const express = require('express');
const router  = express.Router();
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');

// GET /api/messages/contacts — contacts based on role and org
router.get('/contacts', authenticateToken, async (req, res) => {
  try {
    const { id, role, org_id } = req.user;
    let contacts = [];

    if (role === 'student') {
      const adminRes = await pool.query(
        `SELECT id, name, email, role FROM users
         WHERE org_id=$1 AND role='admin' AND is_active=TRUE`,
        [org_id]);
      const teachRes = await pool.query(
        `SELECT DISTINCT u.id, u.name, u.email, u.role
         FROM users u
         JOIN classes c ON c.teacher_id = u.id
         JOIN enrolments e ON e.class_id = c.id
         WHERE e.student_id=$1 AND u.is_active=TRUE AND u.org_id=$2`,
        [id, org_id]);
      contacts = [...adminRes.rows, ...teachRes.rows];

    } else if (role === 'teacher') {
      const adminRes = await pool.query(
        `SELECT id, name, email, role FROM users
         WHERE org_id=$1 AND role='admin' AND is_active=TRUE`,
        [org_id]);
      const studRes = await pool.query(
        `SELECT DISTINCT u.id, u.name, u.email, u.role
         FROM users u
         JOIN enrolments e ON e.student_id = u.id
         JOIN classes c ON e.class_id = c.id
         WHERE c.teacher_id=$1 AND u.is_active=TRUE AND u.org_id=$2`,
        [id, org_id]);
      contacts = [...adminRes.rows, ...studRes.rows];

    } else if (role === 'admin') {
      const superRes = await pool.query(
        `SELECT id, name, email, role FROM users WHERE role='superadmin'`);
      const teachRes = await pool.query(
        `SELECT id, name, email, role FROM users
         WHERE org_id=$1 AND role='teacher' AND is_active=TRUE`,
        [org_id]);
      const studRes = await pool.query(
        `SELECT id, name, email, role FROM users
         WHERE org_id=$1 AND role='student' AND is_active=TRUE`,
        [org_id]);
      contacts = [...superRes.rows, ...teachRes.rows, ...studRes.rows];

    } else if (role === 'superadmin') {
      const adminRes = await pool.query(
        `SELECT id, name, email, role FROM users
         WHERE role='admin' AND is_active=TRUE`);
      contacts = adminRes.rows;
    }

    contacts = contacts.filter(c => c.id !== id);
    res.json({ contacts });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/messages/unread — count unread messages
router.get('/unread', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT COUNT(*) FROM messages WHERE receiver_id=$1 AND is_read=FALSE',
      [req.user.id]
    );
    res.json({ unread: parseInt(result.rows[0].count) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/messages/thread/:id — get full thread with replies
router.get('/thread/:id', authenticateToken, async (req, res) => {
  try {
    const original = await pool.query(
      `SELECT m.*, s.name AS sender_name, s.role AS sender_role,
         r.name AS receiver_name, r.role AS receiver_role
       FROM messages m
       JOIN users s ON m.sender_id   = s.id
       JOIN users r ON m.receiver_id = r.id
       WHERE m.id=$1`,
      [req.params.id]
    );
    if (!original.rows.length) {
      return res.status(404).json({ error: 'Message not found' });
    }
    const msg = original.rows[0];
    if (msg.sender_id !== req.user.id && msg.receiver_id !== req.user.id) {
      return res.status(403).json({ error: 'Access denied' });
    }
    const replies = await pool.query(
      `SELECT m.*, s.name AS sender_name, s.role AS sender_role
       FROM messages m
       JOIN users s ON m.sender_id = s.id
       WHERE m.thread_id=$1
       ORDER BY m.created_at ASC`,
      [req.params.id]
    );
    await pool.query(
      'UPDATE messages SET is_read=TRUE WHERE id=$1 AND receiver_id=$2',
      [req.params.id, req.user.id]
    );
    res.json({ message: msg, replies: replies.rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/messages — get all messages for logged in user
router.get('/', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT m.*,
         s.name AS sender_name,   s.role AS sender_role,
         r.name AS receiver_name, r.role AS receiver_role
       FROM messages m
       JOIN users s ON m.sender_id   = s.id
       JOIN users r ON m.receiver_id = r.id
       WHERE (m.receiver_id=$1 OR m.sender_id=$1)
         AND m.parent_id IS NULL
       ORDER BY m.created_at DESC`,
      [req.user.id]
    );
    const threads = await Promise.all(result.rows.map(async (msg) => {
      const replies = await pool.query(
        'SELECT COUNT(*) FROM messages WHERE thread_id=$1', [msg.id]);
      return { ...msg, reply_count: parseInt(replies.rows[0].count) };
    }));
    res.json({ messages: threads });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/messages — send a new message
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { receiverId, subject, body } = req.body;
    if (!receiverId || !subject || !body) {
      return res.status(400).json({ error: 'receiverId, subject and body required' });
    }
    const recv = await pool.query(
      'SELECT id, name, role, org_id FROM users WHERE id=$1',
      [receiverId]
    );
    if (!recv.rows.length) {
      return res.status(404).json({ error: 'Receiver not found' });
    }
    const receiver = recv.rows[0];
    const role     = req.user.role;
    const orgId    = req.user.org_id;

    if (role === 'student') {
      if (receiver.role !== 'admin' && receiver.role !== 'teacher') {
        return res.status(403).json({ error: 'Students can only message admin or teachers' });
      }
    }
    if (role === 'teacher') {
      if (receiver.role !== 'admin' && receiver.role !== 'student') {
        return res.status(403).json({ error: 'Teachers can only message admin or students' });
      }
    }
    if (role === 'admin') {
      if (receiver.role !== 'superadmin' && receiver.role !== 'teacher' && receiver.role !== 'student') {
        return res.status(403).json({ error: 'Invalid message recipient' });
      }
    }
    if (role === 'superadmin') {
      if (receiver.role !== 'admin') {
        return res.status(403).json({ error: 'Superadmin can only message admins' });
      }
    }

    const msgOrgId = orgId || receiver.org_id;

    const inserted = await pool.query(
      `INSERT INTO messages (org_id, sender_id, receiver_id, subject, body)
       VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [msgOrgId, req.user.id, receiverId, subject, body]
    );
    await pool.query(
      'UPDATE messages SET thread_id=id WHERE id=$1',
      [inserted.rows[0].id]
    );
    await pool.query(
      `INSERT INTO notifications (user_id, title, message, type)
       VALUES ($1,$2,$3,'message')`,
      [receiverId, `New message from ${req.user.name}`, subject]
    );
    res.json({ message: inserted.rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/messages/:id/reply — reply to a message
router.post('/:id/reply', authenticateToken, async (req, res) => {
  try {
    const { body } = req.body;
    if (!body) return res.status(400).json({ error: 'body required' });
    const original = await pool.query(
      'SELECT * FROM messages WHERE id=$1', [req.params.id]);
    if (!original.rows.length) {
      return res.status(404).json({ error: 'Message not found' });
    }
    const orig = original.rows[0];
    if (orig.sender_id !== req.user.id && orig.receiver_id !== req.user.id) {
      return res.status(403).json({ error: 'Access denied' });
    }
    const replyTo = orig.sender_id === req.user.id
      ? orig.receiver_id : orig.sender_id;
    const msgOrgId = req.user.org_id || orig.org_id;
    const result = await pool.query(
      `INSERT INTO messages (org_id, sender_id, receiver_id, subject, body, parent_id, thread_id, is_reply)
       VALUES ($1,$2,$3,$4,$5,$6,$7,TRUE) RETURNING *`,
      [msgOrgId, req.user.id, replyTo,
       `Re: ${orig.subject}`, body, orig.id, orig.thread_id || orig.id]
    );
    await pool.query(
      `INSERT INTO notifications (user_id, title, message, type)
       VALUES ($1,$2,$3,'message')`,
      [replyTo, `Reply from ${req.user.name}`, `Re: ${orig.subject}`]
    );
    res.json({ reply: result.rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/messages/:id — delete own message
router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const msg = await pool.query(
      'SELECT * FROM messages WHERE id=$1', [req.params.id]);
    if (!msg.rows.length) {
      return res.status(404).json({ error: 'Message not found' });
    }
    if (msg.rows[0].sender_id !== req.user.id) {
      return res.status(403).json({ error: 'Can only delete your own messages' });
    }
    await pool.query(
      'DELETE FROM messages WHERE id=$1 OR thread_id=$1', [req.params.id]);
    res.json({ deleted: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
