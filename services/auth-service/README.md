# Auth Service

Authentication service for the Task Management API. Handles user registration, login, and JWT token validation.

## Endpoints

- `POST /auth/register` - Register a new user
- `POST /auth/login` - Login and receive JWT token
- `POST /auth/validate` - Validate JWT token (internal use)
- `GET /auth/health` - Health check endpoint

## Environment Variables

See `.env.example` for required environment variables.

## Building Docker Image

```bash
docker build -t auth-service:v1.0.0 .
```

## Running Locally

```bash
npm install
npm start
```

## Requirements Validated

- **6.1**: JWT token generation with 1-hour expiration
- **6.3**: Password hashing with bcrypt
- **6.5**: JWT token includes user_id, username, and email claims
