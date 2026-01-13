# Task 8: Deploy Task Service to ECS - Step-by-Step Guide

This guide walks you through deploying the Task Service to ECS with service discovery.

## Prerequisites

Before starting, ensure you have:
- ✅ Task 7 completed (Auth Service deployed and running)
- ✅ Task Service container image pushed to ECR (v1.0.0)
- ✅ All 5 VPC Endpoints created and available
- ✅ **CRITICAL:** Task service security group has HTTPS (443) rule from itself for VPC Endpoints access
  ```bash
  aws ec2 authorize-security-group-ingress \
    --region us-east-1 \
    --group-id <TASK_SG_ID> \
    --protocol tcp \
    --port 443 \
    --source-group <TASK_SG_ID>
  ```
- ✅ Security group rules configured
- ✅ IAM policies attached to ecsTaskExecutionRole

## Overview

Task Service will:
- Run in the same ECS cluster as Auth Service
- Use Service Discovery to find and call Auth Service
- Validate JWT tokens by calling `auth-service.task-management.local:3000/auth/validate`
- Provide CRUD operations for tasks
- Connect to the same RDS database

---

## Step 1: Create Task Definition

### 1.1 Navigate to ECS Task Definitions

1. Open AWS Console
2. Go to **ECS** service
3. Click **Task Definitions** in the left sidebar
4. Click **Create new task definition** button
5. Click **Create new task definition** (with JSON)

### 1.2 Configure Task Definition JSON

Copy and paste this JSON (replace the placeholder values with your actual values):

```json
{
  "family": "task-service",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::211125602758:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::211125602758:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "task-service",
      "image": "211125602758.dkr.ecr.us-east-1.amazonaws.com/task-service:v1.0.0",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp",
          "name": "task-service-3000-tcp",
          "appProtocol": "http"
        }
      ],
      "environment": [
        {
          "name": "NODE_ENV",
          "value": "production"
        },
        {
          "name": "PORT",
          "value": "3000"
        },
        {
          "name": "AUTH_SERVICE_URL",
          "value": "http://auth-service.task-management.local:3000"
        }
      ],
      "secrets": [
        {
          "name": "DB_HOST",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:211125602758:secret:rds-credentials-aAhHLW:host::"
        },
        {
          "name": "DB_PORT",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:211125602758:secret:rds-credentials-aAhHLW:port::"
        },
        {
          "name": "DB_NAME",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:211125602758:secret:rds-credentials-aAhHLW:dbname::"
        },
        {
          "name": "DB_USER",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:211125602758:secret:rds-credentials-aAhHLW:username::"
        },
        {
          "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:211125602758:secret:rds-credentials-aAhHLW:password::"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/task-service",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:3000/tasks/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

**Important Notes:**
- **AUTH_SERVICE_URL**: Uses Service Discovery DNS name `auth-service.task-management.local`
- **Secrets**: Same RDS credentials as auth-service (both services share the database)
- **No JWT_SECRET**: Task service doesn't generate tokens, only validates them via auth-service
- **Health check**: Uses `/tasks/health` endpoint

### 1.3 Create Task Definition

1. Paste the JSON into the editor
2. Click **Create**
3. Verify task definition **task-service:1** is created

---

## Step 2: Create ECS Service

### 2.1 Navigate to Create Service

1. Go to **ECS** → **Clusters**
2. Click **task-management-cluster**
3. Click **Services** tab
4. Click **Create** button

### 2.2 Environment Configuration

**Compute configuration:**
- **Compute options:** Launch type
- **Launch type:** FARGATE
- **Platform version:** LATEST

**Application type:**
- **Service** (default)

### 2.3 Deployment Configuration

**Task definition:**
- **Family:** task-service
- **Revision:** 1 (latest)

**Service name:**
- **Service name:** `task-service`

**Desired tasks:**
- **Desired tasks:** `2`

### 2.4 Networking Configuration

**VPC:**
- **VPC:** `vpc-0792f2f110cb731ed`

**Subnets:**
- ✅ Select **BOTH private subnets**:
  - `subnet-01578e4938893297d` (us-east-1a)
  - `subnet-0bbad45200c46c4e5` (us-east-1b)
- ❌ Do NOT select public subnets

**Security group:**
- **Use an existing security group**
- Select: **task-mgmt-task-sg** (the one you created for task service)
- Remove the default security group if it's selected

**Public IP:**
- **Turn OFF** public IP (tasks are in private subnets)

### 2.5 Load Balancing (Skip for Now)

- **Load balancer type:** None
- (You'll configure ALB in Task 10)

### 2.6 Service Discovery

**Use service discovery:**
- ✅ **Turn ON** service discovery

**Namespace:**
- Select: **task-management.local** (existing namespace)

**Service discovery service:**
- **Configure service discovery service:** Create new service discovery service

**Service discovery name:**
- **Service discovery name:** `task-service`
- This will create DNS: `task-service.task-management.local`

**DNS record type:**
- **DNS record type:** A (default)

**TTL:**
- **TTL:** 60 seconds (default)

### 2.7 Deployment Options

**Deployment type:**
- **Rolling update** (default)

**Min running tasks:**
- **Minimum:** 100%

**Max running tasks:**
- **Maximum:** 200%

**Deployment circuit breaker:**
- ✅ **Turn ON** deployment circuit breaker
- ✅ **Rollback on failure**

### 2.8 Review and Create

1. Scroll down and click **Create**
2. You'll see "Service task-service created successfully"
3. Click **View service**

---

## Step 3: Monitor Deployment

### 3.1 Watch Service Status

1. On the service details page, click **Tasks** tab
2. You should see 2 tasks being created
3. Watch the **Last status** column:
   - `PROVISIONING` → Creating network interfaces
   - `PENDING` → Pulling container image
   - `RUNNING` → Container started successfully

**Expected timeline:**
- 0-30 seconds: PROVISIONING
- 30-90 seconds: PENDING (pulling image, retrieving secrets)
- 90+ seconds: RUNNING

### 3.2 Check for Errors

If tasks fail to start:

1. Click on a task ID
2. Check **Stopped reason** field
3. Common issues:
   - **Cannot pull secrets**: VPC Endpoints issue (should be fixed from Task 7)
   - **Cannot pull image**: ECR endpoint issue (should be fixed from Task 7)
   - **Logger args error**: CloudWatch Logs endpoint issue (should be fixed from Task 7)
   - **Health check failed**: Application error (check CloudWatch Logs)

### 3.3 View CloudWatch Logs

1. Go to **CloudWatch** → **Log groups**
2. Click `/ecs/task-service`
3. Click on the latest log stream
4. You should see:
   ```
   Task Service listening on port 3000
   Database connected successfully
   ```

---

## Step 4: Verify Service Discovery

### 4.1 Check Service Discovery Registration

From your local machine:

```bash
# Get the Cloud Map namespace ID
NAMESPACE_ID=$(aws servicediscovery list-namespaces \
  --region us-east-1 \
  --query 'Namespaces[?Name==`task-management.local`].Id' \
  --output text)

echo "Namespace ID: $NAMESPACE_ID"

# List services in the namespace
aws servicediscovery list-services \
  --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID \
  --region us-east-1

# You should see both auth-service and task-service
```

### 4.2 Get Task Private IPs

```bash
# List task-service tasks
aws ecs list-tasks \
  --cluster task-management-cluster \
  --service-name task-service \
  --region us-east-1

# Get task details (replace TASK_ARN)
aws ecs describe-tasks \
  --cluster task-management-cluster \
  --tasks <TASK_ARN> \
  --region us-east-1 \
  --query 'tasks[0].containers[0].networkInterfaces[0].privateIpv4Address' \
  --output text
```

---

## Step 5: Test Task Service

### 5.1 Test from EC2 Instance (Using Private IP)

From your EC2 instance in the VPC:

```bash
# Get the private IP from Step 4.2, then test health endpoint
curl http://<TASK_PRIVATE_IP>:3000/tasks/health

# Expected response:
# {"status":"healthy","service":"task-service","timestamp":"..."}
```

### 5.2 Test Authentication Integration

The task service validates tokens by calling auth-service. Let's test the full flow:

**Step 1: Register a user (via auth-service)**
```bash
# Get auth-service private IP first
AUTH_IP=<AUTH_SERVICE_PRIVATE_IP>

curl -X POST http://$AUTH_IP:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "Test123!@#"
  }'

# Expected response:
# {"message":"User registered successfully","userId":1}
```

**Step 2: Login to get JWT token**
```bash
curl -X POST http://$AUTH_IP:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!@#"
  }'

# Expected response:
# {"token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."}

# Save the token
TOKEN="<paste_token_here>"
```

**Step 3: Create a task (via task-service)**
```bash
# Get task-service private IP
TASK_IP=<TASK_SERVICE_PRIVATE_IP>

curl -X POST http://$TASK_IP:3000/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "title": "Test Task",
    "description": "Testing task service",
    "status": "pending"
  }'

# Expected response:
# {"id":1,"title":"Test Task","description":"Testing task service","status":"pending","userId":1,"createdAt":"...","updatedAt":"..."}
```

**Step 4: Get all tasks**
```bash
curl http://$TASK_IP:3000/tasks \
  -H "Authorization: Bearer $TOKEN"

# Expected response:
# [{"id":1,"title":"Test Task",...}]
```

**Step 5: Test without token (should fail)**
```bash
curl http://$TASK_IP:3000/tasks

# Expected response:
# {"error":"No token provided"}
```

---

## Step 6: Verify Service-to-Service Communication

The task-service calls auth-service internally to validate tokens. Check the logs:

```bash
# View task-service logs
aws logs tail /ecs/task-service --follow --region us-east-1
```

When you make a request with a token, you should see logs showing:
- Received request with token
- Calling auth-service for validation
- Token validated successfully
- Processing request

---

## Step 7: Verify Both Services Running

### 7.1 Check Service Status

```bash
# Check both services
aws ecs describe-services \
  --cluster task-management-cluster \
  --services auth-service task-service \
  --region us-east-1 \
  --query 'services[*].[serviceName,status,runningCount,desiredCount]' \
  --output table
```

Expected output:
```
---------------------------------
|      DescribeServices         |
+---------------+--------+---+---+
| auth-service  | ACTIVE | 2 | 2 |
| task-service  | ACTIVE | 2 | 2 |
+---------------+--------+---+---+
```

### 7.2 Check All Tasks

```bash
# List all running tasks
aws ecs list-tasks \
  --cluster task-management-cluster \
  --desired-status RUNNING \
  --region us-east-1
```

You should see 4 task ARNs (2 auth-service + 2 task-service).

---

## Troubleshooting

### Issue 1: Tasks Fail to Start

**Check CloudWatch Logs:**
```bash
aws logs tail /ecs/task-service --region us-east-1
```

**Common errors:**
- **Cannot pull secrets/Cannot send logs**: Missing HTTPS (443) security group rule
  ```bash
  # Add the rule for task-service security group
  aws ec2 authorize-security-group-ingress \
    --region us-east-1 \
    --group-id <TASK_SG_ID> \
    --protocol tcp \
    --port 443 \
    --source-group <TASK_SG_ID>
  
  # Then force new deployment
  aws ecs update-service \
    --cluster task-management-cluster \
    --service task-service \
    --force-new-deployment \
    --region us-east-1
  ```
- **Cannot connect to database**: Check security group rules (task-mgmt-task-sg → task-mgmt-rds-sg on port 5432)
- **Cannot reach auth-service**: Service Discovery issue or security group rules

### Issue 2: Cannot Connect to Auth Service

**Error in logs:** `ENOTFOUND auth-service.task-management.local`

**Solution:**
1. Verify VPC DNS is enabled:
   ```bash
   aws ec2 describe-vpc-attribute \
     --vpc-id vpc-0792f2f110cb731ed \
     --attribute enableDnsSupport \
     --region us-east-1
   ```

2. Verify service discovery is configured on auth-service

3. Wait 1-2 minutes for DNS propagation

### Issue 3: Authentication Fails

**Error:** `Invalid token` or `Token validation failed`

**Check:**
1. Auth service is running and healthy
2. Security group allows task-service → auth-service on port 3000
3. Token is valid (not expired)
4. AUTH_SERVICE_URL is correct in task definition

**Verify security group rule:**
```bash
# Check task-mgmt-auth-sg allows inbound from task-mgmt-task-sg
aws ec2 describe-security-groups \
  --group-ids sg-0f19eb8f889b954d1 \
  --region us-east-1 \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`3000`]'
```

### Issue 4: Database Connection Fails

**Error in logs:** `Connection refused` or `ETIMEDOUT`

**Solution:**
Add security group rule:
```bash
# Allow task-service to connect to RDS
aws ec2 authorize-security-group-ingress \
  --group-id <RDS_SG_ID> \
  --protocol tcp \
  --port 5432 \
  --source-group <TASK_SERVICE_SG_ID> \
  --region us-east-1
```

---

## Security Group Rules Checklist

Verify these rules are in place:

**task-mgmt-task-sg (Task Service):**
- ✅ Inbound: Port 3000 from ALB SG (for future ALB)
- ✅ Inbound: Port 443 from itself (for VPC Endpoints access) **CRITICAL!**
- ✅ Outbound: Port 3000 to auth-service SG (to call auth-service)
- ✅ Outbound: Port 5432 to RDS SG (to access database)
- ✅ Outbound: Port 443 to 0.0.0.0/0 (for AWS services)

**task-mgmt-auth-sg (Auth Service):**
- ✅ Inbound: Port 3000 from task-service SG (to receive validation requests)
- ✅ Inbound: Port 443 from itself (for VPC Endpoints access) **CRITICAL!**

**task-mgmt-rds-sg (RDS):**
- ✅ Inbound: Port 5432 from auth-service SG
- ✅ Inbound: Port 5432 from task-service SG

---

## Verification Checklist

Before moving to Task 9, verify:

- [ ] Task definition created: task-service:1
- [ ] ECS service created: task-service
- [ ] 2 tasks running in RUNNING state
- [ ] Service discovery configured: task-service.task-management.local
- [ ] CloudWatch logs showing successful startup
- [ ] Health endpoint responds: `/tasks/health`
- [ ] Can register user via auth-service
- [ ] Can login and get JWT token
- [ ] Can create task with valid token
- [ ] Cannot create task without token
- [ ] Task-service successfully validates tokens via auth-service
- [ ] Both services (auth + task) running with 2 tasks each (4 total)

---

## What You've Accomplished

✅ **Deployed Task Service to ECS Fargate**
- Running 2 instances across 2 availability zones
- High availability and fault tolerance

✅ **Configured Service Discovery**
- Task service can find auth service via DNS
- Service-to-service communication working

✅ **Implemented Authentication Flow**
- Task service validates JWT tokens via auth service
- Secure API endpoints

✅ **Database Integration**
- Both services connected to RDS PostgreSQL
- Shared database for users and tasks

✅ **Microservices Architecture**
- Two independent services
- Loosely coupled via HTTP/REST
- Each service can scale independently

---

## Next Steps

You've completed Task 8! Next up:

**Task 9: Checkpoint - Verify Services Running**
- Comprehensive testing of both services
- Verify all endpoints working
- Check logs and metrics

**Task 10: Application Load Balancer Configuration**
- Create ALB to expose services to the internet
- Configure target groups and health checks
- Set up routing rules

---

## Cost Update

With both services running:

| Service | Count | Monthly Cost |
|---------|-------|--------------|
| ECS Fargate Tasks | 4 tasks (2 auth + 2 task) | ~$30 |
| RDS db.t3.micro | 1 instance | ~$15 |
| VPC Endpoints | 5 endpoints | ~$29 |
| CloudWatch Logs | 2 log groups | ~$5 |
| **Total (before ALB)** | | **~$79/month** |

**Note:** ALB will add ~$20/month when you set it up in Task 10.

---

## Summary

You now have a fully functional microservices architecture running on ECS:

- **Auth Service**: Handles user registration, login, and token validation
- **Task Service**: Manages tasks with JWT authentication
- **Service Discovery**: Services communicate via private DNS
- **High Availability**: 2 instances of each service across 2 AZs
- **Secure**: Private subnets, VPC Endpoints, security groups
- **Scalable**: Ready for auto-scaling configuration

Great work! 🎉
