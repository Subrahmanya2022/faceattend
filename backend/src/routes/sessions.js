const express = require('express');
const router  = express.Router();
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { sendSessionInviteEmail } = require('../config/email');

function requireRole(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Access denied' });
    }
    next();
  };
}

// GET /api/sessions — list sessions based on role
router.get('/', authenticateToken, async (req, res) => {
  try {
    let query, params;

    if (req.user.role === 'teacher') {
      query = `SELECT s.*, c.name AS class_name, c.subject,
                 COUNT(si.id) AS invited_count,
                 COUNT(a.id)  AS marked_count
               FROM sessions s
               JOIN classes c ON s.class_id = c.id
               LEFT JOIN session_invites si ON si.session_id = s.id
               LEFT JOIN attendance     a  ON a.session_id  = s.id
               WHERE c.teacher_id=$1
               GROUP BY s.id, c.name, c.subject
               ORDER BY s.scheduled_at DESC`;
      params = [req.user.id];

    } else if (req.user.role === 'student') {
      query = `SELECT s.*, c.name AS class_name, c.subject,
                 c.meeting_link,
                 a.status AS my_status
               FROM sessions s
               JOIN classes     c  ON s.class_id  = c.id
               JOIN enrolments  e  ON e.class_id  = c.id AND e.student_id=$1
               LEFT JOIN attendance a ON a.session_id=s.id AND a.user_id=$1
               ORDER BY s.scheduled_at DESC`;
      params = [req.user.id];

    } else if (req.user.role === 'admin') {
      query = `SELECT s.*, c.name AS class_name, c.subject,
                 u.name AS teacher_name
               FROM sessions s
               JOIN classes c ON s.class_id = c.id
               JOIN users   u ON c.teacher_id = u.id
               WHERE c.org_id=$1
               ORDER BY s.scheduled_at DESC`;
      params = [req.user.org_id];

    } else {
      query  = `SELECT s.*, c.name AS class_name FROM sessions s
                JOIN classes c ON s.class_id=c.id
                ORDER BY s.scheduled_at DESC`;
      params = [];
    }

    const result = await pool.query(query, params);
    res.json({ sessions: result.rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/sessions — teacher schedules a session
router.post('/', authenticateToken, requireRole('teacher','admin'), async (req, res) => {
  try {
    const { classId, title, scheduledAt, meetingLink, notifyStudents } = req.body;
    if (!classId || !title || !scheduledAt) {
      return res.status(400).json({ error: 'classId, title and scheduledAt required' });
    }

    // Verify teacher owns this class
    if (req.user.role === 'teacher') {
      const cls = await pool.query(
        'SELECT * FROM classes WHERE id=$1 AND teacher_id=$2',
        [classId, req.user.id]
      );
      if (!cls.rows.length) {
        return res.status(403).json({ error: 'You do not own this class' });
      }
    }

    const result = await pool.query(
      `INSERT INTO sessions (class_id, opened_by, title, scheduled_at, meeting_link, status)
       VALUES ($1,$2,$3,$4,$5,'scheduled') RETURNING *`,
      [classId, req.user.id, title, scheduledAt, meetingLink || null]
    );

    const session = result.rows[0];

    // Notify enrolled students if requested
    if (notifyStudents) {
      const students = await pool.query(
        `SELECT u.id, u.name, u.email FROM enrolments e
         JOIN users u ON e.student_id = u.id
         WHERE e.class_id=$1`,
        [classId]
      );

      const cls = await pool.query('SELECT * FROM classes WHERE id=$1', [classId]);

      for (const student of students.rows) {
        // Save session invite
        await pool.query(
          `INSERT INTO session_invites (session_id, student_id)
           VALUES ($1,$2) ON CONFLICT DO NOTHING`,
          [session.id, student.id]
        );
        // Save notification
        await pool.query(
          `INSERT INTO notifications (user_id, title, message, type)
           VALUES ($1,$2,$3,'session')`,
          [student.id,
           `New Session: ${title}`,
           `${cls.rows[0].name} — Scheduled for ${new Date(scheduledAt).toLocaleString()}`]
        );
        // Send email
        try {
          await sendSessionInviteEmail(
            student.email, student.name, title,
            cls.rows[0].name, scheduledAt, meetingLink
          );
        } catch (e) {
          console.error('Email error:', e.message);
        }
      }
    }

    res.json({ session, message: 'Session scheduled successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PATCH /api/sessions/:id/activate — teacher starts session
router.patch('/:id/activate', authenticateToken, requireRole('teacher','admin'), async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE sessions SET status='active', opened_at=NOW()
       WHERE id=$1 RETURNING *`,
      [req.params.id]
    );
    if (!result.rows.length) return res.status(404).json({ error: 'Session not found' });

    // Notify enrolled students
    const session = result.rows[0];
    const students = await pool.query(
      `SELECT u.id FROM enrolments e
       JOIN users u ON e.student_id=u.id
       WHERE e.class_id=$1`,
      [session.class_id]
    );
    for (const s of students.rows) {
      await pool.query(
        `INSERT INTO notifications (user_id, title, message, type)
         VALUES ($1,'Session is now LIVE!','Open FaceAttend to mark your attendance.','alert')`,
        [s.id]
      );
    }

    res.json({ session: result.rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PATCH /api/sessions/:id/close — teacher closes session
router.patch('/:id/close', authenticateToken, requireRole('teacher','admin'), async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE sessions SET status='completed', closed_at=NOW()
       WHERE id=$1 RETURNING *`,
      [req.params.id]
    );
    if (!result.rows.length) return res.status(404).json({ error: 'Session not found' });
    res.json({ session: result.rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/sessions/:id — teacher deletes session
router.delete('/:id', authenticateToken, requireRole('teacher','admin'), async (req, res) => {
  try {
    const session = await pool.query('SELECT * FROM sessions WHERE id=$1', [req.params.id]);
    if (!session.rows.length) return res.status(404).json({ error: 'Session not found' });
    if (session.rows[0].status === 'active') {
      return res.status(400).json({ error: 'Cannot delete an active session. Close it first.' });
    }
    await pool.query('DELETE FROM sessions WHERE id=$1', [req.params.id]);
    res.json({ deleted: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/sessions/:id — session detail with attendance
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT s.*, c.name AS class_name, c.subject, c.meeting_link,
         u.name AS teacher_name
       FROM sessions s
       JOIN classes c ON s.class_id   = c.id
       JOIN users   u ON s.opened_by  = u.id
       WHERE s.id=$1`,
      [req.params.id]
    );
    if (!result.rows.length) return res.status(404).json({ error: 'Session not found' });

    const attendance = await pool.query(
  `SELECT u.id AS user_id, u.name, u.email,
     a.id, a.status, a.confidence, a.check_in
   FROM enrolments e
   JOIN users u ON e.student_id = u.id
   LEFT JOIN attendance a ON a.user_id=e.student_id
     AND a.session_id=$1
   WHERE e.class_id=$2`,
  [req.params.id, result.rows[0].class_id]
);

    // const attendance = await pool.query(
    //   `SELECT u.id, u.name, u.email, a.status, a.confidence, a.check_in
    //    FROM enrolments e
    //    JOIN users u ON e.student_id = u.id
    //    LEFT JOIN attendance a ON a.user_id=e.student_id AND a.session_id=$1
    //    WHERE e.class_id=$2`,
    //   [req.params.id, result.rows[0].class_id]
    // );

    res.json({ session: result.rows[0], attendance: attendance.rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
