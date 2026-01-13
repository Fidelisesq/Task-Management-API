# Lessons Learned and Challenges - ECS Task Management API

This document captures all the challenges encountered during the implementation of this project and how they were resolved. These lessons will help future developers avoid the same pitfalls.

---

## Table of Contents

1. [Network Connectivity Issues](#network-connectivity-issues)
2. [IAM Permissions Issues](#iam-permissions-issues)
3. [Security Group Configuration](#security-group-configuration)
4. [VPC Endpoints Configuration](#vpc-endpoints-configuration)
5. [Health Check Issues](#health-check-issues)
6. [Database Connection Issues](#database-connection-issues)
7. [Service Discovery Issues](#service-discovery-issues)
8. [Key Takeaways](#key-takeaways)

---

## Network Connectivity Issues

### Challenge 1: Unable to Pull Secrets from Secrets Manager

**When:** Task 7 - Deploying Auth Service to ECS

**Error Message:**
```
ResourceInitializationError: unable to pull secrets or registry auth: 
unable to retrieve secret from asm: There is a connection issue between 
the task and AWS Secrets Manager. Check your task network configuration. 
failed to fetch secret arn:aws:secretsmanager:us-east-1:211125602758:secret:rds-credentials-aAhHLW 
from secrets manager: operation error Secrets Manager: GetSecretValue, 
https response error StatusCode: 0, RequestID: , canceled, context deadline exceeded
```

**Root Cause:**
ECS tasks were deployed in **private subnets** without internet access. They couldn't reach AWS Secrets Manager or ECR to pull secrets and container images.

**Solution Options:**
We had two options:
1. **NAT Gateway** (~$35/month) - Provides internet access to private subnets
2. **VPC Endpoints** (~$29/month) - Allows private access to AWS services without internet

**Chosen Solution:** VPC Endpoints (more cost-effective and secure)

**Implementation:**
Created 5 VPC Endpoints:
1. Secrets Manager (Interface)
2. ECR API (Interface)
3. ECR Docker (Interface)
4. CloudWatch Logs (Interface)
5. S3 (Gateway)

**Commands Used:**
```bash
# Example: Create Secrets Manager endpoint
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-0792f2f110cb731ed \
  --vpc-endpoint-type Interface \
  --service-name com.amazonaws.us-east-1.secretsmanager \
  --subnet-ids subnet-01578e4938893297d subnet-0bbad45200c46c4e5 \
  --security-group-ids sg-0f19eb8f889b954d1 \
  --region us-east-1
```

**Time to Resolve:** ~2 hours (including research and implementation)

**Documentation Created:** `guides/vpc-endpoints-setup-guide.md`

---

### Challenge 2: Unable to Send Logs to CloudWatch

**When:** Task 7 - After fixing Secrets Manager issue

**Error Message:**
```
ResourceInitializationError: failed to validate logger args: 
The task cannot find the Amazon CloudWatch log group defined in the task definition. 
There is a connection issue between the task and Amazon CloudWatch. 
Check your network configuration. signal: killed
```

**Root Cause:**
Initially created only 4 VPC Endpoints (Secrets Manager, ECR API, ECR Docker, S3). Forgot that ECS tasks also need to send logs to CloudWatch Logs, which requires its own VPC Endpoint.

**Solution:**
Created the 5th VPC Endpoint for CloudWatch Logs.

**Command Used:**
```bash
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-0792f2f110cb731ed \
  --vpc-endpoint-type Interface \
  --service-name com.amazonaws.us-east-1.logs \
  --subnet-ids subnet-01578e4938893297d subnet-0bbad45200c46c4e5 \
  --security-group-ids sg-0f19eb8f889b954d1 \
  --region us-east-1
```

**Lesson Learned:**
ECS tasks in private subnets need VPC Endpoints for:
- ✅ Secrets Manager (retrieve secrets)
- ✅ ECR API (authenticate to registry)
- ✅ ECR Docker (pull images)
- ✅ CloudWatch Logs (send application logs) ← **Often forgotten!**
- ✅ S3 (download ECR image layers)

**Time to Resolve:** ~30 minutes

---

## IAM Permissions Issues

### Challenge 3: Access Denied to Secrets Manager

**When:** Task 7 - After fixing network connectivity

**Error Message:**
```
api error AccessDeniedException: User: arn:aws:sts::211125602758:assumed-role/ecsTaskExecutionRole/... 
is not authorized to perform: secretsmanager:GetSecretValue 
because no identity-based policy allows the secretsmanager:GetSecretValue action
```

**Root Cause:**
The `TaskManagementSecretsAccess` IAM policy was **created** but **NOT attached** to the `ecsTaskExecutionRole`. Creating a policy doesn't automatically attach it to a role.

**Solution:**
Attached the policy to the role.

**Command Used:**
```bash
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::211125602758:policy/TaskManagementSecretsAccess
```

**Verification:**
```bash
aws iam list-attached-role-policies --role-name ecsTaskExecutionRole
```

Expected to see:
- `AmazonECSTaskExecutionRolePolicy` (AWS managed)
- `TaskManagementSecretsAccess` (custom)

**Lesson Learned:**
IAM has two separate steps:
1. **Create policy** - Defines permissions
2. **Attach policy to role** - Actually grants those permissions

Both steps are required!

**Time to Resolve:** ~20 minutes

**Documentation Updated:** 
- `iam-policies/README.md`
- `scripts/01-foundation-setup.sh` (added verification step)

---

## Security Group Configuration

### Challenge 4: HTTPS Rule for VPC Endpoints

**When:** Task 7 and Task 8 - Deploying both services

**Error Message:**
Same as Challenge 1 (unable to pull secrets), even after creating VPC Endpoints.

**Root Cause:**
VPC Endpoints create **Elastic Network Interfaces (ENIs)** in your subnets with private IP addresses. When ECS tasks connect to AWS services, they're actually connecting to these ENI IP addresses over **HTTPS (port 443)**. 

The security group attached to ECS tasks didn't allow HTTPS traffic to the VPC Endpoints.

**Solution:**
Added an inbound HTTPS rule to each ECS task security group, allowing traffic **from itself**.

**Commands Used:**
```bash
# For Auth Service Security Group
aws ec2 authorize-security-group-ingress \
  --region us-east-1 \
  --group-id sg-0f19eb8f889b954d1 \
  --protocol tcp \
  --port 443 \
  --source-group sg-0f19eb8f889b954d1

# For Task Service Security Group
TASK_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=task-mgmt-task-sg" \
  --region us-east-1 \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --region us-east-1 \
  --group-id $TASK_SG_ID \
  --protocol tcp \
  --port 443 \
  --source-group $TASK_SG_ID
```

**Why "from itself"?**
The security group needs to allow traffic from resources that have the same security group attached. Since both the ECS tasks and VPC Endpoint ENIs use the same security group, this allows communication between them.

**Lesson Learned:**
When using VPC Endpoints, **every ECS task security group** needs:
- Inbound: HTTPS (443) from itself
- Outbound: HTTPS (443) to 0.0.0.0/0

**Time to Resolve:** ~1 hour (including troubleshooting)

**Documentation Created:** `docs/security-group-https-rule-guide.md`

---

### Challenge 5: Security Groups Not Attached to VPC Endpoints

**When:** Task 8 - Deploying Task Service

**Error Message:**
```
ResourceInitializationError: unable to pull secrets or registry auth
```

**Root Cause:**
When creating VPC Endpoints in Task 6, only the **auth-service security group** was attached. When deploying task-service with a different security group, it couldn't access the VPC Endpoints because its security group wasn't attached to the endpoints.

**The Problem:**
VPC Endpoints need to have **ALL ECS task security groups** attached to them. It's not enough to just add the HTTPS rule to the security group - the security group must also be attached to each VPC Endpoint.

**Solution:**
Added the task-service security group to all 4 Interface VPC Endpoints.

**Via AWS Console (Easier):**
1. Go to VPC → Endpoints
2. Click on each Interface endpoint
3. Actions → Manage security groups
4. Check ✅ BOTH security groups:
   - task-mgmt-auth-sg
   - task-mgmt-task-sg
5. Save

**Via AWS CLI:**
```bash
# Get task-service security group ID
TASK_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=task-mgmt-task-sg" \
  --region us-east-1 \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

# Add to each endpoint
aws ec2 modify-vpc-endpoint \
  --vpc-endpoint-id <SECRETS_MANAGER_ENDPOINT_ID> \
  --add-security-group-ids $TASK_SG_ID \
  --region us-east-1

aws ec2 modify-vpc-endpoint \
  --vpc-endpoint-id <ECR_API_ENDPOINT_ID> \
  --add-security-group-ids $TASK_SG_ID \
  --region us-east-1

aws ec2 modify-vpc-endpoint \
  --vpc-endpoint-id <ECR_DKR_ENDPOINT_ID> \
  --add-security-group-ids $TASK_SG_ID \
  --region us-east-1

aws ec2 modify-vpc-endpoint \
  --vpc-endpoint-id <CLOUDWATCH_LOGS_ENDPOINT_ID> \
  --add-security-group-ids $TASK_SG_ID \
  --region us-east-1
```

**Verification:**
```bash
aws ec2 describe-vpc-endpoints \
  --region us-east-1 \
  --filters "Name=vpc-id,Values=vpc-0792f2f110cb731ed" "Name=vpc-endpoint-type,Values=Interface" \
  --query 'VpcEndpoints[*].[ServiceName,Groups[*].GroupId]' \
  --output table
```

Should see BOTH security group IDs for each endpoint.

**Lesson Learned:**
VPC Endpoints require **TWO configurations** for each ECS task security group:

1. ✅ **Security Group Inbound Rule:** HTTPS (443) from itself
2. ✅ **VPC Endpoint Attachment:** Attach the security group to each endpoint

**Both steps are required!** The HTTPS rule alone is not enough.

**Best Practice:**
When creating VPC Endpoints, attach **ALL ECS task security groups** immediately, even if you haven't deployed all services yet. This prevents issues later.

**Time to Resolve:** ~45 minutes

**Documentation Updated:**
- `guides/vpc-endpoints-setup-guide.md`
- `docs/security-group-https-rule-guide.md`

---

## VPC Endpoints Configuration

### Challenge 6: Understanding VPC Endpoint Types

**When:** Task 6 - Setting up VPC Endpoints

**Confusion:**
Not understanding the difference between Interface endpoints and Gateway endpoints, and which services need which type.

**Resolution:**

**Interface Endpoints:**
- Create ENIs (Elastic Network Interfaces) in your subnets
- Have private IP addresses
- Require security groups
- Support DNS resolution
- Cost: $0.01/hour per endpoint (~$7.30/month)
- Used for: Secrets Manager, ECR, CloudWatch Logs, and most AWS services

**Gateway Endpoints:**
- Route table entries (not network interfaces)
- No private IP addresses
- No security groups needed
- Free to use
- Only for: S3 and DynamoDB

**Services and Their Endpoint Types:**
| Service | Endpoint Type | Why |
|---------|---------------|-----|
| Secrets Manager | Interface | Needs ENI for private access |
| ECR API | Interface | Needs ENI for private access |
| ECR Docker | Interface | Needs ENI for private access |
| CloudWatch Logs | Interface | Needs ENI for private access |
| S3 | Gateway | AWS provides free gateway access |

**Lesson Learned:**
- Most AWS services use Interface endpoints
- Only S3 and DynamoDB use Gateway endpoints
- Gateway endpoints are free, Interface endpoints cost money
- Always use Gateway endpoint for S3 when available (it's free!)

---

## Health Check Issues

### Challenge 8: Health Check Failing - Curl Not Installed

**When:** Task 8 - Deploying Task Service to ECS

**Error Message:**
```
(service task-service) (task b5067ed30cc5431d89fe74c47fd9981f) failed container health checks.
(service task-service) (deployment ecs-svc/4135006185409410497) deployment failed: tasks failed to start.
```

**Symptoms:**
- Tasks showing status: RUNNING
- Health status: UNHEALTHY
- Deployment status: FAILED
- Application logs showing: "Task Service listening on port 3000"
- No error logs in CloudWatch

**Root Cause:**
The task definition included a health check command that uses `curl`:
```json
{
  "healthCheck": {
    "command": ["CMD-SHELL", "curl -f http://localhost:3000/tasks/health || exit 1"],
    "interval": 30,
    "timeout": 5,
    "retries": 3,
    "startPeriod": 60
  }
}
```

However, the Docker image was built from `node:18-alpine`, which is a **minimal Alpine Linux image that does NOT include `curl`** by default. When ECS tried to run the health check, the `curl` command was not found, causing the health check to fail.

**Why Auth Service Didn't Fail:**
The auth-service task definition did **NOT have a health check configured**, so it never tried to run `curl`. Without a health check, ECS considers the task healthy as long as the container is running.

**Verification Commands:**
```bash
# Check if health check is configured
aws ecs describe-task-definition \
  --task-definition task-service \
  --region us-east-1 \
  --query 'taskDefinition.containerDefinitions[0].healthCheck'

# Returns health check config for task-service

aws ecs describe-task-definition \
  --task-definition auth-service \
  --region us-east-1 \
  --query 'taskDefinition.containerDefinitions[0].healthCheck'

# Returns null for auth-service (no health check)

# Check task health status
aws ecs describe-tasks \
  --cluster task-management-cluster \
  --tasks <TASK_ARN> \
  --region us-east-1 \
  --query 'tasks[0].[lastStatus,healthStatus]'

# Shows: RUNNING, UNHEALTHY
```

**Solution:**
Install `curl` in the Dockerfile using Alpine's package manager (`apk`).

**Updated Dockerfile:**
```dockerfile
FROM node:18-alpine

# Install curl for health checks
RUN apk add --no-cache curl

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application code
COPY src/ ./src/

# Expose port
EXPOSE 3000

# Set environment to production
ENV NODE_ENV=production

# Run as non-root user
USER node

# Start application
CMD ["node", "src/index.js"]
```

**Implementation Steps:**
1. Update Dockerfile to install curl
2. Rebuild Docker image with new version tag (v1.0.1)
3. Push new image to ECR
4. Create new task definition revision with updated image
5. Update ECS service to use new task definition
6. Force new deployment

**Commands Used:**
```bash
# Update Dockerfile (add curl installation)
# Then rebuild and push

cd services/task-service

docker build -t task-service:v1.0.1 .
docker tag task-service:v1.0.1 211125602758.dkr.ecr.us-east-1.amazonaws.com/task-service:v1.0.1
docker tag task-service:v1.0.1 211125602758.dkr.ecr.us-east-1.amazonaws.com/task-service:latest

aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 211125602758.dkr.ecr.us-east-1.amazonaws.com

docker push 211125602758.dkr.ecr.us-east-1.amazonaws.com/task-service:v1.0.1
docker push 211125602758.dkr.ecr.us-east-1.amazonaws.com/task-service:latest

# Update task definition via console or CLI
# Then update service
aws ecs update-service \
  --cluster task-management-cluster \
  --service task-service \
  --task-definition task-service:2 \
  --force-new-deployment \
  --region us-east-1
```

**Lesson Learned:**

**Health Checks in ECS:**
- Health checks are **optional** in ECS task definitions
- Without a health check, ECS considers a task healthy if the container is running
- With a health check, ECS runs the specified command inside the container
- If the health check command fails or doesn't exist, the task is marked UNHEALTHY

**Alpine Linux Images:**
- Alpine Linux is a minimal distribution designed for small container sizes
- It does NOT include common utilities like `curl`, `wget`, `bash` by default
- You must explicitly install any tools you need using `apk add`
- Common packages to install:
  - `curl` - for HTTP health checks
  - `bash` - if you need bash scripts
  - `ca-certificates` - for HTTPS connections

**Health Check Best Practices:**
1. **Always install health check dependencies** in your Dockerfile
2. **Use simple health checks** that don't require external dependencies
3. **Configure appropriate timeouts:**
   - `startPeriod`: 60 seconds (time for app to start)
   - `interval`: 30 seconds (how often to check)
   - `timeout`: 5 seconds (max time for check to complete)
   - `retries`: 3 (failures before marking unhealthy)
4. **Test health checks locally** before deploying:
   ```bash
   docker run -p 3000:3000 task-service:v1.0.1
   docker exec <container_id> curl -f http://localhost:3000/tasks/health
   ```

**Alternative Health Check Methods:**

If you want to avoid installing curl, you can use:

**Option 1: Node.js HTTP request (no curl needed)**
```json
{
  "healthCheck": {
    "command": [
      "CMD-SHELL",
      "node -e \"require('http').get('http://localhost:3000/tasks/health', (res) => process.exit(res.statusCode === 200 ? 0 : 1))\""
    ]
  }
}
```

**Option 2: Use wget (also needs installation)**
```dockerfile
RUN apk add --no-cache wget
```
```json
{
  "healthCheck": {
    "command": ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3000/tasks/health || exit 1"]
  }
}
```

**Option 3: TCP check (no HTTP, just port check)**
```json
{
  "healthCheck": {
    "command": ["CMD-SHELL", "nc -z localhost 3000 || exit 1"]
  }
}
```
Note: `nc` (netcat) is included in Alpine by default.

**Why Health Checks Matter:**

1. **Application-level validation** - Verifies the app is responding, not just running
2. **Automatic recovery** - ECS restarts unhealthy tasks automatically
3. **ALB integration** - ALB only sends traffic to healthy tasks
4. **Deployment safety** - Prevents bad deployments from completing
5. **Monitoring** - CloudWatch metrics track health check status

**Comparison:**

| Scenario | Health Check? | Curl Installed? | Result |
|----------|---------------|-----------------|--------|
| Auth Service (initial) | ❌ No | ❌ No | ✅ Works (no check to fail) |
| Task Service (initial) | ✅ Yes | ❌ No | ❌ Failed (curl not found) |
| Task Service (fixed) | ✅ Yes | ✅ Yes | ✅ Works (health check passes) |
| Auth Service (updated) | ✅ Yes | ✅ Yes | ✅ Works (health check passes) |

**Time to Resolve:** ~45 minutes (including diagnosis, fix, rebuild, and deployment)

**Documentation Updated:**
- Updated both Dockerfiles to install curl
- Added health check troubleshooting to guides
- Documented alternative health check methods

**Follow-up Action:**
Also updated auth-service to include health checks for consistency and production readiness, even though it was working without them.

---

## Database Connection Issues

### Challenge 9: RDS Requires SSL/TLS Encryption

**When:** Task 8 - Testing auth-service registration endpoint

**Error Message (from CloudWatch Logs):**
```
Registration error: error: no pg_hba.conf entry for host "10.0.101.27", 
user "dbadmin", database "taskmanagement", no encryption
```

**Symptoms:**
- Health check endpoint works: `curl http://10.0.98.90:3000/auth/health` ✅
- Registration endpoint fails: `{"error":"Internal Server Error","message":"An unexpected error occurred"}` ❌
- Security groups verified correct (RDS allows port 5432 from ECS tasks)
- Network connectivity confirmed working

**Root Cause:**
Amazon RDS PostgreSQL instances **require SSL/TLS encrypted connections by default**. The Node.js `pg` library was attempting to connect without SSL, which RDS rejected with the "no encryption" error.

The error code `28000` is PostgreSQL's authentication failure code, specifically for SSL/TLS requirement violations.

**Why Health Check Worked:**
The health check endpoint (`/auth/health`) doesn't connect to the database - it just returns a JSON response. Only endpoints that query the database (like `/auth/register`) failed.

**Solution:**
Add SSL configuration to the PostgreSQL connection pool in both services.

**Code Changes:**

**Before (No SSL):**
```javascript
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

**After (With SSL):**
```javascript
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
```

**Implementation Steps:**

1. **Update both service files:**
   - `services/auth-service/src/index.js`
   - `services/task-service/src/index.js`

2. **Rebuild Docker images:**
   ```bash
   cd services/auth-service
   docker build -t auth-service:v1.0.2 .
   docker tag auth-service:v1.0.2 211125602758.dkr.ecr.us-east-1.amazonaws.com/auth-service:v1.0.2
   
   cd ../task-service
   docker build -t task-service:v1.0.2 .
   docker tag task-service:v1.0.2 211125602758.dkr.ecr.us-east-1.amazonaws.com/task-service:v1.0.2
   ```

3. **Push to ECR:**
   ```bash
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 211125602758.dkr.ecr.us-east-1.amazonaws.com
   
   docker push 211125602758.dkr.ecr.us-east-1.amazonaws.com/auth-service:v1.0.2
   docker push 211125602758.dkr.ecr.us-east-1.amazonaws.com/task-service:v1.0.2
   ```

4. **Update task definitions:**
   - Create new task definition revisions with v1.0.2 images
   - Or use AWS Console to update image tags

5. **Update ECS services:**
   ```bash
   # Update auth-service to use new task definition
   aws ecs update-service \
     --cluster task-management-cluster \
     --service auth-service \
     --task-definition auth-service:3 \
     --force-new-deployment \
     --region us-east-1
   
   # Update task-service
   aws ecs update-service \
     --cluster task-management-cluster \
     --service task-service \
     --force-new-deployment \
     --region us-east-1
   ```

6. **Wait for deployment** (~5 minutes)

7. **Get new task IP and test:**
   ```bash
   # Get new auth-service IP
   aws ecs list-tasks --cluster task-management-cluster --service-name auth-service --region us-east-1 --desired-status RUNNING --query "taskArns[0]" --output text | xargs -I {} aws ecs describe-tasks --cluster task-management-cluster --tasks {} --region us-east-1 --query "tasks[0].containers[0].networkInterfaces[0].privateIpv4Address" --output text
   
   # Test registration (from EC2 in VPC)
   curl -X POST http://<NEW_IP>:3000/auth/register \
     -H "Content-Type: application/json" \
     -d '{"username": "testuser","email": "test@example.com","password": "Test123!@#"}'
   ```

**Verification:**
```bash
# Check CloudWatch logs for successful connection
aws logs tail /ecs/auth-service --region us-east-1 --since 5m

# Should see no more "no encryption" errors
# Successful registration should return:
# {"message":"User registered successfully","user":{...}}
```

**Why `rejectUnauthorized: false`?**

This setting tells the PostgreSQL client to accept the RDS SSL certificate without verifying it against a Certificate Authority (CA). 

**Options:**
1. **`rejectUnauthorized: false`** (Used here)
   - ✅ Simple, works immediately
   - ✅ Still encrypted (SSL/TLS active)
   - ⚠️ Doesn't verify certificate authenticity
   - ✅ Good for: Development, testing, internal VPC communication

2. **`rejectUnauthorized: true` with CA certificate** (Production recommended)
   - ✅ Full SSL/TLS verification
   - ✅ Verifies certificate authenticity
   - ❌ Requires downloading and bundling RDS CA certificate
   - ✅ Good for: Production, compliance requirements

**For production, use full verification:**
```javascript
const fs = require('fs');

const pool = new Pool({
  // ... other config ...
  ssl: {
    rejectUnauthorized: true,
    ca: fs.readFileSync('/path/to/rds-ca-2019-root.pem').toString()
  }
});
```

Download RDS CA certificate from: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html

**Lesson Learned:**

**RDS SSL/TLS Requirements:**
- Amazon RDS PostgreSQL **requires SSL/TLS by default**
- This is a security best practice to encrypt data in transit
- Even though your ECS tasks and RDS are in the same VPC, encryption is still required
- The `pg` library doesn't enable SSL by default - you must configure it

**Common Symptoms of Missing SSL:**
- ✅ Network connectivity works (security groups correct)
- ✅ Health checks pass (non-database endpoints work)
- ❌ Database operations fail with "no encryption" error
- ❌ Error code: `28000` (authentication failure)
- ❌ Error message: "no pg_hba.conf entry for host... no encryption"

**Debugging Steps:**
1. Check CloudWatch logs for actual error (don't rely on generic 500 errors)
2. Look for "no encryption" or "SSL" in error messages
3. Verify RDS security group allows connections (but this isn't the issue if you see "no encryption")
4. Add SSL configuration to database client

**Other Database Clients:**

**Python (psycopg2):**
```python
import psycopg2

conn = psycopg2.connect(
    host=os.environ['DB_HOST'],
    database=os.environ['DB_NAME'],
    user=os.environ['DB_USER'],
    password=os.environ['DB_PASSWORD'],
    sslmode='require'  # or 'verify-full' with CA cert
)
```

**Java (JDBC):**
```java
String url = "jdbc:postgresql://" + dbHost + ":" + dbPort + "/" + dbName + "?ssl=true&sslmode=require";
Connection conn = DriverManager.getConnection(url, dbUser, dbPassword);
```

**Go (lib/pq):**
```go
connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=require",
    dbHost, dbPort, dbUser, dbPassword, dbName)
db, err := sql.Open("postgres", connStr)
```

**Time to Resolve:** ~1 hour (including diagnosis, code changes, rebuild, and deployment)

**Documentation Updated:**
- Updated both service source files with SSL configuration
- Added troubleshooting steps to deployment guides

**Key Takeaway:**
Always configure SSL/TLS when connecting to RDS, even from within the same VPC. RDS enforces encryption by default for security compliance.

---

## Service Discovery Issues

### Challenge 10: Cannot Resolve Service Discovery DNS

**When:** Task 7 - Testing auth-service from EC2 instance

**Error Message:**
```bash
curl http://auth-service.task-management.local:3000/auth/health
curl: (6) Could not resolve host: auth-service.task-management.local
```

**Root Cause:**
Service Discovery DNS names (*.task-management.local) only work **within the VPC** for resources that use the VPC DNS resolver. The EC2 instance was in a public subnet and might not have been using the VPC DNS resolver.

**Solution:**
Used the private IP address of the ECS task instead for testing from EC2.

**Commands to Get Private IP:**
```bash
# List tasks
aws ecs list-tasks \
  --cluster task-management-cluster \
  --service-name auth-service \
  --region us-east-1

# Get task details
aws ecs describe-tasks \
  --cluster task-management-cluster \
  --tasks <TASK_ARN> \
  --region us-east-1 \
  --query 'tasks[0].containers[0].networkInterfaces[0].privateIpv4Address' \
  --output text
```

**Testing:**
```bash
# From EC2 instance
curl http://10.0.118.161:3000/auth/health
# Worked! ✅
```

**Lesson Learned:**
- Service Discovery DNS is for **service-to-service communication** within the VPC
- For external testing, use:
  - Private IP addresses (from within VPC)
  - Application Load Balancer (from internet)
- Service Discovery DNS requires:
  - VPC DNS support enabled
  - VPC DNS hostnames enabled
  - Resources using VPC DNS resolver (10.0.0.2)

**When Service Discovery Works:**
- ✅ Task-service calling auth-service
- ✅ Any ECS task calling another ECS task
- ✅ Lambda functions in the VPC
- ✅ EC2 instances using VPC DNS resolver

**When Service Discovery Doesn't Work:**
- ❌ Testing from local machine
- ❌ Testing from internet
- ❌ EC2 instances not using VPC DNS resolver

**Time to Resolve:** ~15 minutes

---

## Key Takeaways

### 1. VPC Endpoints Checklist

For ECS tasks in private subnets, you need:

- [ ] Create 5 VPC Endpoints:
  - [ ] Secrets Manager (Interface)
  - [ ] ECR API (Interface)
  - [ ] ECR Docker (Interface)
  - [ ] CloudWatch Logs (Interface) ← Often forgotten!
  - [ ] S3 (Gateway)

- [ ] Configure Security Groups:
  - [ ] Add HTTPS (443) inbound rule to each ECS task security group (from itself)
  - [ ] Attach ALL ECS task security groups to each Interface endpoint

- [ ] Verify IAM Permissions:
  - [ ] Create custom policies
  - [ ] Attach policies to ecsTaskExecutionRole

- [ ] Wait 2-3 minutes for DNS propagation

- [ ] Force new deployment of ECS services

### 2. Common Mistakes to Avoid

❌ **Mistake 1:** Creating VPC Endpoints but forgetting CloudWatch Logs endpoint
✅ **Fix:** Always create all 5 endpoints

❌ **Mistake 2:** Creating IAM policy but not attaching it to the role
✅ **Fix:** Always verify with `aws iam list-attached-role-policies`

❌ **Mistake 3:** Adding HTTPS rule to security group but not attaching security group to VPC Endpoints
✅ **Fix:** Both steps are required - rule + attachment

❌ **Mistake 4:** Only attaching first service's security group to VPC Endpoints
✅ **Fix:** Attach ALL ECS task security groups to endpoints immediately

❌ **Mistake 5:** Expecting Service Discovery DNS to work from internet
✅ **Fix:** Use ALB for external access, Service Discovery for internal

### 3. Debugging Workflow

When ECS tasks fail to start:

1. **Check Service Events**
   ```bash
   aws ecs describe-services \
     --cluster task-management-cluster \
     --services <SERVICE_NAME> \
     --region us-east-1 \
     --query 'services[0].events[0:5]'
   ```

2. **Check Stopped Tasks**
   ```bash
   aws ecs list-tasks \
     --cluster task-management-cluster \
     --service-name <SERVICE_NAME> \
     --desired-status STOPPED \
     --region us-east-1
   ```

3. **Get Task Stop Reason**
   ```bash
   aws ecs describe-tasks \
     --cluster task-management-cluster \
     --tasks <TASK_ARN> \
     --region us-east-1 \
     --query 'tasks[0].[stoppedReason,containers[0].reason]'
   ```

4. **Check CloudWatch Logs** (if tasks started)
   ```bash
   aws logs tail //ecs/<SERVICE_NAME> --region us-east-1
   ```

5. **Verify VPC Endpoints**
   ```bash
   aws ec2 describe-vpc-endpoints \
     --region us-east-1 \
     --filters "Name=vpc-id,Values=<VPC_ID>" \
     --query 'VpcEndpoints[*].[ServiceName,State,Groups[*].GroupId]'
   ```

6. **Verify IAM Policies**
   ```bash
   aws iam list-attached-role-policies --role-name ecsTaskExecutionRole
   ```

7. **Verify Security Group Rules**
   ```bash
   aws ec2 describe-security-groups \
     --group-ids <SG_ID> \
     --query 'SecurityGroups[0].IpPermissions[?FromPort==`443`]'
   ```

### 4. Cost Optimization

**VPC Endpoints vs NAT Gateway:**

| Solution | Monthly Cost | Pros | Cons |
|----------|--------------|------|------|
| VPC Endpoints (5) | ~$29 | More secure, traffic stays in AWS network | More complex setup |
| NAT Gateway | ~$35 | Simpler setup | Less secure, higher cost |

**Savings:** ~$6/month by using VPC Endpoints

**Recommendation:** Use VPC Endpoints for production workloads

### 5. Time Investment

Total time spent on challenges: **~7 hours**

Breakdown:
- Network connectivity (VPC Endpoints): ~2.5 hours
- IAM permissions: ~20 minutes
- Security group configuration: ~1.5 hours
- Service Discovery testing: ~15 minutes
- Health check issues: ~45 minutes
- Database SSL/TLS configuration: ~1 hour
- Documentation: ~45 minutes

**With this documentation, future implementations should take < 1 hour!**

### 6. Documentation Created

As a result of these challenges, we created:

1. `guides/vpc-endpoints-setup-guide.md` - Complete VPC Endpoints setup
2. `docs/security-group-https-rule-guide.md` - Security group configuration
3. `guides/troubleshooting-ecs-deployment.md` - Common issues and solutions
4. `iam-policies/README.md` - IAM policy explanation
5. `docs/lessons-learned-and-challenges.md` - This document

### 7. What Worked Well

✅ **Systematic troubleshooting** - Checking service events, stopped tasks, and logs
✅ **AWS CLI commands** - Faster than console for verification
✅ **Documentation as we go** - Captured solutions immediately
✅ **Incremental deployment** - Deployed auth-service first, learned lessons, then deployed task-service
✅ **Using Git Bash on Windows** - Worked well with minor path adjustments

### 8. Recommendations for Future Projects

1. **Create VPC Endpoints early** - Do this in Task 1 or Task 6, not during deployment
2. **Attach all security groups to endpoints immediately** - Even if services aren't deployed yet
3. **Verify IAM policy attachment** - Don't assume creation = attachment
4. **Test incrementally** - Deploy one service, verify it works, then deploy the next
5. **Document as you go** - Don't wait until the end
6. **Use AWS Console for complex configurations** - Easier than CLI for VPC Endpoints
7. **Keep a resource inventory** - Track all IDs and ARNs in `docs/resource-inventory.md`

---

## Summary

The main challenges were all related to **network connectivity** and **security configuration** for ECS tasks in private subnets. The key insight is that private subnets require special configuration (VPC Endpoints) to access AWS services, and this configuration has multiple parts that must all be correct:

1. ✅ VPC Endpoints created (all 5)
2. ✅ Security group HTTPS rules added
3. ✅ Security groups attached to endpoints
4. ✅ IAM policies created AND attached
5. ✅ VPC DNS enabled

Missing any one of these will cause deployment failures. With this documentation, future developers can avoid these pitfalls and deploy successfully on the first try!

---

**Last Updated:** January 7, 2026
**Project:** ECS Task Management API
**AWS Account:** 211125602758
**Region:** us-east-1
