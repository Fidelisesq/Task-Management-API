-- Task Management API Database Schema
-- PostgreSQL 15.x

-- ============================================
-- Users Table
-- ============================================

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for users table
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);

COMMENT ON TABLE users IS 'Stores user account information';
COMMENT ON COLUMN users.id IS 'Unique user identifier';
COMMENT ON COLUMN users.username IS 'Unique username for login';
COMMENT ON COLUMN users.email IS 'Unique email address';
COMMENT ON COLUMN users.password_hash IS 'Bcrypt hashed password';

-- ============================================
-- Tasks Table
-- ============================================

CREATE TABLE tasks (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    priority VARCHAR(20) DEFAULT 'medium',
    due_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT chk_status CHECK (status IN ('pending', 'in_progress', 'completed')),
    CONSTRAINT chk_priority CHECK (priority IN ('low', 'medium', 'high'))
);

-- Create indexes for tasks table
CREATE INDEX idx_tasks_user_id ON tasks(user_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_due_date ON tasks(due_date);

COMMENT ON TABLE tasks IS 'Stores task information for users';
COMMENT ON COLUMN tasks.id IS 'Unique task identifier';
COMMENT ON COLUMN tasks.user_id IS 'Foreign key to users table';
COMMENT ON COLUMN tasks.title IS 'Task title';
COMMENT ON COLUMN tasks.description IS 'Detailed task description';
COMMENT ON COLUMN tasks.status IS 'Task status: pending, in_progress, or completed';
COMMENT ON COLUMN tasks.priority IS 'Task priority: low, medium, or high';
COMMENT ON COLUMN tasks.due_date IS 'Optional due date for the task';

-- ============================================
-- Verification Queries
-- ============================================

-- List all tables
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public'
ORDER BY table_name;

-- List all indexes
SELECT 
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- Show table structures
\d users
\d tasks
