const express = require('express');
const router  = express.Router();
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');

// ── GET /api/dashboard/admin ──────────────────────────────────────────────────
router.get('/admin', authenticateToken, async (req, res) => {
  try {
    const totalUsers = await pool.query(
      "SELECT COUNT(*) FROM users"
    );
    const totalStudents = await pool.query(
      "SELECT COUNT(*) FROM users WHERE role='student'"
    );
    const totalTeachers = await pool.query(
      "SELECT COUNT(*) FROM users WHERE role='teacher'"
    );
    const attendanceStats = await pool.query(
      "SELECT COUNT(*) AS total, COUNT(CASE WHEN status='present' THEN 1 END) AS present FROM attendance"
    );
    const total   = parseInt(attendanceStats.rows[0].total);
    const present = parseInt(attendanceStats.rows[0].present);
    const pct     = total > 0 ? Math.round(present / total * 100) : 0;

    const topAbsent = await pool.query(
      `SELECT u.name, u.email,
         COUNT(*) AS total_classes,
         COUNT(CASE WHEN a.status='absent' THEN 1 END) AS absences
       FROM attendance a
       JOIN users u ON a.user_id = u.id
       GROUP BY u.id, u.name, u.email
       ORDER BY absences DESC
       LIMIT 5`
    );

    const recentSessions = await pool.query(
      `SELECT s.id, c.name AS class_name, s.opened_at, s.closed_at,
         COUNT(a.id) AS marked_count
       FROM sessions s
       JOIN classes c ON s.class_id = c.id
       LEFT JOIN attendance a ON a.session_id = s.id
       GROUP BY s.id, c.name
       ORDER BY s.opened_at DESC
       LIMIT 5`
    );

    res.json({
      totalUsers:      parseInt(totalUsers.rows[0].count),
      totalStudents:   parseInt(totalStudents.rows[0].count),
      totalTeachers:   parseInt(totalTeachers.rows[0].count),
      attendancePct:   pct,
      totalClasses:    total,
      presentCount:    present,
      absentCount:     total - present,
      topAbsent:       topAbsent.rows,
      recentSessions:  recentSessions.rows
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── GET /api/dashboard/teacher/:classId ──────────────────────────────────────
router.get('/teacher/:classId', authenticateToken, async (req, res) => {
  try {
    const classInfo = await pool.query(
      'SELECT * FROM classes WHERE id=$1', [req.params.classId]
    );
    if (!classInfo.rows.length) {
      return res.status(404).json({ error: 'Class not found' });
    }

    const sessionStats = await pool.query(
      `SELECT s.id, s.opened_at, s.closed_at,
         COUNT(a.id) AS total_marked,
         COUNT(CASE WHEN a.status='present' THEN 1 END) AS present_count,
         COUNT(CASE WHEN a.status='absent'  THEN 1 END) AS absent_count
       FROM sessions s
       LEFT JOIN attendance a ON a.session_id = s.id
       WHERE s.class_id = $1
       GROUP BY s.id
       ORDER BY s.opened_at DESC`,
      [req.params.classId]
    );

    const studentStats = await pool.query(
      `SELECT u.id, u.name, u.email,
         COUNT(a.id) AS total,
         COUNT(CASE WHEN a.status='present' THEN 1 END) AS present,
         COUNT(CASE WHEN a.status='absent'  THEN 1 END) AS absent,
         ROUND(COUNT(CASE WHEN a.status='present' THEN 1 END)::numeric /
               NULLIF(COUNT(a.id),0) * 100) AS attendance_pct
       FROM users u
       LEFT JOIN attendance a ON a.user_id = u.id
       LEFT JOIN sessions   s ON a.session_id = s.id AND s.class_id = $1
       WHERE u.role = 'student'
       GROUP BY u.id, u.name, u.email
       ORDER BY attendance_pct ASC`,
      [req.params.classId]
    );

    const absentToday = await pool.query(
      `SELECT u.name, u.email, a.check_in
       FROM attendance a
       JOIN users    u ON a.user_id    = u.id
       JOIN sessions s ON a.session_id = s.id
       WHERE s.class_id = $1
         AND a.status = 'absent'
         AND DATE(a.check_in) = CURRENT_DATE`,
      [req.params.classId]
    );

    res.json({
      class:       classInfo.rows[0],
      sessions:    sessionStats.rows,
      students:    studentStats.rows,
      absentToday: absentToday.rows
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── GET /api/dashboard/student/:userId ───────────────────────────────────────
router.get('/student/:userId', authenticateToken, async (req, res) => {
  try {
    const userInfo = await pool.query(
      'SELECT id, name, email, role FROM users WHERE id=$1',
      [req.params.userId]
    );
    if (!userInfo.rows.length) {
      return res.status(404).json({ error: 'User not found' });
    }

    const overall = await pool.query(
      `SELECT COUNT(*) AS total,
         COUNT(CASE WHEN status='present' THEN 1 END) AS present,
         COUNT(CASE WHEN status='absent'  THEN 1 END) AS absent
       FROM attendance WHERE user_id=$1`,
      [req.params.userId]
    );

    const total   = parseInt(overall.rows[0].total);
    const present = parseInt(overall.rows[0].present);
    const pct     = total > 0 ? Math.round(present / total * 100) : 0;

    const byClass = await pool.query(
      `SELECT c.name AS class_name, c.subject,
         COUNT(a.id) AS total,
         COUNT(CASE WHEN a.status='present' THEN 1 END) AS present,
         ROUND(COUNT(CASE WHEN a.status='present' THEN 1 END)::numeric /
               NULLIF(COUNT(a.id),0) * 100) AS attendance_pct
       FROM attendance a
       JOIN sessions s ON a.session_id = s.id
       JOIN classes  c ON s.class_id   = c.id
       WHERE a.user_id = $1
       GROUP BY c.id, c.name, c.subject`,
      [req.params.userId]
    );

    const calendar = await pool.query(
      `SELECT DATE(check_in) AS date, status
       FROM attendance
       WHERE user_id=$1
       ORDER BY check_in DESC
       LIMIT 30`,
      [req.params.userId]
    );

    res.json({
      user:          userInfo.rows[0],
      totalClasses:  total,
      present,
      absent:        parseInt(overall.rows[0].absent),
      attendancePct: pct,
      warning:       pct < 75 && total > 0,
      byClass:       byClass.rows,
      calendar:      calendar.rows
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
