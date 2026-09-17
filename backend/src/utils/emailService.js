const axios = require('axios');
require('dotenv').config();

async function sendOtpEmail(toEmail, otp, purpose = 'registration') {
  const apiKey = process.env.ZEPTOMAIL_API_KEY;
  const senderEmail = process.env.ZEPTOMAIL_SENDER_EMAIL || 'noreply@annauniv.edu';
  const senderName = process.env.ZEPTOMAIL_SENDER_NAME || 'College Grievance Redressal';

  const subject = purpose === 'registration'
    ? 'Your University Grievance Portal Verification Code'
    : 'Your Password Reset Code';

  const htmlBody = `
    <div style="font-family: Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px;">
      <h2 style="color: #1a73e8; margin-bottom: 8px;">College Grievance Redressal System</h2>
      <p style="color: #555; font-size: 15px;">Hello,</p>
      <p style="color: #555; font-size: 15px;">Use the following One-Time Password (OTP) for your ${purpose}:</p>
      <div style="background-color: #f1f3f4; padding: 16px; border-radius: 6px; text-align: center; margin: 20px 0;">
        <span style="font-size: 32px; font-weight: bold; letter-spacing: 6px; color: #202124;">${otp}</span>
      </div>
      <p style="color: #777; font-size: 13px;">This code is valid for 10 minutes. Please do not share this OTP with anyone.</p>
      <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;" />
      <p style="color: #999; font-size: 11px;">Estate & Maintenance Office &bull; Anna University Campus</p>
    </div>
  `;

  if (!apiKey || apiKey.trim() === '') {
    // Development fallback
    console.log('====================================================');
    console.log(`[DEV EMAIL SIMULATION] Sending OTP to: ${toEmail}`);
    console.log(`Purpose: ${purpose} | OTP Code: ${otp}`);
    console.log('====================================================');
    return { success: true, mode: 'simulated' };
  }

  try {
    const response = await axios.post(
      'https://api.zeptomail.in/v1.1/email',
      {
        bounce_address: senderEmail,
        from: {
          address: senderEmail,
          name: senderName,
        },
        to: [
          {
            email_address: {
              address: toEmail,
              name: toEmail.split('@')[0],
            },
          },
        ],
        subject,
        htmlbody: htmlBody,
      },
      {
        headers: {
          'Content-Type': 'application/json',
          Authorization: apiKey.startsWith('Zoho-enczapikey') ? apiKey : `Zoho-enczapikey ${apiKey}`,
        },
        timeout: 10000,
      }
    );

    return { success: true, mode: 'zeptomail', data: response.data };
  } catch (error) {
    console.error('ZeptoMail Send Error:', error.response?.data || error.message);
    // Even if ZeptoMail fails in test mode, return the error details
    throw new Error(`Email delivery failed: ${error.response?.data?.message || error.message}`);
  }
}

module.exports = {
  sendOtpEmail,
};
