# Task Service

Task management service for the Task Management API. Handles CRUD operations for tasks with authentication validation.

## Endpoints

- `POST /tasks` - Create new task (requires JWT)
- `GET /tasks` - List all tasks for authenticated user (requires JWT)
- `GET /tasks/:id` - Get specific task (requires JWT)
- `PUT /tasks/:id` - Update task (requires JWT)
- `DELETE /tasks/:id` - Delete task (requires JWT)
- `GET /tasks/health` - Health check endpoint

## Environment Variables

See `.env.example` for required environment variables.

## Building Docker Image

```bash
docker build -t task-service:v1.0.0 .
```

## Running Locally

```bash
npm install
npm start
```

## Requirements Validated

- **6.2**: Token validation with Auth Service before processing
- **10.1**: Create new task with valid data
- **10.2**: Retrieve all tasks for authenticated user
- **10.3**: Update task if it belongs to authenticated user
- **10.4**: Delete task if it belongs to authenticated user
- **10.5**: Return 401 for requests without valid JWT token
