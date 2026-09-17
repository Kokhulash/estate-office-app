const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { authenticate } = require('../middlewares/authMiddleware');
const { otpRateLimiter, loginLockoutCheck } = require('../middlewares/rateLimiter');

// Registration flow
router.post('/register/send-otp', otpRateLimiter, authController.sendRegistrationOtp);
router.post('/register/verify-and-register', authController.verifyAndRegister);

// Login & Session
router.post('/login', loginLockoutCheck, authController.login);
router.post('/refresh-token', authController.refreshToken);

// Forgot password flow
router.post('/forgot-password/send-otp', otpRateLimiter, authController.sendForgotPasswordOtp);
router.post('/forgot-password/reset', authController.resetPassword);

// Profile
router.get('/me', authenticate, authController.getMe);

module.exports = router;
