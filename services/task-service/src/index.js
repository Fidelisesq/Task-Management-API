const express = require('express');
const axios = require('axios');
const { Pool } = require('pg');

const app = express();
app.use(express.json());


// CORS middleware - Production configuration
app.use((req, res, next) => {
  const allowedOrigins = [
    'http://task-management-frontend-1767876018.s3-website-us-east-1.amazonaws.com',
    'https://task-management.fozdigitalz.com' // my frontend domain
  ];
  
  const origin = req.headers.origin;
  
  // Always set CORS headers for allowed origins
  if (allowedOrigins.includes(origin)) {
    res.header('Access-Control-Allow-Origin', origin);
    res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.header('Access-Control-Allow-Credentials', 'true');
  }
  
  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }
  
  next();
});

// Database connection pool
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
  ssl: {
    rejectUnauthorized: false // Required for RDS connections
  }
});

// Auth Service URL from environment
const AUTH_SERVICE_URL = process.env.AUTH_SERVICE_URL || 'http://auth-service.task-management.local:3000';

// Authentication middleware
async function authenticateToken(req, res, next) {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'No authentication token provided'
      });
    }

    // Validate token with Auth Service
    try {
      const response = await axios.post(
        `${AUTH_SERVICE_URL}/auth/validate`,
        {},
        {
          headers: {
            Authorization: authHeader
          },
          timeout: 5000
        }
      );

      if (response.data.valid) {
        req.user = response.data.user;
        next();
      } else {
        return res.status(401).json({
          error: 'Unauthorized',
          message: 'Invalid token'
        });
      }
    } catch (authError) {
      if (authError.response) {
        return res.status(authError.response.status).json(authError.response.data);
      }
      throw authError;
    }
  } catch (error) {
    console.error('Authentication error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Authentication service unavailable'
    });
  }
}

// Health check endpoint
app.get('/tasks/health', (req, res) => {
  res.status(200).json({ status: 'healthy', service: 'task-service' });
});

// Create new task
app.post('/tasks', authenticateToken, async (req, res) => {
  try {
    const { title, description, status, priority, due_date } = req.body;
    const user_id = req.user.user_id;

    // Validation
    if (!title) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Validation failed',
        details: [
          {
            field: 'title',
            message: 'Title is required'
          }
        ]
      });
    }

    // Insert task
    const result = await pool.query(
      `INSERT INTO tasks (user_id, title, description, status, priority, due_date) 
       VALUES ($1, $2, $3, $4, $5, $6) 
       RETURNING id, user_id, title, description, status, priority, due_date, created_at, updated_at`,
      [
        user_id,
        title,
        description || null,
        status || 'pending',
        priority || 'medium',
        due_date || null
      ]
    );

    res.status(201).json({
      message: 'Task created successfully',
      task: result.rows[0]
    });
  } catch (error) {
    console.error('Create task error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'An unexpected error occurred'
    });
  }
});

// Get all tasks for authenticated user
app.get('/tasks', authenticateToken, async (req, res) => {
  try {
    const user_id = req.user.user_id;

    const result = await pool.query(
      `SELECT id, user_id, title, description, status, priority, due_date, created_at, updated_at 
       FROM tasks 
       WHERE user_id = $1 
       ORDER BY created_at DESC`,
      [user_id]
    );

    res.status(200).json({
      tasks: result.rows,
      count: result.rows.length
    });
  } catch (error) {
    console.error('Get tasks error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'An unexpected error occurred'
    });
  }
});

// Get specific task by ID
app.get('/tasks/:id', authenticateToken, async (req, res) => {
  try {
    const task_id = req.params.id;
    const user_id = req.user.user_id;

    const result = await pool.query(
      `SELECT id, user_id, title, description, status, priority, due_date, created_at, updated_at 
       FROM tasks 
       WHERE id = $1`,
      [task_id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: 'Not Found',
        message: `Task with id ${task_id} not found`
      });
    }

    const task = result.rows[0];

    // Check if task belongs to authenticated user
    if (task.user_id !== user_id) {
      return res.status(403).json({
        error: 'Forbidden',
        message: 'You do not have permission to access this resource'
      });
    }

    res.status(200).json({
      task: task
    });
  } catch (error) {
    console.error('Get task error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'An unexpected error occurred'
    });
  }
});

// Update task
app.put('/tasks/:id', authenticateToken, async (req, res) => {
  try {
    const task_id = req.params.id;
    const user_id = req.user.user_id;
    const { title, description, status, priority, due_date } = req.body;

    // Check if task exists and belongs to user
    const existingTask = await pool.query(
      'SELECT user_id FROM tasks WHERE id = $1',
      [task_id]
    );

    if (existingTask.rows.length === 0) {
      return res.status(404).json({
        error: 'Not Found',
        message: `Task with id ${task_id} not found`
      });
    }

    if (existingTask.rows[0].user_id !== user_id) {
      return res.status(403).json({
        error: 'Forbidden',
        message: 'You do not have permission to access this resource'
      });
    }

    // Update task
    const result = await pool.query(
      `UPDATE tasks 
       SET title = COALESCE($1, title),
           description = COALESCE($2, description),
           status = COALESCE($3, status),
           priority = COALESCE($4, priority),
           due_date = COALESCE($5, due_date),
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $6
       RETURNING id, user_id, title, description, status, priority, due_date, created_at, updated_at`,
      [title, description, status, priority, due_date, task_id]
    );

    res.status(200).json({
      message: 'Task updated successfully',
      task: result.rows[0]
    });
  } catch (error) {
    console.error('Update task error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'An unexpected error occurred'
    });
  }
});

// Delete task
app.delete('/tasks/:id', authenticateToken, async (req, res) => {
  try {
    const task_id = req.params.id;
    const user_id = req.user.user_id;

    // Check if task exists and belongs to user
    const existingTask = await pool.query(
      'SELECT user_id FROM tasks WHERE id = $1',
      [task_id]
    );

    if (existingTask.rows.length === 0) {
      return res.status(404).json({
        error: 'Not Found',
        message: `Task with id ${task_id} not found`
      });
    }

    if (existingTask.rows[0].user_id !== user_id) {
      return res.status(403).json({
        error: 'Forbidden',
        message: 'You do not have permission to access this resource'
      });
    }

    // Delete task
    await pool.query('DELETE FROM tasks WHERE id = $1', [task_id]);

    res.status(200).json({
      message: 'Task deleted successfully'
    });
  } catch (error) {
    console.error('Delete task error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'An unexpected error occurred'
    });
  }
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Task Service listening on port ${PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  pool.end(() => {
    console.log('Database pool closed');
    process.exit(0);
  });
});
