const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'faceattend',
  user: process.env.DB_USER || 'subrahmanyahegde',
  password: process.env.DB_PASS || 'SGH@2026',
});

async function migrate() {
  try {
    await pool.query(`
      CREATE EXTENSION IF NOT EXISTS vector;

      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'teacher', 'student')),
        name VARCHAR(100) NOT NULL,
        email VARCHAR(100) UNIQUE NOT NULL,
        password_hash VARCHAR(255),
        created_at TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS face_embeddings (
        id SERIAL PRIMARY KEY,
        user_id INT REFERENCES users(id) ON DELETE CASCADE,
        embedding VECTOR(512),
        image_path VARCHAR(500),
        model_name VARCHAR(50),
        created_at TIMESTAMP DEFAULT NOW()
      );

      CREATE INDEX IF NOT EXISTS face_embeddings_user_idx ON face_embeddings(user_id);
      CREATE INDEX IF NOT EXISTS face_embeddings_hnsw ON face_embeddings USING hnsw (embedding vector_cosine_ops);

      CREATE TABLE IF NOT EXISTS attendance (
        id SERIAL PRIMARY KEY,
        user_id INT REFERENCES users(id) ON DELETE CASCADE,
        session_date DATE NOT NULL,
        check_in TIMESTAMP DEFAULT NOW(),
        embedding   vector(512) NOT NULL,
        confidence FLOAT CHECK (confidence BETWEEN 0 AND 1)
      );

      CREATE INDEX IF NOT EXISTS attendance_user_date_idx ON attendance(user_id, session_date);
    `);
    console.log('✅ Tables created: users, face_embeddings, attendance');
  } catch (err) {
    console.error('❌ Error:', err.message);
  } finally {
    pool.end();
  }
}

migrate();
