const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const dbUrl = process.env.DATABASE_URL;
if (!dbUrl) {
  console.error('DATABASE_URL is not defined in .env');
  process.exit(1);
}

const pool = new Pool({
  connectionString: dbUrl,
  ssl: { rejectUnauthorized: false }
});

async function setupDatabase() {
  const client = await pool.connect();
  try {
    console.log('Connected to PostgreSQL database...');

    // 1. Run Schema SQL
    const schemaSql = fs.readFileSync(path.join(__dirname, '../src/db/schema.sql'), 'utf-8');
    await client.query(schemaSql);
    console.log('Database tables, constraints, and indexes created successfully.');

    // 2. Seed Initial Buildings
    const buildings = [
      { name: 'Main Administrative Block', code: 'ADMIN' },
      { name: 'Science & Humanities Block', code: 'SH-01' },
      { name: 'Computer Science & Engineering', code: 'CSE-01' },
      { name: 'Mechanical Engineering Block', code: 'MECH-01' },
      { name: 'ECE & EEE Department', code: 'ECE-01' },
      { name: 'Civil Engineering Block', code: 'CIVIL-01' },
      { name: 'Central University Library', code: 'LIB-01' },
      { name: 'Student Hostel Block A', code: 'HOSTEL-A' },
      { name: 'Student Hostel Block B', code: 'HOSTEL-B' },
      { name: 'University Health Centre', code: 'HEALTH-01' },
      { name: 'Campus Cafeteria & Food Court', code: 'CAFE-01' },
    ];

    for (const b of buildings) {
      await client.query(`
        INSERT INTO buildings (name, code)
        VALUES ($1, $2)
        ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name
      `, [b.name, b.code]);
    }
    console.log(`Seeded ${buildings.length} campus buildings.`);

    // 3. Seed Default Super Admin, JNR Engineer, and AE Engineer
    const adminPasswordHash = await bcrypt.hash('Admin@123', 10);
    const jnrPasswordHash = await bcrypt.hash('Jnr@123', 10);
    const aePasswordHash = await bcrypt.hash('Ae@123', 10);
    const studentPasswordHash = await bcrypt.hash('Student@123', 10);

    // Admin
    await client.query(`
      INSERT INTO users (name, email, phone, department, password_hash, role, is_verified)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      ON CONFLICT (email) DO UPDATE SET
        password_hash = EXCLUDED.password_hash,
        role = EXCLUDED.role,
        is_verified = true
    `, ['Super Admin', 'admin@annauniv.edu', '9876543210', 'Administration', adminPasswordHash, 'admin', true]);

    // JNR Engineer (username login supported via username or email; here jnr1@annauniv.edu)
    await client.query(`
      INSERT INTO users (name, email, phone, department, password_hash, role, is_verified)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      ON CONFLICT (email) DO UPDATE SET
        password_hash = EXCLUDED.password_hash,
        role = EXCLUDED.role,
        is_verified = true
    `, ['JNR Engineer Kumar', 'jnr1@annauniv.edu', '9876543211', 'Estate Office', jnrPasswordHash, 'jnr', true]);

    // AE Engineer
    await client.query(`
      INSERT INTO users (name, email, phone, department, password_hash, role, is_verified)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      ON CONFLICT (email) DO UPDATE SET
        password_hash = EXCLUDED.password_hash,
        role = EXCLUDED.role,
        is_verified = true
    `, ['AE Engineer Sharma', 'ae1@annauniv.edu', '9876543212', 'Estate Office', aePasswordHash, 'ae', true]);

    // Demo Student (Naive User)
    await client.query(`
      INSERT INTO users (name, email, phone, department, password_hash, role, is_verified)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      ON CONFLICT (email) DO UPDATE SET
        password_hash = EXCLUDED.password_hash,
        role = EXCLUDED.role,
        is_verified = true
    `, ['Arun Student', 'student@annauniv.edu', '9876543213', 'Computer Science', studentPasswordHash, 'student', true]);

    console.log('Seeded default user accounts:');
    console.log(' - Super Admin: admin@annauniv.edu / Admin@123');
    console.log(' - JNR Engineer: jnr1@annauniv.edu (or jnr1) / Jnr@123');
    console.log(' - AE Engineer: ae1@annauniv.edu (or ae1) / Ae@123');
    console.log(' - Demo Student: student@annauniv.edu / Student@123');

    console.log('Database setup completed successfully.');
  } catch (err) {
    console.error('Error during database setup:', err);
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

setupDatabase().catch(err => {
  console.error('Migration failed:', err);
  process.exit(1);
});
