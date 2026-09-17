const express = require('express');
const router = express.Router();
const buildingController = require('../controllers/buildingController');
const { authenticate, requireRole } = require('../middlewares/authMiddleware');

// Public/Authenticated list of campus buildings
router.get('/', buildingController.getBuildings);

// Admin-only management endpoints
router.post('/', authenticate, requireRole(['admin']), buildingController.createBuilding);
router.put('/:id', authenticate, requireRole(['admin']), buildingController.updateBuilding);
router.delete('/:id', authenticate, requireRole(['admin']), buildingController.deleteBuilding);

module.exports = router;
