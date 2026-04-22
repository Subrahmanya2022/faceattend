const express = require('express');
const router  = express.Router();
const { sendNotification } = require('../config/notify');
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const multer = require('multer');
const fetch  = (...args) => import('node-fetch').then(({ default: fetch }) => fetch(...args));

const upload     = multer({ storage: multer.memoryStorage() });
const ML_SERVICE = 'http://localhost:8001';
const ML_URL = process.env.ML_URL || 'http://192.168.1.112:8001';

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
    if (!userId || !sessionId) {
      return res.status(400).json({ error: 'userId and sessionId required' });
    }

    // Check session is active
    const session = await pool.query(
      "SELECT * FROM sessions WHERE id=$1 AND status='active'",
      [sessionId]
    );
    if (!session.rows.length) {
      return res.status(400).json({ error: 'Session is not active' });
    }

    // Check already marked
    const existing = await pool.query(
      'SELECT id FROM attendance WHERE session_id=$1 AND user_id=$2',
      [sessionId, userId]
    );
    if (existing.rows.length) {
      return res.status(400).json({ error: 'Already marked for this session' });
    }

    // Check face enrolled
    const faceRow = await pool.query(
      'SELECT embedding FROM face_embeddings WHERE user_id=$1 LIMIT 1',
      [userId]
    );
    if (!faceRow.rows.length) {
      return res.status(404).json({ error: 'Face not enrolled. Please enrol your face first.' });
    }

    // Get embedding from ML service
    const b64 = req.file.buffer.toString('base64');
    let status     = 'absent';
    let confidence = 0;
    let match      = false;

    try {
      const mlResponse = await fetch(`${ML_URL}/enroll`, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({ image: b64 }),
      });
      const mlData = await mlResponse.json();

      if (mlData.embedding) {
        const queryEmbedding = mlData.embedding.map(Number);
        const vector         = `[${queryEmbedding.join(',')}]`;

        // Compare with stored embedding using pgvector
        const verifyResult = await pool.query(
          `SELECT 1 - (fe.embedding <=> $1::vector) AS similarity
           FROM face_embeddings fe
           WHERE fe.user_id = $2
           LIMIT 1`,
          [vector, userId]
        );

        if (verifyResult.rows.length) {
          const similarity = parseFloat(verifyResult.rows[0].similarity);
confidence       = Math.max(0, similarity);

          console.log(`🎯 User ${userId} similarity: ${similarity}`);

          if (similarity > 0.70) {
            status = 'present';
            match  = true;
          }
        }
      }
    } catch (mlErr) {
      console.error('ML error:', mlErr.message);
      // If ML fails still record as absent
    }

    // Record attendance
    const result = await pool.query(
      `INSERT INTO attendance (session_id, user_id, status, confidence, check_in, session_date)
       VALUES ($1,$2,$3,$4,NOW(),CURRENT_DATE)
       RETURNING *`,
      [sessionId, userId, status, confidence]
    );

    // Check absenteeism warning
    const historyCheck = await pool.query(
      `SELECT COUNT(*) AS total,
         COUNT(CASE WHEN status='present' THEN 1 END) AS present
       FROM attendance WHERE user_id=$1`,
      [userId]
    );
    const tot = parseInt(historyCheck.rows[0].total);
    const pre = parseInt(historyCheck.rows[0].present);
    const pct = tot > 0 ? Math.round(pre / tot * 100) : 100;
    if (pct < 75 && tot >= 2) {
      await sendNotification(
        userId,
        'Low Attendance Warning',
        `Your attendance is ${pct}%. Minimum required is 75%.`,
        'warning'
      );
    }

    res.json({
      marked:     true,
      status,
      match,
      confidence,
      record:     result.rows[0]
    });
  } catch (err) {
    console.error('❌ Mark error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// router.post('/mark', upload.single('image'), async (req, res) => {
//   try {
//     const { userId, sessionId } = req.body;
//     if (!userId || !sessionId) return res.status(400).json({ error: 'userId and sessionId required' });

//     const session = await pool.query(
//       'SELECT * FROM sessions WHERE id=$1 AND closed_at IS NULL', [sessionId]
//     );
//     if (!session.rows.length) return res.status(400).json({ error: 'Session is closed or does not exist' });

//     const existing = await pool.query(
//       'SELECT id FROM attendance WHERE session_id=$1 AND user_id=$2', [sessionId, userId]
//     );
//     if (existing.rows.length) return res.status(400).json({ error: 'Already marked for this session' });

//     const faceRow = await pool.query(
//       'SELECT embedding FROM face_embeddings WHERE user_id=$1 ORDER BY created_at DESC LIMIT 1', [userId]
//     );
//     if (!faceRow.rows.length) return res.status(404).json({ error: 'Face not enrolled for this user' });

//     const b64 = req.file.buffer.toString('base64');
//     const mlResponse = await fetch(`${ML_SERVICE}/verify`, {
//       method: 'POST',
//       headers: { 'Content-Type': 'application/json' },
//       body: JSON.stringify({ image: b64, stored_embedding: faceRow.rows[0].embedding })
//     });
//     const mlData = await mlResponse.json();

//     const status     = mlData.match ? 'present' : 'absent';
//     const confidence = mlData.distance || 0;

//     const result = await pool.query(
//       `INSERT INTO attendance (session_id, user_id, status, confidence, check_in, session_date, embedding)
//        VALUES ($1,$2,$3,$4,NOW(),CURRENT_DATE,
//          (SELECT embedding FROM face_embeddings WHERE user_id=$2 LIMIT 1))
//        RETURNING *`,
//       [sessionId, userId, status, confidence]
//     );
// const historyCheck = await pool.query(
//   `SELECT COUNT(*) AS total,
//      COUNT(CASE WHEN status='present' THEN 1 END) AS present
//    FROM attendance WHERE user_id=$1`,
//   [userId]
// );
// const tot = parseInt(historyCheck.rows[0].total);
// const pre = parseInt(historyCheck.rows[0].present);
// const pct = tot > 0 ? Math.round(pre / tot * 100) : 100;
// if (pct < 75 && tot >= 2) {
//   await sendNotification(
//     userId,
//     'Low Attendance Warning',
//     `Your attendance is ${pct}%. Minimum required is 75%.`,
//     'warning'
//   );
// }
//     res.json({ marked: true, status, match: mlData.match, confidence, record: result.rows[0] });
//   } catch (err) {
//     res.status(500).json({ error: err.message });
//   }
// });

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

// POST /api/attendance/:id/request-correction — student requests correction
router.post('/:id/request-correction', authenticateToken, async (req, res) => {
  try {
    const { reason } = req.body;
    if (!reason) {
      return res.status(400).json({ error: 'reason required' });
    }

    const record = await pool.query(
      `SELECT a.*, s.class_id, c.teacher_id, c.org_id
       FROM attendance a
       JOIN sessions s ON a.session_id = s.id
       JOIN classes  c ON s.class_id   = c.id
       WHERE a.id=$1 AND a.user_id=$2`,
      [req.params.id, req.user.id]
    );
    if (!record.rows.length) {
      return res.status(404).json({ error: 'Attendance record not found' });
    }

    const rec = record.rows[0];

    // Notify teacher
    if (rec.teacher_id) {
      await pool.query(
        `INSERT INTO notifications (user_id, title, message, type)
         VALUES ($1,$2,$3,'alert')`,
        [rec.teacher_id,
         `Attendance Correction Request`,
         `${req.user.name} is requesting correction for attendance record #${req.params.id}. Reason: ${reason}`]
      );
    }

    // Notify admin
    const admin = await pool.query(
      `SELECT id FROM users WHERE org_id=$1 AND role='admin' LIMIT 1`,
      [rec.org_id]
    );
    if (admin.rows.length) {
      await pool.query(
        `INSERT INTO notifications (user_id, title, message, type)
         VALUES ($1,$2,$3,'alert')`,
        [admin.rows[0].id,
         `Attendance Correction Request`,
         `${req.user.name} is requesting correction for attendance record #${req.params.id}. Reason: ${reason}`]
      );
    }

    res.json({
      success: true,
      message: 'Correction request sent to teacher and admin'
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});
