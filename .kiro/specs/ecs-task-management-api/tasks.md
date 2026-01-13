# Implementation Plan: ECS Task Management API

## Overview

This implementation plan provides a structured checklist for manually building the Task Management API on AWS ECS. The tasks are organized sequentially to build understanding of container orchestration, service discovery, load balancing, and AWS services integration. Each task includes verification steps to ensure correct configuration before proceeding.

**Note**: This is a learning project focused on manual AWS Console implementation. Tasks involve AWS Console configuration, Docker image building, and testing - not automated code generation.

## Tasks

- [x] 1. Foundation Setup - Configure VPC, Security Groups, and IAM Roles
  - Verify existing VPC structure in us-east-1 (public/private subnets, Internet Gateway, NAT Gateway)
  - Create 4 security groups: ALB, Auth Service, Task Service, and RDS with proper ingress/egress rules
  - Create IAM roles: ecsTaskExecutionRole (with Secrets Manager access) and ecsTaskRole (with CloudWatch Logs access)
  - Document all resource IDs (VPC, subnets, security groups, IAM role ARNs)
  - _Requirements: 1.1, 12.1, 12.2, 12.3, 12.4_

- [x] 2. Database Infrastructure - Set up RDS PostgreSQL and Secrets Management
  - Create RDS subnet group using private subnets
  - Create secrets in Secrets Manager: rds-credentials and jwt-secret
  - Create RDS PostgreSQL instance (db.t3.micro, 20GB, in private subnets)
  - Update secrets with RDS endpoint information
  - Initialize database schema (users and tasks tables with indexes)
  - _Requirements: 5.1, 5.2, 5.3, 7.1, 7.2, 7.5_

- [x] 3. Container Registry Setup - Create ECR repositories
  - Create ECR repository for auth-service with scan on push enabled
  - Create ECR repository for task-service with scan on push enabled
  - Configure lifecycle policies to retain last 10 images
  - Document repository URIs
  - _Requirements: 11.1, 11.2, 11.4_

- [x] 4. Build and Push Auth Service Container
  - Create Auth Service application code (Express.js with JWT, bcrypt, PostgreSQL)
  - Implement endpoints: /auth/register, /auth/login, /auth/validate, /auth/health
  - Create Dockerfile and .dockerignore
  - Build Docker image locally
  - Authenticate Docker to ECR
  - Tag and push image to ECR with version tag (v1.0.0)
  - Verify image appears in ECR with vulnerability scan results
  - _Requirements: 6.1, 6.3, 6.5, 11.3, 11.5_

- [x] 5. Build and Push Task Service Container
  - Create Task Service application code (Express.js with axios for auth validation, PostgreSQL)
  - Implement endpoints: POST/GET/PUT/DELETE /tasks, /tasks/health
  - Implement authentication middleware that calls Auth Service
  - Create Dockerfile and .dockerignore
  - Build, tag, and push image to ECR (v1.0.0)
  - Verify image in ECR
  - _Requirements: 6.2, 10.1, 10.2, 10.3, 10.4, 10.5_

- [x] 6. ECS Cluster and Service Discovery Setup
  - Create ECS cluster: task-management-cluster (Fargate, Container Insights enabled)
  - Create CloudWatch log groups: /ecs/auth-service and /ecs/task-service (30-day retention)
  - Create AWS Cloud Map namespace: task-management.local (private DNS in VPC)
  - Verify cluster is active and log groups are created
  - _Requirements: 1.2, 1.5, 2.1, 2.3, 9.1, 9.2_

- [x] 7. Deploy Auth Service to ECS
  - Create Auth Service task definition with Fargate launch type (0.25 vCPU, 0.5 GB memory)
  - Configure container with ECR image URI, port 3000, environment variables from Secrets Manager
  - Configure CloudWatch logging to /ecs/auth-service
  - Create ECS service with 2 desired tasks in private subnets
  - Enable service discovery registration (auth-service.task-management.local)
  - Verify 2 tasks are running and registered in Cloud Map
  - _Requirements: 1.3, 1.4, 2.2, 2.5, 7.2, 9.5_

- [ ] 8. Deploy Task Service to ECS
  - Create Task Service task definition (0.25 vCPU, 0.5 GB memory)
  - Configure container with ECR image, port 3000, environment variables including AUTH_SERVICE_URL
  - Configure CloudWatch logging to /ecs/task-service
  - Create ECS service with 2 desired tasks in private subnets
  - Verify 2 tasks are running and can resolve auth-service.task-management.local
  - _Requirements: 1.3, 2.2, 2.4, 5.4_

- [ ] 9. Checkpoint - Verify Services are Running
  - Confirm 4 total tasks running (2 auth + 2 task)
  - Check CloudWatch logs show both services started successfully
  - Verify service discovery shows auth-service with 2 registered instances
  - Check security groups allow proper inter-service communication

- [ ] 10. Application Load Balancer Configuration
  - Create 2 target groups: auth-service-tg and task-service-tg (IP type, HTTP:3000)
  - Configure health checks: /auth/health and /tasks/health (30s interval, 5s timeout)
  - Create internet-facing ALB in public subnets with ALB security group
  - Configure HTTP:80 listener with default action
  - Add routing rules: /auth/* → auth-service-tg, /tasks/* → task-service-tg
  - Update ECS services to register with target groups
  - Verify targets are healthy in both target groups
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [ ] 11. Auto Scaling Configuration
  - Configure target tracking scaling policy for auth-service (CPU 70%, min 2, max 10)
  - Configure target tracking scaling policy for task-service (CPU 70%, min 2, max 10)
  - Set scale-out cooldown to 60s and scale-in cooldown to 300s
  - Verify scaling policies are active
  - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [ ] 12. Monitoring and Alarms Setup
  - Create CloudWatch alarm for high error rate (5XX > 10 in 5 minutes)
  - Create CloudWatch alarms for high CPU (>80% for 3 periods) for both services
  - Create CloudWatch dashboard with widgets: request count, response time, CPU, memory, RDS connections, running tasks
  - Configure alarm actions (SNS topic optional)
  - _Requirements: 4.5, 9.3, 9.4_

- [ ] 13. End-to-End Testing - Authentication Flow
  - Test user registration via ALB: POST /auth/register
  - Test user login via ALB: POST /auth/login
  - Verify JWT token is returned with correct claims and expiration
  - Test token validation: POST /auth/validate
  - Test health check endpoints
  - Verify all requests are logged in CloudWatch
  - _Requirements: 6.1, 6.4, 6.5, 9.1_

- [ ] 14. End-to-End Testing - Task Management Flow
  - Test task creation with valid JWT: POST /tasks
  - Test retrieving all tasks: GET /tasks
  - Test retrieving specific task: GET /tasks/:id
  - Test updating task: PUT /tasks/:id
  - Test deleting task: DELETE /tasks/:id
  - Verify user can only access their own tasks
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 5.5_

- [ ] 15. End-to-End Testing - Error Scenarios
  - Test requests without JWT token (expect 401)
  - Test requests with invalid/expired token (expect 401)
  - Test accessing another user's task (expect 403)
  - Test accessing non-existent task (expect 404)
  - Verify error responses match design specification
  - _Requirements: 6.2, 6.4, 10.5_

- [ ] 16. End-to-End Testing - Service Discovery
  - Verify Task Service can resolve auth-service.task-management.local
  - Check CloudWatch logs for successful inter-service communication
  - Test token validation flow between services
  - Verify service discovery updates when tasks are added/removed
  - _Requirements: 2.2, 2.5_

- [ ] 17. Load Testing and Auto Scaling Verification
  - Use Apache Bench or similar tool to generate load on ALB
  - Monitor CPU utilization in CloudWatch
  - Verify auto scaling triggers when CPU > 70%
  - Verify tasks scale up (2 → 3+)
  - Stop load and verify scale-in after cooldown period
  - Check CloudWatch alarms trigger appropriately
  - _Requirements: 4.2, 4.3, 4.5_

- [ ] 18. Security Verification
  - Verify passwords are hashed with bcrypt in database (never plaintext)
  - Verify secrets are loaded from Secrets Manager (not hardcoded)
  - Verify RDS is in private subnets with no public access
  - Verify security groups only allow necessary traffic
  - Verify JWT tokens expire after 3600 seconds
  - _Requirements: 6.3, 7.1, 7.3, 7.5, 12.1, 12.2, 12.3, 12.4_

- [ ] 19. Final Checkpoint - Complete System Validation
  - Verify all 4 services are running and healthy
  - Verify ALB is routing traffic correctly
  - Verify auto scaling is configured and working
  - Verify monitoring dashboard shows all metrics
  - Verify all CloudWatch logs are being collected
  - Document ALB DNS name and test all endpoints
  - Review cost estimation and resource usage

- [ ] 20. Documentation and Learning Review
  - Document all resource IDs, ARNs, and endpoints
  - Review what was learned about ECS, service discovery, load balancing
  - Review auto scaling behavior and CloudWatch monitoring
  - Document any issues encountered and solutions
  - (Optional) Plan cleanup steps to avoid ongoing charges

## Notes

- This is a manual implementation project for learning AWS ECS
- Each task should be completed through the AWS Console (not automated)
- Verification steps are critical - don't skip them
- Tasks build on each other - complete them in order
- Estimated total time: 4-6 hours
- Refer to `implementation-guide.md` for detailed step-by-step instructions
- Take notes on what you learn at each step
- Use CloudWatch logs extensively for troubleshooting
