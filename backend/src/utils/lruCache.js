const { LRUCache } = require('lru-cache');
const bcrypt = require('bcryptjs');

// Options for LRU Cache: 10,000 items, default TTL 15 minutes
const cache = new LRUCache({
  max: 10000,
  ttl: 15 * 60 * 1000, // 15 minutes default
});

/**
 * OTP Utilities
 */
const OTP_EXPIRY_MS = 10 * 60 * 1000; // 10 minutes
const OTP_RESEND_COOLDOWN_MS = 60 * 1000; // 60 seconds
const MAX_OTP_ATTEMPTS = 5;

function generateNumericOtp() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

async function setOtp(email, purpose, otp) {
  const key = `otp:${email.toLowerCase()}:${purpose}`;
  const hashedCode = await bcrypt.hash(otp, 10);
  const now = Date.now();

  const existing = cache.get(key);
  if (existing && (now - existing.createdAt < OTP_RESEND_COOLDOWN_MS)) {
    const secondsRemaining = Math.ceil((OTP_RESEND_COOLDOWN_MS - (now - existing.createdAt)) / 1000);
    const error = new Error(`Please wait ${secondsRemaining}s before requesting a new OTP.`);
    error.statusCode = 429;
    throw error;
  }

  cache.set(key, {
    hashedCode,
    attempts: 0,
    createdAt: now,
  }, { ttl: OTP_EXPIRY_MS });

  return otp;
}

async function verifyOtp(email, purpose, enteredOtp) {
  const key = `otp:${email.toLowerCase()}:${purpose}`;
  const data = cache.get(key);

  if (!data) {
    return { success: false, reason: 'OTP expired or not found. Please request a new code.' };
  }

  if (data.attempts >= MAX_OTP_ATTEMPTS) {
    cache.delete(key);
    return { success: false, reason: 'Maximum OTP verification attempts exceeded. Please request a new code.' };
  }

  data.attempts += 1;
  cache.set(key, data, { ttl: OTP_EXPIRY_MS });

  const isMatch = await bcrypt.compare(enteredOtp.trim(), data.hashedCode);
  if (!isMatch) {
    const remaining = MAX_OTP_ATTEMPTS - data.attempts;
    return {
      success: false,
      reason: remaining > 0 
        ? `Incorrect OTP. ${remaining} attempt(s) remaining.` 
        : 'Maximum OTP verification attempts exceeded. Code invalidated.'
    };
  }

  // OTP verified successfully -> invalidate immediately
  cache.delete(key);
  return { success: true };
}

/**
 * Rate Limiting Utilities using LRU Cache
 */
function checkRateLimit(key, limit, windowMs) {
  const record = cache.get(key) || { count: 0, firstAccess: Date.now() };
  const now = Date.now();

  if (now - record.firstAccess > windowMs) {
    record.count = 1;
    record.firstAccess = now;
  } else {
    record.count += 1;
  }

  cache.set(key, record, { ttl: windowMs });

  if (record.count > limit) {
    return false; // limit exceeded
  }
  return true;
}

// Failed login tracker: lock account/IP after 5 failed attempts for 15 minutes
function recordFailedLogin(identifier) {
  const key = `failed_login:${identifier.toLowerCase()}`;
  const record = cache.get(key) || { count: 0, lockedUntil: 0 };
  const now = Date.now();

  record.count += 1;
  if (record.count >= 5) {
    record.lockedUntil = now + (15 * 60 * 1000); // 15 minutes lockout
  }
  cache.set(key, record, { ttl: 15 * 60 * 1000 });
}

function clearFailedLogin(identifier) {
  cache.delete(`failed_login:${identifier.toLowerCase()}`);
}

function isLoginLocked(identifier) {
  const key = `failed_login:${identifier.toLowerCase()}`;
  const record = cache.get(key);
  if (record && record.lockedUntil > Date.now()) {
    const minutesLeft = Math.ceil((record.lockedUntil - Date.now()) / (60 * 1000));
    return { locked: true, minutesLeft };
  }
  return { locked: false };
}

module.exports = {
  cache,
  generateNumericOtp,
  setOtp,
  verifyOtp,
  checkRateLimit,
  recordFailedLogin,
  clearFailedLogin,
  isLoginLocked,
};
