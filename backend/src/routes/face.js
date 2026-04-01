const express = require('express');
const router = express.Router();
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));
const { pool } = require('../db');

const ML_SERVICE = 'http://localhost:8001';

router.post('/enroll', async (req, res) => {
  try {
    // ✅ BYPASS JWT - userId=4 for demo
    const userId = 4;
    const { images } = req.body;
    
    console.log('🤖 Enrolling user 4...');
    
    const mlResponse = await fetch(`${ML_SERVICE}/enroll`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ images })
    });
    
    const mlData = await mlResponse.json();
    
    // 🔥 CRITICAL pgvector FIX
    let embedding = Array.isArray(mlData.embedding) ? mlData.embedding : JSON.parse(mlData.embedding);
    
    // ✅ FORMAT: [0.1,0.2,0.3] for pgvector
    const vectorEmbedding = `[${embedding.map(x => parseFloat(x)).join(',')}]`;
    
    console.log(`📊 pgvector format: ${vectorEmbedding.slice(0, 50)}... (${embedding.length} dims)`);
    
    await pool.query(
      'INSERT INTO face_embeddings (user_id, embedding, model_name) VALUES ($1, $2::vector(512), $3)',
      [userId, vectorEmbedding, mlData.model]
    );
    
    res.json({ 
      success: true, 
      message: '🎉 Face enrolled successfully!',
      dims: embedding.length, 
      model: mlData.model,
      userId,
      vectorFormat: vectorEmbedding.slice(0, 50) + '...'
    });
  } catch (err) {
    console.error('❌ Enroll error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

router.post('/verify', async (req, res) => {
  try {
    const { images } = req.body;
    
    const mlResponse = await fetch(`${ML_SERVICE}/enroll`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ images })
    });
    
    const mlData = await mlResponse.json();
    let queryEmbedding = Array.isArray(mlData.embedding) ? mlData.embedding : JSON.parse(mlData.embedding);
    
    // 🔥 pgvector FIX for query
    const vectorQuery = `[${queryEmbedding.map(x => parseFloat(x)).join(',')}]`;
    
    const results = await pool.query(`
      SELECT u.id, u.name, u.email, u.role, 
             1 - (fe.embedding <=> $1::vector) as similarity
      FROM face_embeddings fe
      JOIN users u ON u.id = fe.user_id
      ORDER BY fe.embedding <=> $1::vector
      LIMIT 1
    `, [vectorQuery]);
    
    const similarity = results.rows[0]?.similarity || 0;
    
    if (parseFloat(similarity) > 0.7) {
      res.json({
        success: true,
        user: results.rows[0],
        similarity: parseFloat(similarity)
      });
    } else {
      res.json({ 
        success: false, 
        message: `No match (similarity: ${similarity})`,
        closest: results.rows[0]
      });
    }
  } catch (err) {
    console.error('❌ Verify error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
