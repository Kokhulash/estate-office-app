const express = require('express');
const router = express.Router();
const grievanceController = require('../controllers/grievanceController');
const { authenticate } = require('../middlewares/authMiddleware');
const { upload } = require('../utils/storageService');

// All grievance operations require authentication
router.use(authenticate);

// Submit new grievance (camera image required)
router.post('/', upload.single('image'), grievanceController.createGrievance);

// Community feed across all users (reporter identities masked)
router.get('/feed', grievanceController.getCommunityFeed);

// Personal filed grievances
router.get('/my', grievanceController.getMyGrievances);

// Single grievance detail with status timeline
router.get('/:id', grievanceController.getGrievanceById);

// Upvote toggle (1 vote per user)
router.post('/:id/upvote', grievanceController.toggleUpvote);

module.exports = router;
