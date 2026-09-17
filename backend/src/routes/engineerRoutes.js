const express = require('express');
const router = express.Router();
const engineerController = require('../controllers/engineerController');
const { authenticate, requireRole } = require('../middlewares/authMiddleware');
const { upload } = require('../utils/storageService');

// All engineer operations require engineer/admin role
router.use(authenticate, requireRole(['jnr', 'ae', 'admin']));

// Triage queue with filters
router.get('/queue', engineerController.getTriageQueue);

// Update status (Closing ticket requires resolution photo)
router.patch('/:id/status', upload.single('resolution_photo'), engineerController.updateTicketStatus);

// Manual escalation (JNR / AE)
router.post('/:id/escalate', engineerController.escalateTicket);

// Add internal comment
router.post('/:id/comment', engineerController.addComment);

module.exports = router;
