const express = require('express');
const router  = express.Router();
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { format } = require('fast-csv');
const PDFDocument = require('pdfkit');

// ── GET /api/reports/export?classId=1&format=csv ──────────────────────────────
router.get('/export', authenticateToken, async (req, res) => {
  const { classId, format: fmt } = req.query;
  if (!classId) return res.status(400).json({ error: 'classId required' });

  try {
    const result = await pool.query(
      `SELECT
         u.name, u.email, u.role,
         a.status, a.confidence,
         a.check_in, a.session_date,
         c.name AS class_name, c.subject
       FROM attendance a
       JOIN users    u ON a.user_id    = u.id
       JOIN sessions s ON a.session_id = s.id
       JOIN classes  c ON s.class_id   = c.id
       WHERE s.class_id = $1
       ORDER BY a.check_in DESC`,
      [classId]
    );

    if (fmt === 'pdf') {
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `attachment; filename=attendance_class${classId}.pdf`);

      const doc = new PDFDocument({ margin: 40 });
      doc.pipe(res);

      doc.fontSize(18).font('Helvetica-Bold')
         .text('FaceAttend — Attendance Report', { align: 'center' });
      doc.moveDown(0.5);
      doc.fontSize(11).font('Helvetica')
         .text(`Class ID: ${classId}`, { align: 'center' });
      doc.text(`Generated: ${new Date().toLocaleDateString()}`, { align: 'center' });
      doc.moveDown(1);

      doc.fontSize(10).font('Helvetica-Bold');
      doc.text('Name', 40, doc.y, { continued: true, width: 150 });
      doc.text('Status', 200, doc.y, { continued: true, width: 80 });
      doc.text('Date', 290, doc.y, { continued: true, width: 120 });
      doc.text('Class', 420, doc.y, { width: 130 });
      doc.moveTo(40, doc.y).lineTo(555, doc.y).stroke();
      doc.moveDown(0.3);

      doc.font('Helvetica').fontSize(9);
      result.rows.forEach(row => {
        const y = doc.y;
        doc.text(row.name || '', 40, y, { continued: true, width: 150 });
        doc.text(row.status || '', 200, y, { continued: true, width: 80 });
        doc.text(row.session_date ? new Date(row.session_date).toLocaleDateString() : '', 290, y, { continued: true, width: 120 });
        doc.text(row.class_name || '', 420, y, { width: 130 });
        doc.moveDown(0.4);
      });

      doc.moveDown(1);
      doc.fontSize(10).font('Helvetica-Bold')
         .text(`Total Records: ${result.rows.length}`);

      doc.end();

    } else {
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', `attachment; filename=attendance_class${classId}.csv`);

      const csvStream = format({ headers: true });
      csvStream.pipe(res);
      result.rows.forEach(row => csvStream.write({
        Name:         row.name,
        Email:        row.email,
        Class:        row.class_name,
        Subject:      row.subject,
        Status:       row.status,
        Confidence:   row.confidence,
        Date:         row.session_date,
        CheckIn:      row.check_in
      }));
      csvStream.end();
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
