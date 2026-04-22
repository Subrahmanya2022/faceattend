const express = require('express');
const router  = express.Router();
const fetch   = (...args) =>
  import('node-fetch').then(({ default: f }) => f(...args));
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');

const ML_URL = process.env.ML_URL || 'http://192.168.1.112:8001';

// POST /api/face/enroll
router.post('/enroll', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { images } = req.body;
    if (!images || images.length === 0) {
      return res.status(400).json({ error: 'No images provided' });
    }
    console.log(`🤖 Enrolling user: ${userId}`);

    const mlResponse = await fetch(`${ML_URL}/enroll`, {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    JSON.stringify({ image: images[0] }),
    });
    const data = await mlResponse.json();
    if (!data.embedding) {
      throw new Error(data.error || 'No embedding from ML');
    }

    const embedding = data.embedding.map(Number);
    const dims      = embedding.length;
    const vector    = `[${embedding.join(',')}]`;

    console.log(`✅ Got ${dims}-dim embedding`);

    await pool.query(
      'DELETE FROM face_embeddings WHERE user_id=$1', [userId]);

    await pool.query(
      `INSERT INTO face_embeddings (user_id, embedding, model_name)
       VALUES ($1, $2::vector(${dims}), $3)`,
      [userId, vector, data.model || 'Facenet512']
    );

    res.json({
      success:     true,
      message:     '🎉 Face enrolled successfully!',
      dims,
      model:       data.model || 'Facenet512',
      userId,
      vectorFormat: vector.substring(0, 40) + '...',
    });
  } catch (err) {
    console.error('❌ Enroll error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/face/verify
router.post('/verify', authenticateToken, async (req, res) => {
  try {
    const { images } = req.body;
    if (!images || images.length === 0) {
      return res.status(400).json({ error: 'No images provided' });
    }
    console.log('🔍 Verify called');

    const mlResponse = await fetch(`${ML_URL}/enroll`, {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    JSON.stringify({ image: images[0] }),
    });
    const data = await mlResponse.json();
    if (!data.embedding) {
      throw new Error(data.error || 'No embedding from ML');
    }

    const queryEmbedding = data.embedding.map(Number);
    const dims           = queryEmbedding.length;
    const vector         = `[${queryEmbedding.join(',')}]`;

    const results = await pool.query(`
      SELECT u.id, u.name, u.email, u.role,
        1 - (fe.embedding <=> $1::vector) AS similarity
      FROM face_embeddings fe
      JOIN users u ON u.id = fe.user_id
      ORDER BY fe.embedding <=> $1::vector
      LIMIT 1
    `, [vector]);

    if (!results.rows.length) {
      return res.json({ success: false, message: 'No enrolled faces found' });
    }

    const similarity = parseFloat(results.rows[0].similarity);
    console.log(`🎯 Similarity: ${similarity}`);

    if (similarity > 0.70) {
      res.json({ success: true, user: results.rows[0], similarity });
    } else {
      res.json({
        success:  false,
        message:  `No match (similarity: ${similarity})`,
        closest:  results.rows[0],
        similarity,
      });
    }
  } catch (err) {
    console.error('❌ Verify error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/face/status — check if user has enrolled face
router.get('/status', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, created_at FROM face_embeddings WHERE user_id=$1',
      [req.user.id]
    );
    res.json({
      enrolled:  result.rows.length > 0,
      enrolledAt: result.rows[0]?.created_at || null
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
