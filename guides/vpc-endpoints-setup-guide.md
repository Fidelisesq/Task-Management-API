# VPC Endpoints Setup Guide

This guide will help you create VPC Endpoints so your ECS tasks in private subnets can access AWS services (Secrets Manager, ECR) without needing a NAT Gateway.

## Why You Need This

**Problem:** Your ECS tasks are failing with:
```
ResourceInitializationError: unable to pull secrets or registry auth
```

**Cause:** Tasks in private subnets cannot reach AWS Secrets Manager or ECR

**Solution:** Create VPC Endpoints to allow private subnet access to AWS services

---

## Prerequisites

- VPC: `vpc-0792f2f110cb731ed`
- Private Subnets: 
  - `subnet-01578e4938893297d` (us-east-1a)
  - `subnet-0bbad45200c46c4e5` (us-east-1b)
- Security Groups: 
  - `task-mgmt-auth-sg` (for auth-service)
  - `task-mgmt-task-sg` (for task-service)
  - **IMPORTANT:** ALL ECS task security groups must be attached

---

## Step 1: Create Secrets Manager VPC Endpoint

### 1.1 Navigate to VPC Endpoints

1. Open AWS Console
2. Go to **VPC** service
3. Click **Endpoints** in the left sidebar
4. Click **Create endpoint** button

### 1.2 Configure Secrets Manager Endpoint

**Name and Service:**
- **Name tag:** `secrets-manager-endpoint`
- **Service category:** AWS services (default)
- **Services:** 
  - In the search box, type: `secretsmanager`
  - Select: **com.amazonaws.us-east-1.secretsmanager**
  - Type should show: **Interface**

**VPC:**
- **VPC:** Select `vpc-0792f2f110cb731ed`

**Subnets:**
- **Availability Zone: us-east-1a**
  - Select: `subnet-01578e4938893297d` (Private Subnet 1)
- **Availability Zone: us-east-1b**
  - Select: `subnet-0bbad45200c46c4e5` (Private Subnet 2)

**Security groups:**
- Uncheck the default security group
- Check ✅ **task-mgmt-auth-sg** (for auth-service tasks)
- Check ✅ **task-mgmt-task-sg** (for task-service tasks)
- **IMPORTANT:** Select ALL ECS task security groups that will use VPC Endpoints

**Policy:**
- Leave as **Full access** (default)

**DNS options:**
- ✅ **Enable DNS name** (should be checked by default)
- ✅ **Enable private DNS only for inbound endpoint** (if available)

**Tags (Optional):**
- Key: `Project`, Value: `task-management`

### 1.3 Create Endpoint

1. Click **Create endpoint**
2. Wait for **Status: Available** (~2-3 minutes)
3. Note the Endpoint ID (e.g., `vpce-xxxxxxxxx`)

---

## Step 2: Create ECR API VPC Endpoint

### 2.1 Create New Endpoint

1. Click **Create endpoint** button again

### 2.2 Configure ECR API Endpoint

**Name and Service:**
- **Name tag:** `ecr-api-endpoint`
- **Service category:** AWS services
- **Services:** 
  - Search: `ecr.api`
  - Select: **com.amazonaws.us-east-1.ecr.api**
  - Type: **Interface**

**VPC:**
- **VPC:** `vpc-0792f2f110cb731ed`

**Subnets:**
- **us-east-1a:** `subnet-01578e4938893297d`
- **us-east-1b:** `subnet-0bbad45200c46c4e5`

**Security groups:**
- ✅ **task-mgmt-auth-sg** (for auth-service)
- ✅ **task-mgmt-task-sg** (for task-service)

**DNS options:**
- ✅ **Enable DNS name**

### 2.3 Create Endpoint

1. Click **Create endpoint**
2. Wait for **Status: Available**

---

## Step 3: Create ECR Docker VPC Endpoint

### 3.1 Create New Endpoint

1. Click **Create endpoint** button again

### 3.2 Configure ECR Docker Endpoint

**Name and Service:**
- **Name tag:** `ecr-dkr-endpoint`
- **Service category:** AWS services
- **Services:** 
  - Search: `ecr.dkr`
  - Select: **com.amazonaws.us-east-1.ecr.dkr**
  - Type: **Interface**

**VPC:**
- **VPC:** `vpc-0792f2f110cb731ed`

**Subnets:**
- **us-east-1a:** `subnet-01578e4938893297d`
- **us-east-1b:** `subnet-0bbad45200c46c4e5`

**Security groups:**
- ✅ **task-mgmt-auth-sg** (sg-0f19eb8f889b954d1)

**DNS options:**
- ✅ **Enable DNS name**

### 3.3 Create Endpoint

1. Click **Create endpoint**
2. Wait for **Status: Available**

---

## Step 4: Create S3 Gateway VPC Endpoint

### 4.1 Create New Endpoint

1. Click **Create endpoint** button again

### 4.2 Configure S3 Gateway Endpoint

**Name and Service:**
- **Name tag:** `s3-gateway-endpoint`
- **Service category:** AWS services
- **Services:** 
  - Search: `s3`
  - Select: **com.amazonaws.us-east-1.s3**
  - Type: **Gateway** (important!)

**VPC:**
- **VPC:** `vpc-0792f2f110cb731ed`

**Route tables:**
- You need to select the route table associated with your **private subnets**
- Look for the route table that has:
  - subnet-01578e4938893297d
  - subnet-0bbad45200c46c4e5
- Check ✅ that route table

**Policy:**
- Leave as **Full access** (default)

### 4.3 Create Endpoint

1. Click **Create endpoint**
2. **Status should be Available immediately** (Gateway endpoints are instant)

---

## Step 5: Create CloudWatch Logs VPC Endpoint

### 5.1 Create New Endpoint

1. Click **Create endpoint** button again

### 5.2 Configure CloudWatch Logs Endpoint

**Name and Service:**
- **Name tag:** `cloudwatch-logs-endpoint`
- **Service category:** AWS services
- **Services:** 
  - Search: `logs`
  - Select: **com.amazonaws.us-east-1.logs**
  - Type: **Interface**

**VPC:**
- **VPC:** `vpc-0792f2f110cb731ed`

**Subnets:**
- **us-east-1a:** `subnet-01578e4938893297d`
- **us-east-1b:** `subnet-0bbad45200c46c4e5`

**Security groups:**
- ✅ **task-mgmt-auth-sg** (sg-0f19eb8f889b954d1)

**DNS options:**
- ✅ **Enable DNS name**

### 5.3 Create Endpoint

1. Click **Create endpoint**
2. Wait for **Status: Available**

**Why this is needed:** Your ECS tasks send application logs to CloudWatch Logs. Without this endpoint, tasks in private subnets cannot reach CloudWatch and will fail with "failed to validate logger args" error.

---

## Step 6: Update Security Group Rules

The VPC endpoints need to allow HTTPS traffic from your ECS tasks.

### 6.1 Navigate to Security Groups

1. Go to **VPC** → **Security Groups**
2. You'll need to update BOTH ECS task security groups:
   - **task-mgmt-auth-sg** (for auth-service)
   - **task-mgmt-task-sg** (for task-service)

### 6.2 Add Inbound Rule for VPC Endpoints (Do this for EACH security group)

**For Auth Service Security Group:**
1. Find and click on **task-mgmt-auth-sg**
2. Click **Inbound rules** tab
3. Click **Edit inbound rules**
4. Click **Add rule**
5. Configure:
   - **Type:** HTTPS
   - **Protocol:** TCP
   - **Port range:** 443
   - **Source:** Custom
   - In the search box, select: **task-mgmt-auth-sg** - **itself**
   - **Description:** Allow HTTPS for VPC endpoints
6. Click **Save rules**

**For Task Service Security Group:**
1. Find and click on **task-mgmt-task-sg**
2. Click **Inbound rules** tab
3. Click **Edit inbound rules**
4. Click **Add rule**
5. Configure:
   - **Type:** HTTPS
   - **Protocol:** TCP
   - **Port range:** 443
   - **Source:** Custom
   - In the search box, select: **task-mgmt-task-sg** - **itself**
   - **Description:** Allow HTTPS for VPC endpoints
6. Click **Save rules**

**Why this is needed:** VPC endpoints are network interfaces in your subnets. Your ECS tasks need to communicate with these endpoints over HTTPS (port 443).

---

## Step 7: Verify All Endpoints

### 7.1 Check Endpoint Status

1. Go to **VPC** → **Endpoints**
2. Verify you see 5 endpoints:

| Endpoint Name | Service Name | Type | Status | Subnets |
|---------------|--------------|------|--------|---------|
| secrets-manager-endpoint | secretsmanager | Interface | Available | 2 subnets |
| ecr-api-endpoint | ecr.api | Interface | Available | 2 subnets |
| ecr-dkr-endpoint | ecr.dkr | Interface | Available | 2 subnets |
| cloudwatch-logs-endpoint | logs | Interface | Available | 2 subnets |
| s3-gateway-endpoint | s3 | Gateway | Available | Route table |

### 7.2 Verify Interface Endpoints

For each Interface endpoint (Secrets Manager, ECR API, ECR Docker, CloudWatch Logs):

1. Click on the endpoint
2. Verify:
   - **Status:** Available
   - **VPC:** vpc-0792f2f110cb731ed
   - **Subnets:** 2 subnets (one in each AZ)
   - **Security groups:** BOTH task-mgmt-auth-sg AND task-mgmt-task-sg
   - **DNS names:** Should show private DNS names

**⚠️ CRITICAL:** Each VPC Endpoint must have ALL ECS task security groups attached!

**Common Mistake:** If you only attach auth-sg when creating endpoints, task-service will fail to deploy later. You have two options:

**Option A: Add Both Security Groups Now (Recommended)**
- When creating each endpoint, select BOTH security groups:
  - task-mgmt-auth-sg
  - task-mgmt-task-sg
- This prevents issues when deploying task-service later

**Option B: Add Task-Service Security Group Later**
- If you only added auth-sg initially, you MUST add task-sg before deploying task-service
- Go to each endpoint → Actions → Manage security groups → Add task-mgmt-task-sg
- Without this, task-service deployment will fail with "unable to pull secrets" error

### 7.3 Verify Gateway Endpoint

For S3 Gateway endpoint:

1. Click on the endpoint
2. Verify:
   - **Status:** Available
   - **VPC:** vpc-0792f2f110cb731ed
   - **Route tables:** Shows your private subnet route table

---

## Step 8: Wait for Endpoints to Propagate

**Important:** Wait 2-3 minutes after all endpoints show "Available" status before retrying ECS service deployment.

This allows:
- DNS records to propagate
- Network interfaces to be fully configured
- Security group rules to take effect

---

## Step 9: Retry ECS Service Deployment

### 9.1 Delete Failed Service (if exists)

1. Go to **ECS** → **Clusters** → `task-management-cluster`
2. Click **Services** tab
3. If you see `auth-service` with failed status:
   - Select it
   - Click **Delete**
   - Confirm deletion
   - Wait for deletion to complete

### 9.2 Create Service Again

1. Follow **Task 7 Step 2** from the deployment guide
2. Create the auth-service with the same configuration:
   - Task definition: auth-service:1
   - Desired tasks: 2
   - Private subnets
   - Security group: task-mgmt-auth-sg
   - Service discovery enabled

### 9.3 Monitor Deployment

1. Watch the service creation
2. Check **Tasks** tab
3. Tasks should now:
   - Pull container image from ECR ✅
   - Retrieve secrets from Secrets Manager ✅
   - Send logs to CloudWatch Logs ✅
   - Start successfully ✅
   - Status: RUNNING ✅

---

## Troubleshooting

### Issue: Endpoints stuck in "Pending" status

**Solution:**
- Wait 5 minutes
- Check that subnets are correct (private subnets)
- Check that security group exists

### Issue: Tasks still failing after creating endpoints

**Possible causes:**

1. **Didn't wait long enough**
   - Wait 3-5 minutes after endpoints show "Available"

2. **Security group rule missing**
   - Verify task-mgmt-auth-sg allows inbound HTTPS (443) from itself

3. **Wrong subnets selected**
   - Verify endpoints are in PRIVATE subnets (not public)

4. **DNS not enabled**
   - Verify "Enable DNS name" is checked for Interface endpoints

### Issue: Cannot find route table for S3 Gateway endpoint

**Solution:**
1. Go to **VPC** → **Subnets**
2. Click on `subnet-01578e4938893297d`
3. Note the **Route table** ID
4. Use that route table when creating S3 Gateway endpoint

---

## Verification Checklist

Before retrying ECS deployment, verify:

- [ ] 5 VPC endpoints created (Secrets Manager, ECR API, ECR Docker, CloudWatch Logs, S3)
- [ ] All endpoints show Status: Available
- [ ] Interface endpoints (4) use both private subnets
- [ ] Interface endpoints use task-mgmt-auth-sg security group
- [ ] S3 Gateway endpoint uses private subnet route table
- [ ] Security group allows HTTPS (443) from itself
- [ ] Waited 2-3 minutes after endpoints became available
- [ ] Deleted failed ECS service (if it existed)

---

## Cost Breakdown

**VPC Endpoints Cost:**
- **Interface Endpoints:** $0.01 per hour per endpoint
  - 4 endpoints × $0.01/hour × 730 hours/month = **$29.20/month**
- **Gateway Endpoint (S3):** **Free**
- **Data transfer:** First 1 GB free, then $0.01 per GB

**Total estimated cost:** ~$29/month

**Savings vs NAT Gateway:** ~$6/month (NAT Gateway costs ~$35/month)

---

## Key Concepts Learned

### VPC Endpoints
- Allow private subnet resources to access AWS services
- No internet gateway or NAT Gateway needed
- Traffic stays within AWS network (more secure)

### Interface Endpoints
- Create network interfaces (ENIs) in your subnets
- Use private IP addresses
- Require security group rules
- Support DNS resolution

### Gateway Endpoints
- Route table entries (not network interfaces)
- Only for S3 and DynamoDB
- Free to use
- No security group needed

---

## Next Steps

Once all endpoints are created and verified:

1. ✅ Wait 2-3 minutes
2. ✅ Delete failed ECS service
3. ✅ Create ECS service again (Task 7 Step 2)
4. ✅ Verify tasks start successfully
5. ✅ Continue with Task 7 Step 3 (Verify Service Deployment)

---

## Summary

You have successfully:
- ✅ Created 5 VPC Endpoints for private subnet access
- ✅ Configured security groups for endpoint access
- ✅ Enabled your ECS tasks to access AWS services without NAT Gateway
- ✅ Saved ~$6/month compared to NAT Gateway
- ✅ Improved security (traffic stays in AWS network)

Your ECS tasks can now:
- Pull container images from ECR
- Retrieve secrets from Secrets Manager
- Access S3 for ECR image layers
- Send logs to CloudWatch Logs
- All without internet access!

