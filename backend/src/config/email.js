const nodemailer = require('nodemailer');
require('dotenv').config();

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

async function sendInvitationEmail(to, name, role, orgName, tempPassword, token) {
  const acceptUrl = `http://localhost:3000/api/invitations/accept/${token}`;
  const html = `
    <div style="font-family:Arial,sans-serif;max-width:600px;margin:auto;padding:24px;border:1px solid #e0e0e0;border-radius:8px;">
      <div style="background:#1A237E;padding:20px;border-radius:8px 8px 0 0;text-align:center;">
        <h1 style="color:white;margin:0;">FaceAttend</h1>
        <p style="color:#80CBC4;margin:4px 0 0;">Smart Attendance. Powered by AI.</p>
      </div>
      <div style="padding:24px;">
        <h2 style="color:#1A237E;">Welcome, ${name}!</h2>
        <p>You have been invited to join <strong>${orgName}</strong> as a <strong>${role}</strong>.</p>
        <div style="background:#f5f5f5;padding:16px;border-radius:8px;margin:16px 0;">
          <p style="margin:0;"><strong>Your login credentials:</strong></p>
          <p style="margin:8px 0;">Email: <strong>${to}</strong></p>
          <p style="margin:0;">Temporary Password: <strong>${tempPassword}</strong></p>
        </div>
        <p>Please click the button below to accept your invitation and activate your account:</p>
        <a href="${acceptUrl}" style="display:inline-block;background:#00897B;color:white;padding:12px 24px;border-radius:8px;text-decoration:none;font-weight:bold;">Accept Invitation</a>
        <p style="color:#999;font-size:12px;margin-top:24px;">This invitation expires in 7 days. If you did not expect this email, please ignore it.</p>
      </div>
    </div>
  `;
  await transporter.sendMail({
    from: `"FaceAttend" <${process.env.EMAIL_USER}>`,
    to,
    subject: `You're invited to join ${orgName} on FaceAttend`,
    html,
  });
}

async function sendSessionInviteEmail(to, name, sessionTitle, className, scheduledAt, meetingLink) {
  const html = `
    <div style="font-family:Arial,sans-serif;max-width:600px;margin:auto;padding:24px;border:1px solid #e0e0e0;border-radius:8px;">
      <div style="background:#1A237E;padding:20px;border-radius:8px 8px 0 0;text-align:center;">
        <h1 style="color:white;margin:0;">FaceAttend</h1>
      </div>
      <div style="padding:24px;">
        <h2 style="color:#1A237E;">Session Invitation</h2>
        <p>Hi <strong>${name}</strong>,</p>
        <p>You have been invited to an attendance session:</p>
        <div style="background:#f5f5f5;padding:16px;border-radius:8px;margin:16px 0;">
          <p style="margin:0;"><strong>Session:</strong> ${sessionTitle}</p>
          <p style="margin:8px 0;"><strong>Class:</strong> ${className}</p>
          <p style="margin:8px 0;"><strong>Scheduled:</strong> ${new Date(scheduledAt).toLocaleString()}</p>
          ${meetingLink ? `<p style="margin:0;"><strong>Meeting Link:</strong> <a href="${meetingLink}">${meetingLink}</a></p>` : ''}
        </div>
        <p>Open the FaceAttend app to mark your attendance when the session goes live.</p>
      </div>
    </div>
  `;
  await transporter.sendMail({
    from: `"FaceAttend" <${process.env.EMAIL_USER}>`,
    to,
    subject: `Session Invitation: ${sessionTitle} — ${className}`,
    html,
  });
}

module.exports = { sendInvitationEmail, sendSessionInviteEmail };
