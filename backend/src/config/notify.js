const { pool } = require('../db');

async function sendNotification(userId, title, message, type = 'alert') {
  try {
    await pool.query(
      `INSERT INTO notifications (user_id, title, message, type, created_at)
       VALUES ($1, $2, $3, $4, NOW())`,
      [userId, title, message, type]
    );
    console.log(`Notification sent to user ${userId}: ${title}`);
  } catch (err) {
    console.error('Notification error:', err.message);
  }
}

module.exports = { sendNotification };
