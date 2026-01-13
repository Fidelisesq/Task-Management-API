# Task 7: Deploy Auth Service to ECS Guide

This guide provides step-by-step instructions for creating the Auth Service task definition and deploying it to ECS with service discovery.

## Prerequisites

- Completed Task 6 (ECS Cluster, CloudWatch Log Groups, Cloud Map Namespace)
- Auth Service container image in ECR: `211125602758.dkr.ecr.us-east-1.amazonaws.com/auth-service:v1.0.0`
- Secrets Manager secrets created (rds-credentials, jwt-secret)
- IAM roles created (ecsTaskExecutionRole, ecsTaskRole)
- **CRITICAL: VPC Endpoints configured** (see below)

## ⚠️ CRITICAL: VPC Endpoints Required

**Before creating the ECS service, you MUST set up VPC Endpoints for private subnet access.**

Your ECS tasks run in private subnets and need to access:
- AWS Secrets Manager (to retrieve database credentials and JWT secret)
- Amazon ECR (to pull container images)
- Amazon CloudWatch Logs (to send application logs)
- Amazon S3 (for ECR image layers)

**Without VPC Endpoints, your tasks will fail with:**
```
ResourceInitializationError: unable to pull secrets or registry auth
ResourceInitializationError: failed to validate logger args
```

### Quick Setup

You have two options:

**Option 1: NAT Gateway** (if you already have one)
- Ensure private subnet route table has: `0.0.0.0/0 → NAT Gateway`
- Cost: ~$35/month

**Option 2: VPC Endpoints** (Recommended - more cost-effective)
- Create 5 VPC Endpoints (Secrets Manager, ECR API, ECR Docker, CloudWatch Logs, S3)
- Cost: ~$29/month
- **📄 Follow the complete guide:** `guides/vpc-endpoints-setup-guide.md`

### VPC Endpoints Quick Checklist

If using VPC Endpoints, create these 5 endpoints:

- [ ] **Secrets Manager Endpoint** (Interface)
  - Service: `com.amazonaws.us-east-1.secretsmanager`
  - Subnets: Both private subnets
  - Security group: task-mgmt-auth-sg

- [ ] **ECR API Endpoint** (Interface)
  - Service: `com.amazonaws.us-east-1.ecr.api`
  - Subnets: Both private subnets
  - Security group: task-mgmt-auth-sg

- [ ] **ECR Docker Endpoint** (Interface)
  - Service: `com.amazonaws.us-east-1.ecr.dkr`
  - Subnets: Both private subnets
  - Security group: task-mgmt-auth-sg

- [ ] **CloudWatch Logs Endpoint** (Interface)
  - Service: `com.amazonaws.us-east-1.logs`
  - Subnets: Both private subnets
  - Security group: task-mgmt-auth-sg

- [ ] **S3 Gateway Endpoint** (Gateway)
  - Service: `com.amazonaws.us-east-1.s3`
  - Route table: Private subnet route table

- [ ] **CRITICAL: Security Group HTTPS Rule**
  ```bash
  # Allow ECS tasks to access VPC Endpoints over HTTPS
  aws ec2 authorize-security-group-ingress \
    --region us-east-1 \
    --group-id <AUTH_SG_ID> \
    --protocol tcp \
    --port 443 \
    --source-group <AUTH_SG_ID>
  ```
  **This rule is REQUIRED for each ECS task security group!**

- [ ] **IAM Policy Attached**
  ```bash
  # Verify TaskManagementSecretsAccess is attached
  aws iam list-attached-role-policies --role-name ecsTaskExecutionRole
  ```
  - Subnets: Both private subnets
  - Security group: task-mgmt-auth-sg

- [ ] **ECR Docker Endpoint** (Interface)
  - Service: `com.amazonaws.us-east-1.ecr.dkr`
  - Subnets: Both private subnets
  - Security group: task-mgmt-auth-sg

- [ ] **S3 Gateway Endpoint** (Gateway)
  - Service: `com.amazonaws.us-east-1.s3`
  - Route table: Private subnet route table

- [ ] **Security Group Rule Added**
  - task-mgmt-auth-sg allows inbound HTTPS (443) from itself

**⏱️ Wait 2-3 minutes after creating endpoints before proceeding.**

**📖 Detailed instructions:** See `guides/vpc-endpoints-setup-guide.md`

## Overview

In this task, you will:
1. Create an ECS Task Definition for the Auth Service
2. Configure container settings and environment variables
3. Set up CloudWatch logging
4. Create an ECS Service with 2 tasks
5. Enable service discovery registration
6. Verify tasks are running and registered

---

## Step 1: Create Task Definition

### 1.1 Navigate to ECS Task Definitions

1. Open the AWS Console
2. Go to **ECS** service
3. Click **Task definitions** in the left sidebar
4. Click **Create new task definition** button (or **Create new task definition** dropdown → **Create new task definition**)

### 1.2 Configure Task Definition - Basic Settings

**Task definition family:**
- **Task definition family name:** `auth-service`

**Infrastructure requirements:**
- **Launch type:** Select **AWS Fargate**
- **Operating system/Architecture:** **Linux/X86_64**
- **Network mode:** **awsvpc** (automatically selected for Fargate)

**Task size:**
- **CPU:** `0.25 vCPU` (select from dropdown)
- **Memory:** `0.5 GB` (select from dropdown)

**Task roles:**
- **Task execution role:** Select `ecsTaskExecutionRole`
  - This role allows ECS to pull images from ECR and access Secrets Manager
- **Task role:** Select `ecsTaskRole`
  - This role allows the container to write to CloudWatch Logs

### 1.3 Configure Container - Container Details

Scroll down to the **Container - 1** section:

**Container details:**
- **Name:** `auth-service-container`
- **Image URI:** `211125602758.dkr.ecr.us-east-1.amazonaws.com/auth-service:v1.0.0`
  - Copy this exactly from your ECR repository
- **Essential container:** ✅ **Yes** (checked)

**Port mappings:**
- Click **Add port mapping**
- **Container port:** `3000`
- **Protocol:** `TCP`
- **Port name:** `auth-service-3000-tcp` (auto-generated)
- **App protocol:** Leave empty

### 1.4 Configure Container - Environment Variables

Scroll down to **Environment variables** section.

We need to configure environment variables from Secrets Manager. Click **Add environment variable** for each:

**Environment variables from Secrets Manager:**

1. **DB_HOST**
   - **Key:** `DB_HOST`
   - **Value type:** Select **ValueFrom**
   - **Value:** `arn:aws:secretsmanager:us-east-1:211125602758:secret:rds-credentials-aAhHLW:host::`
   - Format: `<secret-arn>:<json-key>::`

2. **DB_PORT**
   - **Key:** `DB_PORT`
   - **Value type:** Select **ValueFrom**
   - **Value:** `arn:aws:secretsmanager:us-east-1:211125602758:secret:rds-credentials-aAhHLW:port::`

3. **DB_NAME**
   - **Key:** `DB_NAME`
   - **Value type:** Select **ValueFrom**
   - **Value:** `arn:aws:secretsmanager:us-east-1:211125602758:secret:rds-credentials-aAhHLW:dbname::`

4. **DB_USER**
   - **Key:** `DB_USER`
   - **Value type:** Select **ValueFrom**
   - **Value:** `arn:aws:secretsmanager:us-east-1:211125602758:secret:rds-credentials-aAhHLW:username::`

5. **DB_PASSWORD**
   - **Key:** `DB_PASSWORD`
   - **Value type:** Select **ValueFrom**
   - **Value:** `arn:aws:secretsmanager:us-east-1:211125602758:secret:rds-credentials-aAhHLW:password::`

6. **JWT_SECRET**
   - **Key:** `JWT_SECRET`
   - **Value type:** Select **ValueFrom**
   - **Value:** `arn:aws:secretsmanager:us-east-1:211125602758:secret:jwt-secret-z96Mor:secret::`

7. **JWT_EXPIRATION**
   - **Key:** `JWT_EXPIRATION`
   - **Value type:** Select **Value**
   - **Value:** `3600`

**Important Notes:**
- Replace the secret ARNs with your actual ARNs from Secrets Manager
- The format is: `<secret-arn>:<json-key>::`
- The double colon `::` at the end is required
- For JWT_EXPIRATION, use regular **Value** type (not ValueFrom)

### 1.5 Configure Container - Logging

Scroll down to **Storage and Logging** section:

**Log configuration:**
- **Log driver:** Select **awslogs** (should be default)
- **awslogs-group:** `/ecs/auth-service`
- **awslogs-region:** `us-east-1`
- **awslogs-stream-prefix:** `ecs`

This will send all container logs to the CloudWatch log group we created in Task 6.

### 1.6 Review and Create Task Definition

1. Scroll to the bottom
2. Review all settings
3. Click **Create** button
4. Wait for the task definition to be created

**Expected Result:**
```
Task definition: auth-service:1
Status: Active
```

---

## Step 2: Create ECS Service

Now we'll create a service that runs 2 instances of the Auth Service.

### 2.1 Navigate to Create Service

1. From the task definition page, click **Deploy** dropdown
2. Select **Create service**

OR

1. Go to **ECS** → **Clusters**
2. Click on `task-management-cluster`
3. Click **Create** button in the Services tab

### 2.2 Configure Service - Environment

**Compute configuration:**
- **Compute options:** Select **Launch type**
- **Launch type:** Select **FARGATE**

**Application type:**
- Select **Service**

**Task definition:**
- **Family:** Select `auth-service`
- **Revision:** Select `1 (LATEST)`

**Service name:**
- **Service name:** `auth-service`

**Desired tasks:**
- **Desired tasks:** `2`

### 2.3 Configure Service - Networking

**Networking:**
- **VPC:** Select `vpc-0792f2f110cb731ed` (your VPC)

**Subnets:**
- Select **ONLY private subnets:**
  - ✅ `subnet-01578e4938893297d` (Private Subnet 1 - us-east-1a)
  - ✅ `subnet-0bbad45200c46c4e5` (Private Subnet 2 - us-east-1b)
- ❌ Do NOT select public subnets

**Security group:**
- Select **Use an existing security group**
- Select `task-mgmt-auth-sg` (sg-0f19eb8f889b954d1)
- Remove the default security group if it's selected

**Public IP:**
- **Turn off** public IP assignment (we're in private subnets)

### 2.4 Configure Service - Service Discovery

**Service discovery (optional):**
- Check ✅ **Use service discovery**

**Namespace:**
- Select `task-management.local` (the namespace we created in Task 6)

**Service discovery service:**
- Select **Create new service discovery service**

**Service discovery name:**
- **Service discovery name:** `auth-service`
- This will create DNS: `auth-service.task-management.local`

**DNS record type:**
- Select **A record**

**TTL:**
- **TTL:** `60` seconds

**Service discovery routing policy:**
- Select **Multivalue answer routing**

### 2.5 Configure Service - Load Balancing (Skip for Now)

**Load balancing:**
- Select **None**
- We'll configure the ALB in Task 10

### 2.6 Configure Service - Auto Scaling (Skip for Now)

**Service auto scaling:**
- Select **Do not use service auto scaling**
- We'll configure auto scaling in Task 11

### 2.7 Review and Create Service

1. Scroll to the bottom
2. Review all settings
3. Click **Create** button
4. Wait for the service to be created (~2-3 minutes)

**Expected Result:**
```
Service: auth-service
Status: Active
Desired tasks: 2
Running tasks: 2
Pending tasks: 0
```

---

## Step 3: Verify Service Deployment

### 3.1 Check Service Status

1. Go to **ECS** → **Clusters** → `task-management-cluster`
2. Click on the **Services** tab
3. Click on `auth-service`
4. Check the service details:
   - **Status:** Active
   - **Desired tasks:** 2
   - **Running tasks:** 2 (may take 2-3 minutes to reach this)

### 3.2 Check Task Status

1. In the service details page, click on the **Tasks** tab
2. You should see 2 tasks with status **RUNNING**
3. Click on one of the tasks to view details
4. Check:
   - **Last status:** RUNNING
   - **Health status:** HEALTHY (if health checks are configured)
   - **Private IP:** Note the IP address

### 3.3 Verify CloudWatch Logs

1. Go to **CloudWatch** → **Log groups**
2. Click on `/ecs/auth-service`
3. You should see 2 log streams (one for each task)
4. Click on a log stream
5. You should see logs like:
   ```
   Auth Service listening on port 3000
   ```

### 3.4 Verify Service Discovery Registration

**Option 1: Via Cloud Map Console**
1. Go to **Cloud Map** → **Namespaces**
2. Click on `task-management.local`
3. Click on **Services** tab
4. You should see `auth-service` listed
5. Click on `auth-service`
6. You should see 2 service instances registered with their private IPs

**Option 2: Via Route 53 Console**
1. Go to **Route 53** → **Hosted zones**
2. Click on `task-management.local`
3. You should see an A record for `auth-service.task-management.local`
4. It should have 2 IP addresses (one for each task)

### 3.5 Test DNS Resolution (Optional - Advanced)

If you have access to an EC2 instance in the same VPC, you can test DNS resolution:

```bash
# From an EC2 instance in the same VPC
nslookup auth-service.task-management.local

# Or using dig
dig auth-service.task-management.local
```

You should see 2 IP addresses returned.

---

## Step 4: Troubleshooting

### Issue: Tasks are stuck in PENDING status

**Possible causes:**
1. **No available IP addresses in subnets**
   - Solution: Check subnet CIDR ranges have available IPs

2. **Cannot pull container image**
   - Solution: Verify ecsTaskExecutionRole has ECR permissions
   - Check the image URI is correct

3. **Cannot access Secrets Manager**
   - Solution: Verify ecsTaskExecutionRole has Secrets Manager permissions
   - Check secret ARNs are correct

**How to debug:**
1. Click on the task
2. Click on **Logs** tab
3. Check for error messages
4. Or go to CloudWatch Logs and check the log stream

### Issue: Tasks start but immediately stop

**Possible causes:**
1. **Application error**
   - Solution: Check CloudWatch logs for error messages
   - Common issues: Cannot connect to database, invalid secrets

2. **Database connection failure**
   - Solution: Verify security group allows traffic from auth-service-sg to rds-sg on port 5432
   - Check RDS endpoint is correct in Secrets Manager

3. **Missing environment variables**
   - Solution: Verify all environment variables are configured in task definition

**How to debug:**
1. Go to CloudWatch Logs → `/ecs/auth-service`
2. Find the log stream for the failed task
3. Look for error messages

### Issue: Service discovery not working

**Possible causes:**
1. **Namespace not found**
   - Solution: Verify `task-management.local` namespace exists in Cloud Map

2. **VPC DNS settings**
   - Solution: Verify VPC has DNS resolution and DNS hostnames enabled
   - Go to VPC → Select your VPC → Actions → Edit DNS resolution (should be enabled)
   - Go to VPC → Select your VPC → Actions → Edit DNS hostnames (should be enabled)

### Issue: Cannot access Secrets Manager

**Error in logs:** `Error: Unable to fetch secret`

**Solution:**
1. Verify the secret ARNs are correct
2. Check the format: `<secret-arn>:<json-key>::`
3. Verify ecsTaskExecutionRole has the `TaskManagementSecretsAccess` policy attached
4. Check the policy allows `secretsmanager:GetSecretValue` for your secrets

---

## Step 5: Verification Checklist

Before marking Task 7 as complete, verify:

### ✅ Task Definition Verification

- [ ] Task definition `auth-service:1` exists
- [ ] Launch type: Fargate
- [ ] CPU: 0.25 vCPU, Memory: 0.5 GB
- [ ] Task execution role: ecsTaskExecutionRole
- [ ] Task role: ecsTaskRole
- [ ] Container image: auth-service:v1.0.0
- [ ] Port mapping: 3000/TCP
- [ ] All 7 environment variables configured
- [ ] CloudWatch logging configured

### ✅ Service Verification

- [ ] Service `auth-service` exists in cluster
- [ ] Status: Active
- [ ] Desired tasks: 2
- [ ] Running tasks: 2
- [ ] Launch type: Fargate
- [ ] Subnets: Private subnets only
- [ ] Security group: task-mgmt-auth-sg
- [ ] Service discovery enabled

### ✅ Tasks Verification

- [ ] 2 tasks in RUNNING status
- [ ] Tasks have private IP addresses
- [ ] Tasks are in different availability zones (for high availability)
- [ ] No tasks in STOPPED or PENDING status

### ✅ CloudWatch Logs Verification

- [ ] Log group `/ecs/auth-service` has 2 log streams
- [ ] Logs show "Auth Service listening on port 3000"
- [ ] No error messages in logs

### ✅ Service Discovery Verification

- [ ] Service `auth-service` registered in Cloud Map
- [ ] 2 service instances showing in Cloud Map
- [ ] DNS record `auth-service.task-management.local` exists in Route 53
- [ ] DNS record has 2 IP addresses

---

## Step 6: Document Resource IDs

Update your `docs/resource-inventory.md` file:

```markdown
## Task 7: Auth Service Deployment

### Task Definition

| Resource | Value |
|----------|-------|
| Task Definition | auth-service:1 |
| Launch Type | Fargate |
| CPU | 0.25 vCPU |
| Memory | 0.5 GB |
| Task Execution Role | ecsTaskExecutionRole |
| Task Role | ecsTaskRole |

### ECS Service

| Resource | Value |
|----------|-------|
| Service Name | auth-service |
| Cluster | task-management-cluster |
| Desired Tasks | 2 |
| Running Tasks | 2 |
| Launch Type | Fargate |
| Subnets | Private Subnet 1, Private Subnet 2 |
| Security Group | task-mgmt-auth-sg |

### Service Discovery

| Resource | Value |
|----------|-------|
| Service Name | auth-service |
| DNS Name | auth-service.task-management.local |
| Registered Instances | 2 |
| IP Addresses | [Task 1 IP], [Task 2 IP] |
```

---

## Key Concepts Learned

### Task Definition
- Blueprint for running containers
- Defines CPU, memory, image, environment variables
- Reusable across multiple services

### ECS Service
- Maintains desired number of tasks
- Automatically replaces failed tasks
- Integrates with load balancers and service discovery

### Secrets Manager Integration
- Securely inject secrets as environment variables
- No secrets in code or task definition
- Automatic rotation support

### Service Discovery
- DNS-based service discovery
- Automatic registration/deregistration
- Enables inter-service communication

### High Availability
- Tasks in multiple availability zones
- Automatic task replacement on failure
- Load distribution across tasks

---

## Next Steps

Once you've completed all verification steps:

1. ✅ Mark Task 7 as complete
2. Update your resource inventory document
3. Proceed to **Task 8: Deploy Task Service to ECS**

Task 8 will be similar to Task 7, but for the Task Service, which will:
- Use the task-service container image
- Include AUTH_SERVICE_URL environment variable
- Call the Auth Service for token validation

---

## Cost Considerations

**ECS Fargate Tasks (2 tasks):**
- 0.25 vCPU × 2 tasks × $0.04048 per vCPU-hour = ~$0.08/hour
- 0.5 GB × 2 tasks × $0.004445 per GB-hour = ~$0.004/hour
- **Total: ~$0.084/hour or ~$60/month** (if running 24/7)

**CloudWatch Logs:**
- Minimal for 2 tasks (~$1-2/month)

**Service Discovery:**
- Essentially free (queries are $0.0000001 each)

**Estimated monthly cost for Auth Service:** ~$61-62

---

## Summary

You have successfully:
- ✅ Created a task definition for the Auth Service
- ✅ Configured environment variables from Secrets Manager
- ✅ Deployed the Auth Service with 2 tasks
- ✅ Enabled service discovery registration
- ✅ Verified tasks are running and healthy
- ✅ Confirmed service discovery is working

Your Auth Service is now running in ECS and discoverable via DNS!

