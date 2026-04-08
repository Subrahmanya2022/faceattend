const express = require('express');
const router  = express.Router();
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');

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

    // For each thread get reply count
    const threads = await Promise.all(result.rows.map(async (msg) => {
      const replies = await pool.query(
        'SELECT COUNT(*) FROM messages WHERE thread_id=$1',
        [msg.id]
      );
      return { ...msg, reply_count: parseInt(replies.rows[0].count) };
    }));

    res.json({ messages: threads });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/messages/thread/:id — get full thread with replies
router.get('/thread/:id', authenticateToken, async (req, res) => {
  try {
    // Get original message
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

    // Check user is part of this thread
    const msg = original.rows[0];
    if (msg.sender_id !== req.user.id && msg.receiver_id !== req.user.id) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Get all replies
    const replies = await pool.query(
      `SELECT m.*, s.name AS sender_name, s.role AS sender_role
       FROM messages m
       JOIN users s ON m.sender_id = s.id
       WHERE m.thread_id=$1
       ORDER BY m.created_at ASC`,
      [req.params.id]
    );

    // Mark as read
    await pool.query(
      'UPDATE messages SET is_read=TRUE WHERE id=$1 AND receiver_id=$2',
      [req.params.id, req.user.id]
    );

    res.json({ message: msg, replies: replies.rows });
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

    // Check receiver exists
    const receiver = await pool.query(
      'SELECT id, name, role, org_id FROM users WHERE id=$1',
      [receiverId]
    );
    if (!receiver.rows.length) {
      return res.status(404).json({ error: 'Receiver not found' });
    }

    const recv = receiver.rows[0];

    // Role-based messaging rules
    const role = req.user.role;
    if (role === 'student' && recv.role !== 'admin' && recv.role !== 'superadmin') {
      return res.status(403).json({ error: 'Students can only message their admin' });
    }
    if (role === 'teacher' && recv.role !== 'admin' && recv.role !== 'superadmin') {
      return res.status(403).json({ error: 'Teachers can only message their admin' });
    }
    if (role === 'admin' && recv.role !== 'superadmin' &&
        recv.role !== 'teacher' && recv.role !== 'student') {
      return res.status(403).json({ error: 'Invalid message recipient' });
    }

    // Org isolation — admin can only message within their org or superadmin
    if (role === 'admin' && recv.role !== 'superadmin' &&
        recv.org_id !== req.user.org_id) {
      return res.status(403).json({ error: 'Cannot message users outside your organisation' });
    }

    const result = await pool.query(
      `INSERT INTO messages (org_id, sender_id, receiver_id, subject, body)
       VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [req.user.org_id, req.user.id, receiverId, subject, body]
    );

    // Set thread_id to own id for root messages
    await pool.query(
      'UPDATE messages SET thread_id=id WHERE id=$1',
      [result.rows[0].id]
    );

    // Send notification to receiver
    await pool.query(
      `INSERT INTO notifications (user_id, title, message, type)
       VALUES ($1,$2,$3,'message')`,
      [receiverId, `New message from ${req.user.name}`, subject]
    );

    res.json({ message: result.rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/messages/:id/reply — reply to a message
router.post('/:id/reply', authenticateToken, async (req, res) => {
  try {
    const { body } = req.body;
    if (!body) return res.status(400).json({ error: 'body required' });

    // Get original message
    const original = await pool.query('SELECT * FROM messages WHERE id=$1', [req.params.id]);
    if (!original.rows.length) return res.status(404).json({ error: 'Message not found' });

    const orig = original.rows[0];

    // Only sender or receiver can reply
    if (orig.sender_id !== req.user.id && orig.receiver_id !== req.user.id) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Reply goes to the other person
    const replyTo = orig.sender_id === req.user.id ? orig.receiver_id : orig.sender_id;

    const result = await pool.query(
      `INSERT INTO messages (org_id, sender_id, receiver_id, subject, body, parent_id, thread_id, is_reply)
       VALUES ($1,$2,$3,$4,$5,$6,$7,TRUE) RETURNING *`,
      [req.user.org_id, req.user.id, replyTo,
       `Re: ${orig.subject}`, body, orig.id, orig.thread_id || orig.id]
    );

    // Notify receiver
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
    const msg = await pool.query('SELECT * FROM messages WHERE id=$1', [req.params.id]);
    if (!msg.rows.length) return res.status(404).json({ error: 'Message not found' });
    if (msg.rows[0].sender_id !== req.user.id) {
      return res.status(403).json({ error: 'Can only delete your own messages' });
    }
    await pool.query('DELETE FROM messages WHERE id=$1 OR thread_id=$1', [req.params.id]);
    res.json({ deleted: true });
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

module.exports = router;
