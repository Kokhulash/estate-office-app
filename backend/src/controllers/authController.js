const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../db');
const { generateNumericOtp, setOtp, verifyOtp, recordFailedLogin, clearFailedLogin } = require('../utils/lruCache');
const { sendOtpEmail } = require('../utils/emailService');
const { generateTokens, REFRESH_SECRET } = require('../middlewares/authMiddleware');

/**
 * Helper: validate email address format (Anna University or general institutional email)
 */
function isValidEmail(email) {
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return re.test(String(email).toLowerCase());
}

/**
 * 1. Send OTP for Registration
 */
async function sendRegistrationOtp(req, res) {
  try {
    const { email } = req.body;
    if (!email || !isValidEmail(email)) {
      return res.status(400).json({ success: false, message: 'A valid university email address is required.' });
    }

    // Check if user already exists
    const existing = await db.query('SELECT id, is_verified FROM users WHERE email = $1', [email.toLowerCase()]);
    if (existing.rows.length > 0 && existing.rows[0].is_verified) {
      return res.status(400).json({ success: false, message: 'An account with this email already exists. Please log in.' });
    }

    const otp = generateNumericOtp();
    await setOtp(email, 'registration', otp);

    // Send email (via ZeptoMail or console fallback)
    await sendOtpEmail(email, otp, 'registration');

    return res.status(200).json({
      success: true,
      message: `Verification code sent to ${email}. Valid for 10 minutes.`,
    });
  } catch (err) {
    return res.status(err.statusCode || 500).json({ success: false, message: err.message });
  }
}

/**
 * 2. Verify OTP and Register Naive User
 */
async function verifyAndRegister(req, res) {
  try {
    const { name, department, email, phone, password, role = 'student', otp } = req.body;

    if (!name || !department || !email || !password || !otp) {
      return res.status(400).json({ success: false, message: 'Name, department, email, password, and OTP code are required.' });
    }

    if (password.length < 6) {
      return res.status(400).json({ success: false, message: 'Password must be at least 6 characters long.' });
    }

    // Role check: Only naive user roles can self-register
    const allowedSelfRoles = ['student', 'faculty', 'employee'];
    const chosenRole = allowedSelfRoles.includes(role) ? role : 'student';

    // Verify OTP from LRU Cache
    const otpResult = await verifyOtp(email, 'registration', otp);
    if (!otpResult.success) {
      return res.status(400).json({ success: false, message: otpResult.reason });
    }

    // Hash password
    const passwordHash = await bcrypt.hash(password, 10);

    // Insert or update user
    const insertQuery = `
      INSERT INTO users (name, department, email, phone, password_hash, role, is_verified)
      VALUES ($1, $2, $3, $4, $5, $6, true)
      ON CONFLICT (email) DO UPDATE SET
        name = EXCLUDED.name,
        department = EXCLUDED.department,
        phone = EXCLUDED.phone,
        password_hash = EXCLUDED.password_hash,
        role = EXCLUDED.role,
        is_verified = true
      RETURNING id, name, email, department, phone, role, created_at;
    `;

    const result = await db.query(insertQuery, [
      name.trim(),
      department.trim(),
      email.toLowerCase().trim(),
      phone ? phone.trim() : null,
      passwordHash,
      chosenRole,
    ]);

    const user = result.rows[0];
    const tokens = generateTokens(user);

    return res.status(201).json({
      success: true,
      message: 'Account registered and verified successfully.',
      user,
      tokens,
    });
  } catch (err) {
    console.error('Registration error:', err);
    return res.status(500).json({ success: false, message: 'Registration failed. ' + err.message });
  }
}

/**
 * 3. Login
 * Accepts university email OR username for staff, plus password.
 */
async function login(req, res) {
  try {
    const { email, username, password } = req.body;
    const identifier = (email || username || '').trim().toLowerCase();

    if (!identifier || !password) {
      return res.status(400).json({ success: false, message: 'Email/Username and password are required.' });
    }

    // Find user by email OR username (staff can login by username e.g. jnr1 or jnr1@annauniv.edu)
    let userQuery = 'SELECT * FROM users WHERE LOWER(email) = $1';
    let params = [identifier];

    if (!identifier.includes('@')) {
      // Try username match (e.g. prefix before @ in staff email)
      userQuery = 'SELECT * FROM users WHERE LOWER(email) LIKE $1';
      params = [`${identifier}@%`];
    }

    const result = await db.query(userQuery, params);
    if (result.rows.length === 0) {
      recordFailedLogin(identifier);
      return res.status(401).json({ success: false, message: 'Invalid credentials.' });
    }

    const user = result.rows[0];

    // Verify password
    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      recordFailedLogin(identifier);
      return res.status(401).json({ success: false, message: 'Invalid credentials.' });
    }

    // Clear failed login tracker on success
    clearFailedLogin(identifier);

    // Issue tokens
    const tokens = generateTokens(user);

    // Strip password hash from response
    delete user.password_hash;

    return res.status(200).json({
      success: true,
      message: 'Logged in successfully.',
      user,
      tokens,
    });
  } catch (err) {
    console.error('Login error:', err);
    return res.status(500).json({ success: false, message: 'Login failed: ' + err.message });
  }
}

/**
 * 4. Refresh Token (Rotates refresh token)
 */
async function refreshToken(req, res) {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return res.status(400).json({ success: false, message: 'Refresh token is required.' });
    }

    const decoded = jwt.verify(refreshToken, REFRESH_SECRET);
    const result = await db.query('SELECT id, name, email, role, department, phone FROM users WHERE id = $1', [decoded.userId]);

    if (result.rows.length === 0) {
      return res.status(401).json({ success: false, message: 'User account not found.' });
    }

    const user = result.rows[0];
    const newTokens = generateTokens(user);

    return res.status(200).json({
      success: true,
      tokens: newTokens,
    });
  } catch (err) {
    return res.status(401).json({ success: false, message: 'Invalid or expired refresh token.' });
  }
}

/**
 * 5. Send Forgot Password OTP
 */
async function sendForgotPasswordOtp(req, res) {
  try {
    const { email } = req.body;
    if (!email || !isValidEmail(email)) {
      return res.status(400).json({ success: false, message: 'A valid email address is required.' });
    }

    const result = await db.query('SELECT id FROM users WHERE LOWER(email) = $1', [email.toLowerCase().trim()]);
    if (result.rows.length === 0) {
      // Don't disclose user existence for security, return standard message
      return res.status(200).json({
        success: true,
        message: 'If an account exists with this email, a reset OTP has been sent.',
      });
    }

    const otp = generateNumericOtp();
    await setOtp(email, 'forgot-password', otp);
    await sendOtpEmail(email, otp, 'password reset');

    return res.status(200).json({
      success: true,
      message: `Password reset OTP sent to ${email}.`,
    });
  } catch (err) {
    return res.status(err.statusCode || 500).json({ success: false, message: err.message });
  }
}

/**
 * 6. Reset Password with OTP
 */
async function resetPassword(req, res) {
  try {
    const { email, otp, newPassword } = req.body;
    if (!email || !otp || !newPassword) {
      return res.status(400).json({ success: false, message: 'Email, OTP, and new password are required.' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ success: false, message: 'Password must be at least 6 characters long.' });
    }

    const otpResult = await verifyOtp(email, 'forgot-password', otp);
    if (!otpResult.success) {
      return res.status(400).json({ success: false, message: otpResult.reason });
    }

    const passwordHash = await bcrypt.hash(newPassword, 10);
    await db.query('UPDATE users SET password_hash = $1 WHERE LOWER(email) = $2', [passwordHash, email.toLowerCase().trim()]);

    return res.status(200).json({
      success: true,
      message: 'Password reset successfully. You can now log in with your new password.',
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Password reset failed: ' + err.message });
  }
}

/**
 * 7. Get Current User Profile
 */
async function getMe(req, res) {
  return res.status(200).json({
    success: true,
    user: req.user,
  });
}

module.exports = {
  sendRegistrationOtp,
  verifyAndRegister,
  login,
  refreshToken,
  sendForgotPasswordOtp,
  resetPassword,
  getMe,
};
