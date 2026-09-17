const db = require('../db');

/**
 * Get all buildings (ordered by name)
 */
async function getBuildings(req, res) {
  try {
    const result = await db.query('SELECT id, name, code FROM buildings ORDER BY name ASC');
    return res.status(200).json({
      success: true,
      buildings: result.rows,
    });
  } catch (err) {
    console.error('Error fetching buildings:', err);
    return res.status(500).json({ success: false, message: 'Failed to fetch buildings.' });
  }
}

/**
 * Create new building (Admin only)
 */
async function createBuilding(req, res) {
  try {
    const { name, code } = req.body;
    if (!name || !code) {
      return res.status(400).json({ success: false, message: 'Building name and code are required.' });
    }

    const result = await db.query(
      'INSERT INTO buildings (name, code) VALUES ($1, $2) RETURNING id, name, code',
      [name.trim(), code.trim().toUpperCase()]
    );

    return res.status(201).json({
      success: true,
      building: result.rows[0],
      message: 'Building added successfully.',
    });
  } catch (err) {
    if (err.code === '23505') {
      return res.status(400).json({ success: false, message: 'A building with this code already exists.' });
    }
    return res.status(500).json({ success: false, message: 'Failed to create building: ' + err.message });
  }
}

/**
 * Update building (Admin only)
 */
async function updateBuilding(req, res) {
  try {
    const { id } = req.params;
    const { name, code } = req.body;

    if (!name || !code) {
      return res.status(400).json({ success: false, message: 'Building name and code are required.' });
    }

    const result = await db.query(
      'UPDATE buildings SET name = $1, code = $2 WHERE id = $3 RETURNING id, name, code',
      [name.trim(), code.trim().toUpperCase(), id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Building not found.' });
    }

    return res.status(200).json({
      success: true,
      building: result.rows[0],
      message: 'Building updated successfully.',
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Failed to update building: ' + err.message });
  }
}

/**
 * Delete building (Admin only)
 */
async function deleteBuilding(req, res) {
  try {
    const { id } = req.params;

    // Check if any grievance uses this building
    const checkGrievances = await db.query('SELECT id FROM grievances WHERE building_id = $1 LIMIT 1', [id]);
    if (checkGrievances.rows.length > 0) {
      return res.status(400).json({
        success: false,
        message: 'Cannot delete building: active grievances are linked to this building.',
      });
    }

    const result = await db.query('DELETE FROM buildings WHERE id = $1 RETURNING id', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Building not found.' });
    }

    return res.status(200).json({
      success: true,
      message: 'Building deleted successfully.',
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Failed to delete building: ' + err.message });
  }
}

module.exports = {
  getBuildings,
  createBuilding,
  updateBuilding,
  deleteBuilding,
};
