const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const { authenticate, requireRole } = require('../middlewares/authMiddleware');

// Super Admin Analytics (Full dataset)
router.get('/analytics', authenticate, requireRole(['admin']), adminController.getAnalytics);

// Staff Management: Super Admin can create AE & JNR; AE can create JNR
router.post('/users', authenticate, requireRole(['admin', 'ae']), adminController.createStaffAccount);

// List Staff Accounts
router.get('/users', authenticate, requireRole(['admin', 'ae']), adminController.listStaffAccounts);

module.exports = router;
