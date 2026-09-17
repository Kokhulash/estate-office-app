const axios = require('axios');
const fs = require('fs');
const path = require('path');
const FormData = require('form-data');
const { runAutoEscalationCheck } = require('../src/workers/escalationWorker');
const db = require('../src/db');

const BASE_URL = 'http://localhost:5001/api';

// Create a small 1x1 test JPEG image buffer for upload tests
const testImageBuffer = Buffer.from([
  0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x01, 0x00, 0x48,
  0x00, 0x48, 0x00, 0x00, 0xff, 0xdb, 0x00, 0x43, 0x00, 0x03, 0x02, 0x02, 0x03, 0x02, 0x02, 0x03,
  0x03, 0x03, 0x03, 0x04, 0x03, 0x03, 0x04, 0x05, 0x08, 0x05, 0x05, 0x04, 0x04, 0x05, 0x0a, 0x07,
  0x07, 0x06, 0x08, 0x0c, 0x0a, 0x0c, 0x0c, 0x0b, 0x0a, 0x0b, 0x0b, 0x0d, 0x0e, 0x12, 0x10, 0x0d,
  0x0e, 0x11, 0x0e, 0x0b, 0x0b, 0x10, 0x16, 0x10, 0x11, 0x13, 0x14, 0x15, 0x15, 0x15, 0x0c, 0x0f,
  0x17, 0x18, 0x16, 0x14, 0x18, 0x12, 0x14, 0x15, 0x14, 0xff, 0xc0, 0x00, 0x0b, 0x08, 0x00, 0x01,
  0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xff, 0xc4, 0x00, 0x14, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x09, 0xff, 0xda, 0x00, 0x08,
  0x01, 0x01, 0x00, 0x00, 0x3f, 0x00, 0x7f, 0x00, 0xff, 0xd9
]);

async function runTests() {
  console.log('--- Starting College Grievance System API Automated Tests ---');

  // Start app on port 5001 for test
  const app = require('../src/app');
  const server = app.listen(5001);

  try {
    // 1. Health check & Public Buildings
    console.log('\n[1] Testing GET /api/buildings...');
    const buildingsRes = await axios.get(`${BASE_URL}/buildings`);
    console.log(`✓ Fetched ${buildingsRes.data.buildings.length} campus buildings.`);
    const firstBuilding = buildingsRes.data.buildings[0];

    // 2. Auth: Student Login
    console.log('\n[2] Testing Student Login (student@annauniv.edu)...');
    const studentLogin = await axios.post(`${BASE_URL}/auth/login`, {
      email: 'student@annauniv.edu',
      password: 'Student@123',
    });
    const studentToken = studentLogin.data.tokens.accessToken;
    console.log(`✓ Student logged in successfully. Role: ${studentLogin.data.user.role}`);

    // 3. Grievance Submission with Camera Photo & GPS metadata
    console.log('\n[3] Testing Grievance Submission (Camera Photo + GPS)...');
    const form = new FormData();
    form.append('image', testImageBuffer, { filename: 'report_capture.jpg', contentType: 'image/jpeg' });
    form.append('building_id', firstBuilding.id.toString());
    form.append('location_text', '2nd Floor Restroom');
    form.append('issue_type', 'Bathroom Related Issues');
    form.append('severity', 'High');
    form.append('description', 'Water leakage from the main pipe.');
    form.append('is_anonymous', 'false');
    form.append('image_gps_lat', '13.01023');
    form.append('image_gps_lng', '80.23557');
    form.append('image_captured_at', new Date().toISOString());

    const reportRes = await axios.post(`${BASE_URL}/grievances`, form, {
      headers: {
        ...form.getHeaders(),
        Authorization: `Bearer ${studentToken}`,
      },
    });
    const ticketId = reportRes.data.grievance.id;
    console.log(`✓ Grievance submitted successfully. Ticket ID: ${ticketId}`);

    // 4. Community Feed - Anonymity Verification
    console.log('\n[4] Testing Community Feed & Anonymity Rules...');
    const feedRes = await axios.get(`${BASE_URL}/grievances/feed`, {
      headers: { Authorization: `Bearer ${studentToken}` },
    });
    console.log(`✓ Feed loaded ${feedRes.data.feed.length} tickets.`);
    // Verify reporter name is not exposed in feed cards
    const feedTicket = feedRes.data.feed.find(t => t.id === ticketId);
    if (feedTicket.reporter_name) {
      throw new Error('FAILED: Feed exposed reporter name!');
    }
    console.log('✓ Verified: Reporter identity is strictly omitted from community feed card.');

    // 5. Upvote Toggle
    console.log('\n[5] Testing Upvote Toggle...');
    const upvote1 = await axios.post(`${BASE_URL}/grievances/${ticketId}/upvote`, {}, {
      headers: { Authorization: `Bearer ${studentToken}` },
    });
    console.log(`✓ Upvoted ticket. HasUpvoted: ${upvote1.data.has_upvoted}, Count: ${upvote1.data.upvote_count}`);

    const upvote2 = await axios.post(`${BASE_URL}/grievances/${ticketId}/upvote`, {}, {
      headers: { Authorization: `Bearer ${studentToken}` },
    });
    console.log(`✓ Toggled upvote again. HasUpvoted: ${upvote2.data.has_upvoted}, Count: ${upvote2.data.upvote_count}`);

    // 6. JNR Engineer Login & Triage
    console.log('\n[6] Testing JNR Engineer Login (username: jnr1)...');
    const jnrLogin = await axios.post(`${BASE_URL}/auth/login`, {
      username: 'jnr1',
      password: 'Jnr@123',
    });
    const jnrToken = jnrLogin.data.tokens.accessToken;
    console.log(`✓ JNR Engineer logged in. Role: ${jnrLogin.data.user.role}`);

    console.log('\n[7] JNR moves status to "In Progress"...');
    const statusProgress = await axios.patch(`${BASE_URL}/engineer/${ticketId}/status`, {
      status: 'In Progress',
      comment: 'Inspecting the leakage on site.',
    }, {
      headers: { Authorization: `Bearer ${jnrToken}` },
    });
    console.log(`✓ Status updated to: ${statusProgress.data.grievance.status}`);

    // 7. JNR Manual Escalation with Reason
    console.log('\n[8] JNR escalates ticket to AE with reason...');
    const escalateRes = await axios.post(`${BASE_URL}/engineer/${ticketId}/escalate`, {
      reason: 'Plumbing contractor required for major valve replacement.',
    }, {
      headers: { Authorization: `Bearer ${jnrToken}` },
    });
    console.log(`✓ Escalated: ${escalateRes.data.message}`);

    // 8. AE Engineer Login & Escalation Queue Verification
    console.log('\n[9] Testing AE Engineer Login (ae1)...');
    const aeLogin = await axios.post(`${BASE_URL}/auth/login`, {
      username: 'ae1',
      password: 'Ae@123',
    });
    const aeToken = aeLogin.data.tokens.accessToken;
    console.log(`✓ AE Engineer logged in. Role: ${aeLogin.data.user.role}`);

    const aeQueue = await axios.get(`${BASE_URL}/engineer/queue`, {
      headers: { Authorization: `Bearer ${aeToken}` },
    });
    const foundInAeQueue = aeQueue.data.queue.some(t => t.id === ticketId);
    if (!foundInAeQueue) {
      throw new Error('FAILED: Escalated ticket not found in AE queue!');
    }
    console.log('✓ Verified: Ticket is present in AE escalation queue.');

    // 9. Close Ticket as "Closed Successfully" (Requires Resolution Photo!)
    console.log('\n[10] AE closes ticket as "Closed Successfully" with resolution photo...');
    const closeForm = new FormData();
    closeForm.append('resolution_photo', testImageBuffer, { filename: 'resolution_photo.jpg', contentType: 'image/jpeg' });
    closeForm.append('status', 'Closed Successfully');
    closeForm.append('comment', 'Valve replaced and water pressure restored.');

    const closeRes = await axios.patch(`${BASE_URL}/engineer/${ticketId}/status`, closeForm, {
      headers: {
        ...closeForm.getHeaders(),
        Authorization: `Bearer ${aeToken}`,
      },
    });
    console.log(`✓ Ticket closed successfully! Status: ${closeRes.data.grievance.status}, Closing Photo: ${closeRes.data.grievance.closing_photo_url}`);

    // 10. Super Admin Login & Analytics
    console.log('\n[11] Testing Super Admin Login (admin@annauniv.edu)...');
    const adminLogin = await axios.post(`${BASE_URL}/auth/login`, {
      email: 'admin@annauniv.edu',
      password: 'Admin@123',
    });
    const adminToken = adminLogin.data.tokens.accessToken;
    console.log(`✓ Super Admin logged in. Role: ${adminLogin.data.user.role}`);

    console.log('\n[12] Super Admin fetching Analytics...');
    const analyticsRes = await axios.get(`${BASE_URL}/admin/analytics`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    const a = analyticsRes.data.analytics;
    console.log(`✓ Analytics summary: Total Issues: ${a.summary.total_issues}, Closed: ${a.summary.closed_count}, Escalation Rate: ${a.summary.escalation_rate_percent}%`);

    // 11. Create a new JNR account via Admin
    console.log('\n[13] Testing Admin creating new JNR engineer account...');
    const newJnr = await axios.post(`${BASE_URL}/admin/users`, {
      name: 'Ramesh JNR',
      email: `ramesh_jnr_${Date.now()}@annauniv.edu`,
      phone: '9876500000',
      department: 'Electrical Office',
      password: 'Password@123',
      role: 'jnr',
    }, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    console.log(`✓ Created staff account: ${newJnr.data.user.name} (${newJnr.data.user.role})`);

    // 12. Run 48h Escalation Worker Check
    console.log('\n[14] Testing Auto-Escalation Worker execution...');
    const workerEscalated = await runAutoEscalationCheck();
    console.log(`✓ Auto-escalation worker completed smoothly (Processed: ${workerEscalated} tickets).`);

    console.log('\n======================================================');
    console.log('🎉 ALL BACKEND API & INTEGRATION TESTS PASSED 100%! 🎉');
    console.log('======================================================\n');
  } catch (err) {
    console.error('❌ Test failed with error:', err.response?.data || err.message);
    process.exitCode = 1;
  } finally {
    server.close();
    await db.pool.end();
  }
}

runTests();
