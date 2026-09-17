const bcrypt = require('bcryptjs');
const db = require('../db');

/**
 * 1. Super Admin Full Dataset Analytics
 */
async function getAnalytics(req, res) {
  try {
    // 1. Overall counts: Total, Open (Submitted/In Progress), Closed Successfully, Invalid
    const countStats = await db.query(`
      SELECT 
        COUNT(*)::int AS total_issues,
        COUNT(CASE WHEN status = 'Submitted' THEN 1 END)::int AS submitted_count,
        COUNT(CASE WHEN status = 'In Progress' THEN 1 END)::int AS in_progress_count,
        COUNT(CASE WHEN status = 'Closed Successfully' THEN 1 END)::int AS closed_count,
        COUNT(CASE WHEN status = 'Invalid Report' THEN 1 END)::int AS invalid_count,
        COUNT(CASE WHEN escalated_at IS NOT NULL THEN 1 END)::int AS escalated_count,
        COUNT(CASE WHEN status IN ('Submitted', 'In Progress') AND created_at <= NOW() - INTERVAL '48 hours' THEN 1 END)::int AS overdue_count
      FROM grievances;
    `);

    const summary = countStats.rows[0];
    const total = summary.total_issues || 0;
    const escalationRate = total > 0 ? ((summary.escalated_count / total) * 100).toFixed(1) : 0;

    // 2. Average Resolution Time (in hours) broken down by Building, Issue Type, and Severity
    // Calculated for tickets with status = 'Closed Successfully' (difference between created_at and updated_at)
    const avgResolutionTime = await db.query(`
      SELECT 
        ROUND(AVG(EXTRACT(EPOCH FROM (updated_at - created_at)) / 3600)::numeric, 1) AS overall_avg_hours
      FROM grievances 
      WHERE status = 'Closed Successfully';
    `);

    // By Issue Type
    const resolutionByIssueType = await db.query(`
      SELECT 
        issue_type,
        COUNT(*)::int AS count,
        ROUND(AVG(EXTRACT(EPOCH FROM (updated_at - created_at)) / 3600)::numeric, 1) AS avg_hours
      FROM grievances
      WHERE status = 'Closed Successfully'
      GROUP BY issue_type;
    `);

    // By Building
    const resolutionByBuilding = await db.query(`
      SELECT 
        b.name AS building_name,
        b.code AS building_code,
        COUNT(g.id)::int AS count,
        ROUND(AVG(EXTRACT(EPOCH FROM (g.updated_at - g.created_at)) / 3600)::numeric, 1) AS avg_hours
      FROM grievances g
      JOIN buildings b ON g.building_id = b.id
      WHERE g.status = 'Closed Successfully'
      GROUP BY b.id, b.name, b.code;
    `);

    // By Severity
    const resolutionBySeverity = await db.query(`
      SELECT 
        severity,
        COUNT(*)::int AS count,
        ROUND(AVG(EXTRACT(EPOCH FROM (updated_at - created_at)) / 3600)::numeric, 1) AS avg_hours
      FROM grievances
      WHERE status = 'Closed Successfully'
      GROUP BY severity;
    `);

    // 3. Breakdown by Issue Type (all tickets)
    const breakdownByType = await db.query(`
      SELECT issue_type, COUNT(*)::int AS count
      FROM grievances
      GROUP BY issue_type
      ORDER BY count DESC;
    `);

    // 4. Breakdown by Severity (all tickets)
    const breakdownBySeverity = await db.query(`
      SELECT severity, COUNT(*)::int AS count
      FROM grievances
      GROUP BY severity;
    `);

    // 5. Top Buildings by Volume
    const topBuildings = await db.query(`
      SELECT 
        b.name AS building_name,
        b.code AS building_code,
        COUNT(g.id)::int AS volume
      FROM buildings b
      LEFT JOIN grievances g ON b.id = g.building_id
      GROUP BY b.id, b.name, b.code
      ORDER BY volume DESC
      LIMIT 5;
    `);

    // 6. Tickets Closed per Engineer (Performance audit from status log)
    const engineerPerformance = await db.query(`
      SELECT 
        u.id AS engineer_id,
        u.name AS engineer_name,
        u.role AS engineer_role,
        COUNT(l.id)::int AS tickets_closed
      FROM users u
      JOIN grievance_status_log l ON u.id = l.actor_id
      WHERE l.new_status = 'Closed Successfully' AND u.role IN ('jnr', 'ae', 'admin')
      GROUP BY u.id, u.name, u.role
      ORDER BY tickets_closed DESC;
    `);

    // 7. Volume Over Time (Last 7 days daily counts)
    const volumeOverTime = await db.query(`
      SELECT 
        TO_CHAR(d.day, 'YYYY-MM-DD') AS date,
        COUNT(g.id)::int AS count
      FROM (
        SELECT generate_series(CURRENT_DATE - INTERVAL '6 days', CURRENT_DATE, '1 day'::interval)::date AS day
      ) d
      LEFT JOIN grievances g ON DATE(g.created_at) = d.day
      GROUP BY d.day
      ORDER BY d.day ASC;
    `);

    return res.status(200).json({
      success: true,
      analytics: {
        summary: {
          ...summary,
          escalation_rate_percent: parseFloat(escalationRate),
          overall_avg_resolution_hours: avgResolutionTime.rows[0]?.overall_avg_hours || 0,
        },
        volume_over_time: volumeOverTime.rows,
        top_buildings: topBuildings.rows,
        breakdown_by_type: breakdownByType.rows,
        breakdown_by_severity: breakdownBySeverity.rows,
        resolution_by_type: resolutionByIssueType.rows,
        resolution_by_building: resolutionByBuilding.rows,
        resolution_by_severity: resolutionBySeverity.rows,
        engineer_performance: engineerPerformance.rows,
      }
    });
  } catch (err) {
    console.error('Analytics query error:', err);
    return res.status(500).json({ success: false, message: 'Failed to compute analytics: ' + err.message });
  }
}

/**
 * 2. Create Staff Account
 * Super Admin can create AE and JNR accounts.
 * AE Engineer can create JNR accounts.
 */
async function createStaffAccount(req, res) {
  try {
    const actor = req.user;
    const { name, email, phone, department, password, role } = req.body;

    if (!name || !email || !password || !role) {
      return res.status(400).json({ success: false, message: 'Name, email/username, password, and role are required.' });
    }

    if (password.length < 6) {
      return res.status(400).json({ success: false, message: 'Password must be at least 6 characters.' });
    }

    // Role creation permission rules
    if (actor.role === 'ae' && role !== 'jnr') {
      return res.status(403).json({ success: false, message: 'AE Engineers can only create JNR accounts.' });
    }

    if (actor.role === 'admin' && !['jnr', 'ae'].includes(role)) {
      return res.status(400).json({ success: false, message: 'Super Admin can create JNR or AE accounts here.' });
    }

    // Format email: if user passed username without @, append @annauniv.edu
    let formattedEmail = email.trim().toLowerCase();
    if (!formattedEmail.includes('@')) {
      formattedEmail = `${formattedEmail}@annauniv.edu`;
    }

    // Check uniqueness
    const existing = await db.query('SELECT id FROM users WHERE LOWER(email) = $1', [formattedEmail]);
    if (existing.rows.length > 0) {
      return res.status(400).json({ success: false, message: 'An account with this email/username already exists.' });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const result = await db.query(`
      INSERT INTO users (name, email, phone, department, password_hash, role, is_verified)
      VALUES ($1, $2, $3, $4, $5, $6, true)
      RETURNING id, name, email, phone, department, role, created_at;
    `, [name.trim(), formattedEmail, phone ? phone.trim() : null, department || 'Estate Office', passwordHash, role]);

    return res.status(201).json({
      success: true,
      message: `${role.toUpperCase()} Engineer account created successfully.`,
      user: result.rows[0],
    });
  } catch (err) {
    console.error('Create staff error:', err);
    return res.status(500).json({ success: false, message: 'Failed to create staff account: ' + err.message });
  }
}

/**
 * 3. List Staff Accounts
 */
async function listStaffAccounts(req, res) {
  try {
    const result = await db.query(`
      SELECT id, name, email, phone, department, role, is_verified, created_at
      FROM users
      WHERE role IN ('jnr', 'ae', 'admin')
      ORDER BY role ASC, name ASC;
    `);

    return res.status(200).json({
      success: true,
      staff: result.rows,
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Failed to list staff accounts.' });
  }
}

module.exports = {
  getAnalytics,
  createStaffAccount,
  listStaffAccounts,
};
