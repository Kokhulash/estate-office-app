const db = require('../db');
const { processImageUpload } = require('../utils/storageService');

const VALID_ISSUE_TYPES = ['Civil', 'Electrical', 'Cleaning', 'Bathroom Related Issues', 'Others'];
const VALID_SEVERITIES = ['Low', 'Medium', 'High'];

/**
 * 1. Submit a Grievance
 */
async function createGrievance(req, res) {
  try {
    const {
      description,
      building_id,
      location_text,
      issue_type,
      severity = 'Medium',
      is_anonymous,
      image_gps_lat,
      image_gps_lng,
      image_captured_at,
    } = req.body;

    // Validate image presence
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'Image capture is required.' });
    }

    // Validate issue type
    if (!issue_type || !VALID_ISSUE_TYPES.includes(issue_type)) {
      return res.status(400).json({
        success: false,
        message: `Issue type must be one of: ${VALID_ISSUE_TYPES.join(', ')}`
      });
    }

    // Rule: Issue Description is required if Issue Type is "Others"
    if (issue_type === 'Others' && (!description || description.trim() === '')) {
      return res.status(400).json({
        success: false,
        message: 'Description is required when Issue Type is "Others".'
      });
    }

    // Validate building
    if (!building_id) {
      return res.status(400).json({ success: false, message: 'Campus building selection is required.' });
    }

    const buildingCheck = await db.query('SELECT id FROM buildings WHERE id = $1', [building_id]);
    if (buildingCheck.rows.length === 0) {
      return res.status(400).json({ success: false, message: 'Selected building does not exist.' });
    }

    // Validate severity
    const finalSeverity = VALID_SEVERITIES.includes(severity) ? severity : 'Medium';
    const isAnonymousBool = is_anonymous === 'true' || is_anonymous === true;

    // Process image upload (Cloudinary or local static fallback)
    const imageUrl = await processImageUpload(req.file, req);

    // Parse GPS & Timestamp (never returned to standard user in UI)
    const lat = image_gps_lat ? parseFloat(image_gps_lat) : null;
    const lng = image_gps_lng ? parseFloat(image_gps_lng) : null;
    const capturedAt = image_captured_at ? new Date(image_captured_at) : new Date();

    // Insert grievance record
    const insertQuery = `
      INSERT INTO grievances (
        reporter_id, is_anonymous, image_url, image_gps_lat, image_gps_lng,
        image_captured_at, description, building_id, location_text,
        issue_type, severity, status, created_at, updated_at
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'Submitted', NOW(), NOW()
      )
      RETURNING id, is_anonymous, image_url, description, building_id,
                location_text, issue_type, severity, status, upvote_count, created_at;
    `;

    const result = await db.query(insertQuery, [
      req.user.id,
      isAnonymousBool,
      imageUrl,
      lat,
      lng,
      capturedAt,
      description ? description.trim() : null,
      building_id,
      location_text ? location_text.trim() : null,
      issue_type,
      finalSeverity,
    ]);

    const grievance = result.rows[0];

    // Log initial status submission in audit trail
    await db.query(`
      INSERT INTO grievance_status_log (grievance_id, actor_id, actor_role, old_status, new_status, comment)
      VALUES ($1, $2, $3, NULL, 'Submitted', 'Grievance submitted by reporter')
    `, [grievance.id, req.user.id, req.user.role]);

    return res.status(201).json({
      success: true,
      message: 'Grievance reported successfully.',
      grievance,
    });
  } catch (err) {
    console.error('Create grievance error:', err);
    return res.status(500).json({ success: false, message: 'Failed to submit grievance: ' + err.message });
  }
}

/**
 * 2. Community Feed
 * Section 6.4: Reporter identity is NEVER shown in the feed across all items.
 * Shows Submitted & In Progress issues first by default, filterable by status chips.
 */
async function getCommunityFeed(req, res) {
  try {
    const { status, building_id, issue_type, limit = 50, offset = 0 } = req.query;
    const userId = req.user.id;

    let filterClauses = [];
    let params = [];
    let paramIndex = 1;

    if (status && status !== 'All') {
      filterClauses.push(`g.status = $${paramIndex++}`);
      params.push(status);
    }

    if (building_id) {
      filterClauses.push(`g.building_id = $${paramIndex++}`);
      params.push(building_id);
    }

    if (issue_type && issue_type !== 'All') {
      filterClauses.push(`g.issue_type = $${paramIndex++}`);
      params.push(issue_type);
    }

    const whereClause = filterClauses.length > 0 ? 'WHERE ' + filterClauses.join(' AND ') : '';

    // Order: Submitted and In Progress first, then most recent
    const query = `
      SELECT 
        g.id,
        g.image_url,
        g.description,
        g.issue_type,
        g.severity,
        g.status,
        g.location_text,
        g.upvote_count,
        g.closing_photo_url,
        g.created_at,
        b.name AS building_name,
        b.code AS building_code,
        EXISTS(
          SELECT 1 FROM grievance_upvotes u 
          WHERE u.grievance_id = g.id AND u.user_id = $${paramIndex}
        ) AS has_upvoted
      FROM grievances g
      LEFT JOIN buildings b ON g.building_id = b.id
      ${whereClause}
      ORDER BY 
        CASE 
          WHEN g.status = 'Submitted' THEN 1
          WHEN g.status = 'In Progress' THEN 2
          WHEN g.status = 'Closed Successfully' THEN 3
          ELSE 4
        END,
        g.created_at DESC
      LIMIT $${paramIndex + 1} OFFSET $${paramIndex + 2};
    `;

    params.push(userId, parseInt(limit, 10), parseInt(offset, 10));

    const result = await db.query(query, params);

    return res.status(200).json({
      success: true,
      feed: result.rows,
    });
  } catch (err) {
    console.error('Community feed error:', err);
    return res.status(500).json({ success: false, message: 'Failed to load community feed.' });
  }
}

/**
 * 3. User's Personal Past Issues
 */
async function getMyGrievances(req, res) {
  try {
    const userId = req.user.id;
    const query = `
      SELECT 
        g.id,
        g.image_url,
        g.description,
        g.issue_type,
        g.severity,
        g.status,
        g.location_text,
        g.is_anonymous,
        g.upvote_count,
        g.closing_photo_url,
        g.created_at,
        g.updated_at,
        b.name AS building_name,
        b.code AS building_code
      FROM grievances g
      LEFT JOIN buildings b ON g.building_id = b.id
      WHERE g.reporter_id = $1
      ORDER BY g.created_at DESC;
    `;

    const result = await db.query(query, [userId]);

    return res.status(200).json({
      success: true,
      grievances: result.rows,
    });
  } catch (err) {
    console.error('Past issues error:', err);
    return res.status(500).json({ success: false, message: 'Failed to load your past grievances.' });
  }
}

/**
 * 4. Get Single Grievance Detail with Status History Logs
 */
async function getGrievanceById(req, res) {
  try {
    const { id } = req.params;
    const user = req.user;

    const query = `
      SELECT 
        g.*,
        b.name AS building_name,
        b.code AS building_code,
        u.name AS reporter_name,
        u.email AS reporter_email,
        u.phone AS reporter_phone,
        u.department AS reporter_department,
        EXISTS(
          SELECT 1 FROM grievance_upvotes uv 
          WHERE uv.grievance_id = g.id AND uv.user_id = $2
        ) AS has_upvoted
      FROM grievances g
      LEFT JOIN buildings b ON g.building_id = b.id
      LEFT JOIN users u ON g.reporter_id = u.id
      WHERE g.id = $1;
    `;

    const result = await db.query(query, [id, user.id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Grievance not found.' });
    }

    const grievance = result.rows[0];

    // Status log history
    const logsResult = await db.query(`
      SELECT 
        l.id,
        l.old_status,
        l.new_status,
        l.comment,
        l.actor_role,
        l.created_at,
        u.name AS actor_name
      FROM grievance_status_log l
      LEFT JOIN users u ON l.actor_id = u.id
      WHERE l.grievance_id = $1
      ORDER BY l.created_at ASC;
    `, [id]);

    grievance.status_history = logsResult.rows;

    // Apply Anonymity Rules (Section 12):
    // If grievance is anonymous, and current user is NOT the reporter:
    // mask reporter_name, reporter_email, reporter_phone
    const isOwner = grievance.reporter_id === user.id;
    if (grievance.is_anonymous && !isOwner) {
      grievance.reporter_name = 'Anonymous';
      grievance.reporter_email = null;
      grievance.reporter_phone = null;
      grievance.reporter_department = null;
    }

    // Never disclose server-side GPS coordinates to naive users in standard UI
    if (['student', 'faculty', 'employee'].includes(user.role)) {
      delete grievance.image_gps_lat;
      delete grievance.image_gps_lng;
    }

    return res.status(200).json({
      success: true,
      grievance,
    });
  } catch (err) {
    console.error('Error fetching grievance detail:', err);
    return res.status(500).json({ success: false, message: 'Failed to fetch grievance detail.' });
  }
}

/**
 * 5. Upvote Toggle (One vote per user per grievance)
 */
async function toggleUpvote(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    // Check if already upvoted
    const existing = await db.query(
      'SELECT id FROM grievance_upvotes WHERE grievance_id = $1 AND user_id = $2',
      [id, userId]
    );

    let hasUpvoted = false;

    if (existing.rows.length > 0) {
      // Remove upvote
      await db.query(
        'DELETE FROM grievance_upvotes WHERE grievance_id = $1 AND user_id = $2',
        [id, userId]
      );
      await db.query(
        'UPDATE grievances SET upvote_count = GREATEST(0, upvote_count - 1) WHERE id = $1',
        [id]
      );
      hasUpvoted = false;
    } else {
      // Add upvote
      await db.query(
        'INSERT INTO grievance_upvotes (grievance_id, user_id) VALUES ($1, $2)',
        [id, userId]
      );
      await db.query(
        'UPDATE grievances SET upvote_count = upvote_count + 1 WHERE id = $1',
        [id]
      );
      hasUpvoted = true;
    }

    // Get current count
    const countRes = await db.query('SELECT upvote_count FROM grievances WHERE id = $1', [id]);
    const upvoteCount = countRes.rows[0]?.upvote_count || 0;

    return res.status(200).json({
      success: true,
      has_upvoted: hasUpvoted,
      upvote_count: upvoteCount,
    });
  } catch (err) {
    console.error('Upvote error:', err);
    return res.status(500).json({ success: false, message: 'Failed to update upvote.' });
  }
}

module.exports = {
  createGrievance,
  getCommunityFeed,
  getMyGrievances,
  getGrievanceById,
  toggleUpvote,
};
