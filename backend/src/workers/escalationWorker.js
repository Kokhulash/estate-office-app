const cron = require('node-cron');
const db = require('../db');

/**
 * Checks for grievances that have been in 'Submitted' or 'In Progress' for > 48 hours
 * without being escalated, and automatically flags them as escalated.
 */
async function runAutoEscalationCheck() {
  try {
    console.log('[EscalationWorker] Checking for overdue grievances (>48 hours)...');

    // Find grievances older than 48 hours still Submitted or In Progress
    const findQuery = `
      SELECT id, status, created_at
      FROM grievances
      WHERE status IN ('Submitted', 'In Progress')
        AND created_at <= NOW() - INTERVAL '48 hours'
        AND escalated_at IS NULL;
    `;

    const overdueResult = await db.query(findQuery);
    const count = overdueResult.rows.length;

    if (count === 0) {
      console.log('[EscalationWorker] No overdue unescalated grievances found.');
      return 0;
    }

    console.log(`[EscalationWorker] Found ${count} overdue grievances. Escalating to AE queue...`);

    for (const ticket of overdueResult.rows) {
      // Mark as escalated
      await db.query(`
        UPDATE grievances
        SET 
          escalated_at = NOW(),
          escalated_by = 'SYSTEM_AUTO_48H',
          updated_at = NOW()
        WHERE id = $1;
      `, [ticket.id]);

      // Audit status log
      await db.query(`
        INSERT INTO grievance_status_log (grievance_id, actor_role, old_status, new_status, comment)
        VALUES ($1, 'system', $2, $2, 'Automatically escalated to AE/Admin queue: unresolved after 48 hours');
      `, [ticket.id, ticket.status]);
    }

    console.log(`[EscalationWorker] Successfully auto-escalated ${count} tickets.`);
    return count;
  } catch (err) {
    console.error('[EscalationWorker] Error during auto-escalation check:', err);
    return 0;
  }
}

function startEscalationCron() {
  // Run every 15 minutes: "*/15 * * * *"
  cron.schedule('*/15 * * * *', () => {
    runAutoEscalationCheck();
  });

  console.log('[EscalationWorker] Auto-escalation cron worker scheduled (every 15 minutes).');

  // Also run an initial check on startup
  runAutoEscalationCheck();
}

module.exports = {
  startEscalationCron,
  runAutoEscalationCheck,
};
