const { Pool } = require('pg');

const pool = new Pool({
  connectionString: 'postgresql://localhost/faceattend'
});

module.exports = { pool };
