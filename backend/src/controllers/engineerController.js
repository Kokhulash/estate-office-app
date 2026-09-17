const db = require('../db');
const { processImageUpload } = require('../utils/storageService');

/**
 * 1. Get Engineer Triage Queue
 * - JNR sees active/assigned issues
 * - AE and Super Admin see escalated issues OR issues older than 48 hours still Submitted/In Progress
 * - Filters: Building, Issue Type, Status, Severity, Date range
 */
async function getTriageQueue(req, res) {
  try {
    const user = req.user;
    const { building_id, issue_type, status, severity, start_date, end_date, queue_type } = req.query;

    let filterClauses = [];
    let params = [];
    let paramIndex = 1;

    // Queue filtering based on role / tab
    if (user.role === 'jnr') {
      // JNR default queue: shows all active grievances or assigned
      if (queue_type === 'escalated') {
        filterClauses.push('g.escalated_at IS NOT NULL');
      }
    } else if (user.role === 'ae' || user.role === 'admin') {
      // AE and Admin queue (Section 8 & 9):
      // "Sees issues that are either: escalated manually by a JNR, or still Submitted/In Progress more than 2 days after original report time"
      if (queue_type !== 'all') {
        filterClauses.push(`(
          g.escalated_at IS NOT NULL 
          OR (g.status IN ('Submitted', 'In Progress') AND g.created_at <= NOW() - INTERVAL '48 hours')
        )`);
      }
    }

    if (building_id) {
      filterClauses.push(`g.building_id = $${paramIndex++}`);
      params.push(building_id);
    }

    if (issue_type && issue_type !== 'All') {
      filterClauses.push(`g.issue_type = $${paramIndex++}`);
      params.push(issue_type);
    }

    if (status && status !== 'All') {
      filterClauses.push(`g.status = $${paramIndex++}`);
      params.push(status);
    }

    if (severity && severity !== 'All') {
      filterClauses.push(`g.severity = $${paramIndex++}`);
      params.push(severity);
    }

    if (start_date) {
      filterClauses.push(`g.created_at >= $${paramIndex++}`);
      params.push(new Date(start_date));
    }

    if (end_date) {
      filterClauses.push(`g.created_at <= $${paramIndex++}`);
      params.push(new Date(end_date));
    }

    const whereClause = filterClauses.length > 0 ? 'WHERE ' + filterClauses.join(' AND ') : '';

    const query = `
      SELECT 
        g.id,
        g.reporter_id,
        g.is_anonymous,
        g.image_url,
        g.image_gps_lat,
        g.image_gps_lng,
        g.description,
        g.building_id,
        g.location_text,
        g.issue_type,
        g.severity,
        g.status,
        g.escalated_at,
        g.escalated_by,
        g.closing_photo_url,
        g.upvote_count,
        g.created_at,
        g.updated_at,
        b.name AS building_name,
        b.code AS building_code,
        CASE 
          WHEN g.is_anonymous = true THEN 'Anonymous'
          ELSE u.name 
        END AS reporter_display_name,
        CASE 
          WHEN g.is_anonymous = true THEN NULL
          ELSE u.email 
        END AS reporter_email,
        CASE 
          WHEN g.is_anonymous = true THEN NULL
          ELSE u.phone 
        END AS reporter_phone,
        CASE 
          WHEN g.is_anonymous = true THEN NULL
          ELSE u.department 
        END AS reporter_department,
        (g.created_at <= NOW() - INTERVAL '48 hours' AND g.status IN ('Submitted', 'In Progress')) AS is_overdue
      FROM grievances g
      LEFT JOIN buildings b ON g.building_id = b.id
      LEFT JOIN users u ON g.reporter_id = u.id
      ${whereClause}
      ORDER BY 
        CASE 
          WHEN g.escalated_at IS NOT NULL THEN 1
          WHEN g.created_at <= NOW() - INTERVAL '48 hours' AND g.status IN ('Submitted', 'In Progress') THEN 2
          WHEN g.status = 'Submitted' THEN 3
          WHEN g.status = 'In Progress' THEN 4
          ELSE 5
        END,
        g.created_at DESC;
    `;

    const result = await db.query(query, params);

    return res.status(200).json({
      success: true,
      count: result.rows.length,
      queue: result.rows,
    });
  } catch (err) {
    console.error('Triage queue error:', err);
    return res.status(500).json({ success: false, message: 'Failed to fetch triage queue.' });
  }
}

/**
 * 2. Update Ticket Status (Triage Action)
 * Status transitions: Submitted -> In Progress -> Closed Successfully / Invalid Report
 * Rule: "Closed Successfully" requires a resolution photo!
 */
async function updateTicketStatus(req, res) {
  try {
    const { id } = req.params;
    const { status, comment, severity } = req.body;
    const user = req.user;

    const VALID_STATUSES = ['Submitted', 'In Progress', 'Closed Successfully', 'Invalid Report'];
    if (!status || !VALID_STATUSES.includes(status)) {
      return res.status(400).json({
        success: false,
        message: `Status must be one of: ${VALID_STATUSES.join(', ')}`
      });
    }

    // Get current ticket
    const ticketRes = await db.query('SELECT * FROM grievances WHERE id = $1', [id]);
    if (ticketRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Grievance ticket not found.' });
    }

    const currentTicket = ticketRes.rows[0];
    let closingPhotoUrl = currentTicket.closing_photo_url;

    // RULE: Closed Successfully requires a resolution photo (camera or file picker)
    if (status === 'Closed Successfully') {
      if (req.file) {
        closingPhotoUrl = await processImageUpload(req.file, req);
      } else if (!closingPhotoUrl) {
        return res.status(400).json({
          success: false,
          message: 'Resolution photo is strictly required to mark a ticket as Closed Successfully.'
        });
      }
    }

    // Allow severity adjustment during triage (as per spec Section 6.3 / 10)
    let newSeverity = currentTicket.severity;
    if (severity && ['Low', 'Medium', 'High'].includes(severity)) {
      newSeverity = severity;
    }

    // Update ticket
    const updateRes = await db.query(`
      UPDATE grievances 
      SET 
        status = $1, 
        severity = $2,
        closing_photo_url = $3,
        updated_at = NOW()
      WHERE id = $4
      RETURNING *;
    `, [status, newSeverity, closingPhotoUrl, id]);

    // Record audit log in grievance_status_log
    await db.query(`
      INSERT INTO grievance_status_log (grievance_id, actor_id, actor_role, old_status, new_status, comment)
      VALUES ($1, $2, $3, $4, $5, $6);
    `, [id, user.id, user.role, currentTicket.status, status, comment || `Status changed to ${status}`]);

    return res.status(200).json({
      success: true,
      message: `Ticket status updated to ${status}.`,
      grievance: updateRes.rows[0],
    });
  } catch (err) {
    console.error('Update status error:', err);
    return res.status(500).json({ success: false, message: 'Failed to update ticket status: ' + err.message });
  }
}

/**
 * 3. Escalate Ticket Manually (JNR Action)
 * Moves the ticket into the AE queue immediately with a reason.
 */
async function escalateTicket(req, res) {
  try {
    const { id } = req.params;
    const { reason } = req.body;
    const user = req.user;

    if (!reason || reason.trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'A clear reason is required to escalate a grievance ticket.'
      });
    }

    const ticketRes = await db.query('SELECT * FROM grievances WHERE id = $1', [id]);
    if (ticketRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Grievance ticket not found.' });
    }

    const currentTicket = ticketRes.rows[0];

    // Update grievance escalation fields
    const updated = await db.query(`
      UPDATE grievances
      SET 
        escalated_at = NOW(),
        escalated_by = $1,
        updated_at = NOW()
      WHERE id = $2
      RETURNING *;
    `, [`${user.name} (${user.role.toUpperCase()})`, id]);

    // Log escalation in status history
    await db.query(`
      INSERT INTO grievance_status_log (grievance_id, actor_id, actor_role, old_status, new_status, comment)
      VALUES ($1, $2, $3, $4, $4, $5);
    `, [id, user.id, user.role, currentTicket.status, `ESCALATED: ${reason.trim()}`]);

    return res.status(200).json({
      success: true,
      message: 'Ticket successfully escalated to AE queue.',
      grievance: updated.rows[0],
    });
  } catch (err) {
    console.error('Escalation error:', err);
    return res.status(500).json({ success: false, message: 'Failed to escalate ticket: ' + err.message });
  }
}

/**
 * 4. Add Comment to Grievance Ticket
 */
async function addComment(req, res) {
  try {
    const { id } = req.params;
    const { comment } = req.body;
    const user = req.user;

    if (!comment || comment.trim() === '') {
      return res.status(400).json({ success: false, message: 'Comment text is required.' });
    }

    const ticketRes = await db.query('SELECT status FROM grievances WHERE id = $1', [id]);
    if (ticketRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Grievance ticket not found.' });
    }

    const currentStatus = ticketRes.rows[0].status;

    await db.query(`
      INSERT INTO grievance_status_log (grievance_id, actor_id, actor_role, old_status, new_status, comment)
      VALUES ($1, $2, $3, $4, $4, $5);
    `, [id, user.id, user.role, currentStatus, comment.trim()]);

    return res.status(201).json({
      success: true,
      message: 'Comment added successfully.',
    });
  } catch (err) {
    console.error('Add comment error:', err);
    return res.status(500).json({ success: false, message: 'Failed to add comment.' });
  }
}

module.exports = {
  getTriageQueue,
  updateTicketStatus,
  escalateTicket,
  addComment,
};
