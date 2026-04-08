const express = require('express');
const router  = express.Router();
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');

function requireRole(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Access denied' });
    }
    next();
  };
}

// GET /api/classes — list classes in org
router.get('/', authenticateToken, async (req, res) => {
  try {
    let query, params;

    if (req.user.role === 'superadmin') {
      query  = `SELECT c.*, o.name AS org_name, u.name AS teacher_name,
                  COUNT(e.id) AS student_count
                FROM classes c
                LEFT JOIN organisations o ON c.org_id = o.id
                LEFT JOIN users         u ON c.teacher_id = u.id
                LEFT JOIN enrolments    e ON e.class_id = c.id
                GROUP BY c.id, o.name, u.name
                ORDER BY c.created_at DESC`;
      params = [];
    } else if (req.user.role === 'admin') {
      query  = `SELECT c.*, u.name AS teacher_name,
                  COUNT(e.id) AS student_count
                FROM classes c
                LEFT JOIN users      u ON c.teacher_id = u.id
                LEFT JOIN enrolments e ON e.class_id = c.id
                WHERE c.org_id=$1
                GROUP BY c.id, u.name
                ORDER BY c.created_at DESC`;
      params = [req.user.org_id];
    } else if (req.user.role === 'teacher') {
      query  = `SELECT c.*, COUNT(e.id) AS student_count
                FROM classes c
                LEFT JOIN enrolments e ON e.class_id = c.id
                WHERE c.teacher_id=$1
                GROUP BY c.id
                ORDER BY c.created_at DESC`;
      params = [req.user.id];
    } else {
      // student sees classes they are enrolled in
      query  = `SELECT c.*, u.name AS teacher_name
                FROM classes c
                JOIN enrolments e ON e.class_id = c.id
                LEFT JOIN users u ON c.teacher_id = u.id
                WHERE e.student_id=$1
                ORDER BY c.created_at DESC`;
      params = [req.user.id];
    }

    const result = await pool.query(query, params);
    res.json({ classes: result.rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/classes — admin creates class
router.post('/', authenticateToken, requireRole('admin','superadmin'), async (req, res) => {
  try {
    const { name, subject, teacherId, schedule, description, meetingLink } = req.body;
    if (!name) return res.status(400).json({ error: 'name required' });

    const result = await pool.query(
      `INSERT INTO classes (name, subject, teacher_id, schedule, description, meeting_link, org_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [name, subject, teacherId, schedule, description, meetingLink, req.user.org_id]
    );
    res.json({ class: result.rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/classes/:id — get class detail
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT c.*, u.name AS teacher_name, o.name AS org_name
       FROM classes c
       LEFT JOIN users         u ON c.teacher_id = u.id
       LEFT JOIN organisations o ON c.org_id     = o.id
       WHERE c.id=$1`,
      [req.params.id]
    );
    if (!result.rows.length) return res.status(404).json({ error: 'Class not found' });

    const cls = result.rows[0];
    if (req.user.role !== 'superadmin' && cls.org_id !== req.user.org_id) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Get enrolled students
    const students = await pool.query(
      `SELECT u.id, u.name, u.email, e.enrolled_at
       FROM enrolments e
       JOIN users u ON e.student_id = u.id
       WHERE e.class_id=$1`,
      [req.params.id]
    );

    res.json({ class: cls, students: students.rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/classes/:id — admin deletes class
router.delete('/:id', authenticateToken, requireRole('admin','superadmin'), async (req, res) => {
  try {
    const cls = await pool.query('SELECT * FROM classes WHERE id=$1', [req.params.id]);
    if (!cls.rows.length) return res.status(404).json({ error: 'Class not found' });
    if (req.user.role === 'admin' && cls.rows[0].org_id !== req.user.org_id) {
      return res.status(403).json({ error: 'Access denied' });
    }
    await pool.query('DELETE FROM classes WHERE id=$1', [req.params.id]);
    res.json({ deleted: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/classes/:id/enrol — admin or teacher enrols student
router.post('/:id/enrol', authenticateToken, requireRole('admin','teacher'), async (req, res) => {
  try {
    const { studentId } = req.body;
    if (!studentId) return res.status(400).json({ error: 'studentId required' });

    await pool.query(
      'INSERT INTO enrolments (class_id, student_id) VALUES ($1,$2) ON CONFLICT DO NOTHING',
      [req.params.id, studentId]
    );
    res.json({ enrolled: true, classId: req.params.id, studentId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/classes/:id/enrol/:studentId — remove student from class
router.delete('/:id/enrol/:studentId', authenticateToken, requireRole('admin','teacher'), async (req, res) => {
  try {
    await pool.query(
      'DELETE FROM enrolments WHERE class_id=$1 AND student_id=$2',
      [req.params.id, req.params.studentId]
    );
    res.json({ removed: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
