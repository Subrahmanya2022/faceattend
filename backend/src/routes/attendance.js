const express = require('express');
const router  = express.Router();
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const multer = require('multer');
const fetch  = (...args) => import('node-fetch').then(({ default: fetch }) => fetch(...args));

const upload     = multer({ storage: multer.memoryStorage() });
const ML_SERVICE = 'http://localhost:8001';

function requireRole(role) {
  return (req, res, next) => {
    if (req.user.role !== role && req.user.role !== 'admin') {
      return res.status(403).json({ error: `Requires role: ${role}` });
    }
    next();
  };
}

router.post('/session', authenticateToken, requireRole('teacher'), async (req, res) => {
  try {
    const { classId } = req.body;
    if (!classId) return res.status(400).json({ error: 'classId required' });
    const cls = await pool.query('SELECT * FROM classes WHERE id=$1', [classId]);
    if (!cls.rows.length) return res.status(404).json({ error: 'Class not found' });
    const result = await pool.query(
      'INSERT INTO sessions (class_id, opened_by, opened_at) VALUES ($1,$2,NOW()) RETURNING *',
      [classId, req.user.id]
    );
    res.json({ session: result.rows[0], status: 'open' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/close', authenticateToken, requireRole('teacher'), async (req, res) => {
  try {
    const { sessionId } = req.body;
    if (!sessionId) return res.status(400).json({ error: 'sessionId required' });
    await pool.query('UPDATE sessions SET closed_at=NOW() WHERE id=$1', [sessionId]);
    res.json({ closed: true, sessionId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/mark', upload.single('image'), async (req, res) => {
  try {
    const { userId, sessionId } = req.body;
    if (!userId || !sessionId) return res.status(400).json({ error: 'userId and sessionId required' });

    const session = await pool.query(
      'SELECT * FROM sessions WHERE id=$1 AND closed_at IS NULL', [sessionId]
    );
    if (!session.rows.length) return res.status(400).json({ error: 'Session is closed or does not exist' });

    const existing = await pool.query(
      'SELECT id FROM attendance WHERE session_id=$1 AND user_id=$2', [sessionId, userId]
    );
    if (existing.rows.length) return res.status(400).json({ error: 'Already marked for this session' });

    const faceRow = await pool.query(
      'SELECT embedding FROM face_embeddings WHERE user_id=$1 ORDER BY created_at DESC LIMIT 1', [userId]
    );
    if (!faceRow.rows.length) return res.status(404).json({ error: 'Face not enrolled for this user' });

    const b64 = req.file.buffer.toString('base64');
    const mlResponse = await fetch(`${ML_SERVICE}/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ image: b64, stored_embedding: faceRow.rows[0].embedding })
    });
    const mlData = await mlResponse.json();

    const status     = mlData.match ? 'present' : 'absent';
    const confidence = mlData.distance || 0;

    const result = await pool.query(
      `INSERT INTO attendance (session_id, user_id, status, confidence, check_in, session_date, embedding)
       VALUES ($1,$2,$3,$4,NOW(),CURRENT_DATE,
         (SELECT embedding FROM face_embeddings WHERE user_id=$2 LIMIT 1))
       RETURNING *`,
      [sessionId, userId, status, confidence]
    );

    res.json({ marked: true, status, match: mlData.match, confidence, record: result.rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/class/:classId', authenticateToken, requireRole('teacher'), async (req, res) => {
  try {
    const sessions = await pool.query(
      `SELECT s.id, s.opened_at, s.closed_at,
         COUNT(a.id) AS total_marked,
         COUNT(CASE WHEN a.status='present' THEN 1 END) AS present_count,
         COUNT(CASE WHEN a.status='absent' THEN 1 END)  AS absent_count
       FROM sessions s
       LEFT JOIN attendance a ON a.session_id=s.id
       WHERE s.class_id=$1
       GROUP BY s.id ORDER BY s.opened_at DESC`,
      [req.params.classId]
    );
    const detail = await pool.query(
      `SELECT u.name, u.email, a.status, a.confidence, a.check_in, a.session_date
       FROM attendance a
       JOIN users    u ON a.user_id=u.id
       JOIN sessions s ON a.session_id=s.id
       WHERE s.class_id=$1
       ORDER BY s.opened_at DESC, u.name ASC`,
      [req.params.classId]
    );
    res.json({ classId: req.params.classId, sessions: sessions.rows, records: detail.rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/:userId', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT a.id, a.status, a.confidence, a.check_in, a.session_date,
         c.name AS class_name, c.subject, s.opened_at AS session_opened
       FROM attendance a
       LEFT JOIN sessions s ON a.session_id=s.id
       LEFT JOIN classes  c ON s.class_id=c.id
       WHERE a.user_id=$1
       ORDER BY a.check_in DESC`,
      [req.params.userId]
    );
    const total   = result.rows.length;
    const present = result.rows.filter(r => r.status === 'present').length;
    const pct     = total > 0 ? Math.round(present / total * 100) : 0;
    res.json({
      userId: req.params.userId,
      totalClasses: total, present,
      absent: total - present,
      attendancePct: pct,
      warning: pct < 75 && total > 0,
      records: result.rows
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.patch('/:id', authenticateToken, requireRole('teacher'), async (req, res) => {
  try {
    const { status, reason } = req.body;
    const allowed = ['present', 'absent', 'late'];
    if (!allowed.includes(status)) return res.status(400).json({ error: `status must be one of: ${allowed.join(', ')}` });
    const result = await pool.query(
      'UPDATE attendance SET status=$1 WHERE id=$2 RETURNING *',
      [status, req.params.id]
    );
    if (!result.rows.length) return res.status(404).json({ error: 'Record not found' });
    res.json({ updated: true, record: result.rows[0], reason: reason || 'manual override' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
