const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
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

// JWT configuration
const JWT_SECRET = process.env.JWT_SECRET;
const JWT_EXPIRATION = parseInt(process.env.JWT_EXPIRATION || '3600');

// Health check endpoint
app.get('/auth/health', (req, res) => {
  res.status(200).json({ status: 'healthy', service: 'auth-service' });
});

// Register endpoint
app.post('/auth/register', async (req, res) => {
  try {
    const { username, email, password } = req.body;

    // Validation
    if (!username || !email || !password) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Username, email, and password are required'
      });
    }

    // Check if user already exists
    const existingUser = await pool.query(
      'SELECT id FROM users WHERE username = $1 OR email = $2',
      [username, email]
    );

    if (existingUser.rows.length > 0) {
      return res.status(409).json({
        error: 'Conflict',
        message: 'Username or email already exists'
      });
    }

    // Hash password with bcrypt
    const password_hash = await bcrypt.hash(password, 10);

    // Insert user
    const result = await pool.query(
      'INSERT INTO users (username, email, password_hash) VALUES ($1, $2, $3) RETURNING id, username, email, created_at',
      [username, email, password_hash]
    );

    res.status(201).json({
      message: 'User registered successfully',
      user: result.rows[0]
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'An unexpected error occurred'
    });
  }
});

// Login endpoint
app.post('/auth/login', async (req, res) => {
  try {
    const { username, password } = req.body;

    // Validation
    if (!username || !password) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Username and password are required'
      });
    }

    // Get user from database
    const result = await pool.query(
      'SELECT id, username, email, password_hash FROM users WHERE username = $1',
      [username]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid username or password'
      });
    }

    const user = result.rows[0];

    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password_hash);

    if (!isValidPassword) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid username or password'
      });
    }

    // Generate JWT token
    const token = jwt.sign(
      {
        user_id: user.id,
        username: user.username,
        email: user.email
      },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRATION }
    );

    res.status(200).json({
      message: 'Login successful',
      token: token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'An unexpected error occurred'
    });
  }
});

// Validate token endpoint (for internal use by Task Service)
app.post('/auth/validate', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'No authentication token provided'
      });
    }

    const token = authHeader.substring(7);

    try {
      const decoded = jwt.verify(token, JWT_SECRET);
      res.status(200).json({
        valid: true,
        user: {
          user_id: decoded.user_id,
          username: decoded.username,
          email: decoded.email
        }
      });
    } catch (jwtError) {
      if (jwtError.name === 'TokenExpiredError') {
        return res.status(401).json({
          error: 'Unauthorized',
          message: 'Token has expired'
        });
      }
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid token'
      });
    }
  } catch (error) {
    console.error('Validation error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'An unexpected error occurred'
    });
  }
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Auth Service listening on port ${PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  pool.end(() => {
    console.log('Database pool closed');
    process.exit(0);
  });
});
