const { checkRateLimit, isLoginLocked } = require('../utils/lruCache');

// Max 10 OTP requests per email/IP per hour
function otpRateLimiter(req, res, next) {
  const email = req.body.email ? req.body.email.toLowerCase() : '';
  const ip = req.ip || req.connection.remoteAddress || '127.0.0.1';

  const emailKey = `ratelimit:otp:email:${email}`;
  const ipKey = `ratelimit:otp:ip:${ip}`;

  // Allow up to 10 OTP requests per hour (3600000 ms)
  const isEmailAllowed = checkRateLimit(emailKey, 10, 60 * 60 * 1000);
  const isIpAllowed = checkRateLimit(ipKey, 20, 60 * 60 * 1000);

  if (!isEmailAllowed || !isIpAllowed) {
    return res.status(429).json({
      success: false,
      message: 'Too many OTP requests. Please try again after an hour.'
    });
  }

  next();
}

// Check if user is temporarily locked out due to repeated failed logins
function loginLockoutCheck(req, res, next) {
  const identifier = req.body.email || req.body.username || '';
  if (!identifier) {
    return res.status(400).json({ success: false, message: 'Email or username is required.' });
  }

  const { locked, minutesLeft } = isLoginLocked(identifier);
  if (locked) {
    return res.status(429).json({
      success: false,
      message: `Account is temporarily locked due to multiple failed login attempts. Please try again in ${minutesLeft} minute(s).`
    });
  }

  next();
}

module.exports = {
  otpRateLimiter,
  loginLockoutCheck,
};
