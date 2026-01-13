-- Test Data for Task Management API
-- Use this to verify database connectivity and schema

-- ============================================
-- Insert Test User
-- ============================================

INSERT INTO users (username, email, password_hash) 
VALUES ('testuser', 'test@example.com', '$2b$10$test.hash.placeholder.for.testing');

-- Verify user insertion
SELECT * FROM users;

-- ============================================
-- Insert Test Tasks
-- ============================================

INSERT INTO tasks (user_id, title, description, status, priority, due_date) 
VALUES 
    (1, 'Complete database setup', 'Set up RDS PostgreSQL and initialize schema', 'completed', 'high', NOW() + INTERVAL '1 day'),
    (1, 'Build Docker images', 'Create Dockerfiles for auth and task services', 'in_progress', 'high', NOW() + INTERVAL '2 days'),
    (1, 'Deploy to ECS', 'Deploy services to ECS Fargate', 'pending', 'medium', NOW() + INTERVAL '7 days');

-- Verify task insertion
SELECT * FROM tasks;

-- ============================================
-- Test Queries
-- ============================================

-- Get all tasks for a user
SELECT 
    t.id,
    t.title,
    t.status,
    t.priority,
    t.due_date,
    u.username
FROM tasks t
JOIN users u ON t.user_id = u.id
WHERE u.id = 1
ORDER BY t.due_date;

-- Count tasks by status
SELECT 
    status,
    COUNT(*) as count
FROM tasks
GROUP BY status;

-- Get overdue tasks
SELECT 
    id,
    title,
    due_date,
    status
FROM tasks
WHERE due_date < NOW() 
  AND status != 'completed'
ORDER BY due_date;

-- ============================================
-- Cleanup Test Data
-- ============================================

-- Uncomment these lines to remove test data:
-- DELETE FROM tasks WHERE user_id = 1;
-- DELETE FROM users WHERE id = 1;

-- Verify cleanup
-- SELECT COUNT(*) as user_count FROM users;
-- SELECT COUNT(*) as task_count FROM tasks;
