-- College Grievance Redressal System Schema

-- Enable UUID extension if not enabled
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Users Table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50),
    department VARCHAR(100),
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('student', 'faculty', 'employee', 'jnr', 'ae', 'admin')),
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Buildings Table (Admin-managed, not hardcoded in the app)
CREATE TABLE IF NOT EXISTS buildings (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) UNIQUE NOT NULL
);

-- 3. Grievances Table
CREATE TABLE IF NOT EXISTS grievances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID REFERENCES users(id) ON DELETE SET NULL,
    is_anonymous BOOLEAN DEFAULT false,
    image_url TEXT NOT NULL,
    image_gps_lat DOUBLE PRECISION,
    image_gps_lng DOUBLE PRECISION,
    image_captured_at TIMESTAMPTZ,
    description TEXT,
    building_id INT REFERENCES buildings(id) ON DELETE RESTRICT,
    location_text VARCHAR(255),
    issue_type VARCHAR(50) NOT NULL CHECK (issue_type IN ('Civil', 'Electrical', 'Cleaning', 'Bathroom Related Issues', 'Others')),
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('Low', 'Medium', 'High')),
    status VARCHAR(30) NOT NULL DEFAULT 'Submitted' CHECK (status IN ('Submitted', 'In Progress', 'Closed Successfully', 'Invalid Report')),
    assigned_jnr_id UUID REFERENCES users(id) ON DELETE SET NULL,
    assigned_ae_id UUID REFERENCES users(id) ON DELETE SET NULL,
    escalated_at TIMESTAMPTZ,
    escalated_by VARCHAR(255),
    closing_photo_url TEXT,
    upvote_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Grievance Status Log (Audit trail for accountability)
CREATE TABLE IF NOT EXISTS grievance_status_log (
    id SERIAL PRIMARY KEY,
    grievance_id UUID NOT NULL REFERENCES grievances(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    actor_role VARCHAR(50),
    old_status VARCHAR(30),
    new_status VARCHAR(30),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Grievance Upvotes (One vote per user per grievance)
CREATE TABLE IF NOT EXISTS grievance_upvotes (
    id SERIAL PRIMARY KEY,
    grievance_id UUID NOT NULL REFERENCES grievances(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(grievance_id, user_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_grievances_status ON grievances(status);
CREATE INDEX IF NOT EXISTS idx_grievances_building_id ON grievances(building_id);
CREATE INDEX IF NOT EXISTS idx_grievances_reporter_id ON grievances(reporter_id);
CREATE INDEX IF NOT EXISTS idx_grievances_created_at ON grievances(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_grievances_escalated_at ON grievances(escalated_at);
CREATE INDEX IF NOT EXISTS idx_grievance_status_log_grievance_id ON grievance_status_log(grievance_id);
CREATE INDEX IF NOT EXISTS idx_grievance_upvotes_user_grievance ON grievance_upvotes(user_id, grievance_id);
