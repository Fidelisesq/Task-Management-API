# Troubleshooting ECS Deployment Issues

This guide documents common issues encountered when deploying ECS services and how to fix them.

## Issue 1: Unable to Pull Secrets - Network Connectivity

### Error Message:
```
ResourceInitializationError: unable to pull secrets or registry auth
There is a connection issue between the task and AWS Secrets Manager
context deadline exceeded
```

### Cause:
ECS tasks in private subnets cannot reach AWS Secrets Manager or ECR because they don't have internet access.

### Solution:
Configure network access using **one** of these options:

#### Option A: VPC Endpoints (Recommended - Lower Cost)

Create 5 VPC Endpoints:

1. **Secrets Manager Endpoint**
   ```bash
   aws ec2 create-vpc-endpoint \
     --region us-east-1 \
     --vpc-id vpc-0792f2f110cb731ed \
     --service-name com.amazonaws.us-east-1.secretsmanager \
     --vpc-endpoint-type Interface \
     --subnet-ids subnet-01578e4938893297d subnet-0bbad45200c46c4e5 \
     --security-group-ids sg-0f19eb8f889b954d1
   ```

2. **ECR API Endpoint**
   ```bash
   aws ec2 create-vpc-endpoint \
     --region us-east-1 \
     --vpc-id vpc-0792f2f110cb731ed \
     --service-name com.amazonaws.us-east-1.ecr.api \
     --vpc-endpoint-type Interface \
     --subnet-ids subnet-01578e4938893297d subnet-0bbad45200c46c4e5 \
     --security-group-ids sg-0f19eb8f889b954d1
   ```

3. **ECR Docker Endpoint**
   ```bash
   aws ec2 create-vpc-endpoint \
     --region us-east-1 \
     --vpc-id vpc-0792f2f110cb731ed \
     --service-name com.amazonaws.us-east-1.ecr.dkr \
     --vpc-endpoint-type Interface \
     --subnet-ids subnet-01578e4938893297d subnet-0bbad45200c46c4e5 \
     --security-group-ids sg-0f19eb8f889b954d1
   ```

4. **CloudWatch Logs Endpoint**
   ```bash
   aws ec2 create-vpc-endpoint \
     --region us-east-1 \
     --vpc-id vpc-0792f2f110cb731ed \
     --service-name com.amazonaws.us-east-1.logs \
     --vpc-endpoint-type Interface \
     --subnet-ids subnet-01578e4938893297d subnet-0bbad45200c46c4e5 \
     --security-group-ids sg-0f19eb8f889b954d1
   ```

5. **S3 Gateway Endpoint**
   ```bash
   aws ec2 create-vpc-endpoint \
     --region us-east-1 \
     --vpc-id vpc-0792f2f110cb731ed \
     --service-name com.amazonaws.us-east-1.s3 \
     --vpc-endpoint-type Gateway \
     --route-table-ids <PRIVATE_ROUTE_TABLE_ID>
   ```

**CRITICAL:** Add security group rule to allow HTTPS:
```bash
aws ec2 authorize-security-group-ingress \
  --region us-east-1 \
  --group-id sg-0f19eb8f889b954d1 \
  --protocol tcp \
  --port 443 \
  --source-group sg-0f19eb8f889b954d1
```

**ALSO CRITICAL:** Attach the security group to each VPC Endpoint:
```bash
# Via Console (Easier):
# 1. Go to VPC → Endpoints
# 2. Click on each Interface endpoint
# 3. Actions → Manage security groups
# 4. Check ALL ECS task security groups (auth-sg AND task-sg)
# 5. Save

# Via CLI:
aws ec2 modify-vpc-endpoint \
  --vpc-endpoint-id <ENDPOINT_ID> \
  --add-security-group-ids sg-0f19eb8f889b954d1 \
  --region us-east-1
```

**Note:** Both steps are required! The HTTPS rule alone is not enough - the security group must also be attached to the VPC Endpoints.

#### Option B: NAT Gateway

1. Ensure NAT Gateway exists in public subnet
2. Update private subnet route table:
   ```bash
   aws ec2 create-route \
     --region us-east-1 \
     --route-table-id <PRIVATE_ROUTE_TABLE_ID> \
     --destination-cidr-block 0.0.0.0/0 \
     --nat-gateway-id <NAT_GATEWAY_ID>
   ```

### Verification:
```bash
# Check VPC endpoints status
aws ec2 describe-vpc-endpoints \
  --region us-east-1 \
  --filters "Name=vpc-id,Values=vpc-0792f2f110cb731ed" \
  --query 'VpcEndpoints[*].[ServiceName,State]' \
  --output table

# Check security group has HTTPS rule
aws ec2 describe-security-groups \
  --region us-east-1 \
  --group-ids sg-0f19eb8f889b954d1 \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`443`]'
```

---

## Issue 2: Cannot Send Logs to CloudWatch

### Error Message:
```
ResourceInitializationError: failed to validate logger args
The task cannot find the Amazon CloudWatch log group defined in the task definition
There is a connection issue between the task and Amazon CloudWatch
signal: killed
```

### Cause:
ECS tasks in private subnets cannot reach CloudWatch Logs to send application logs.

### Solution:

Create CloudWatch Logs VPC Endpoint:

```bash
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-0792f2f110cb731ed \
  --vpc-endpoint-type Interface \
  --service-name com.amazonaws.us-east-1.logs \
  --subnet-ids subnet-01578e4938893297d subnet-0bbad45200c46c4e5 \
  --security-group-ids sg-0f19eb8f889b954d1 \
  --region us-east-1 \
  --tag-specifications 'ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=task-mgmt-cloudwatch-logs-endpoint}]'
```

**Note:** This endpoint is required in addition to the other 4 endpoints (Secrets Manager, ECR API, ECR Docker, S3).

### Verification:
```bash
# Check CloudWatch Logs endpoint status
aws ec2 describe-vpc-endpoints \
  --region us-east-1 \
  --filters "Name=vpc-id,Values=vpc-0792f2f110cb731ed" "Name=service-name,Values=com.amazonaws.us-east-1.logs" \
  --query 'VpcEndpoints[*].[VpcEndpointId,State,ServiceName]' \
  --output table
```

After creating the endpoint, force a new deployment:
```bash
aws ecs update-service \
  --cluster task-management-cluster \
  --service auth-service \
  --force-new-deployment \
  --region us-east-1
```

---

## Issue 3: Access Denied to Secrets Manager

### Error Message:
```
api error AccessDeniedException: User: arn:aws:sts::ACCOUNT:assumed-role/ecsTaskExecutionRole/...
is not authorized to perform: secretsmanager:GetSecretValue
because no identity-based policy allows the secretsmanager:GetSecretValue action
```

### Cause:
The `ecsTaskExecutionRole` is missing the `TaskManagementSecretsAccess` policy.

### Solution:

1. **Verify the policy exists:**
   ```bash
   aws iam get-policy \
     --policy-arn arn:aws:iam::211125602758:policy/TaskManagementSecretsAccess
   ```

2. **Attach the policy to the role:**
   ```bash
   aws iam attach-role-policy \
     --role-name ecsTaskExecutionRole \
     --policy-arn arn:aws:iam::211125602758:policy/TaskManagementSecretsAccess
   ```

3. **Verify it's attached:**
   ```bash
   aws iam list-attached-role-policies \
     --role-name ecsTaskExecutionRole \
     --output table
   ```

   You should see both:
   - `AmazonECSTaskExecutionRolePolicy`
   - `TaskManagementSecretsAccess`

### Verification:
```bash
# Check policy document
aws iam get-policy-version \
  --policy-arn arn:aws:iam::211125602758:policy/TaskManagementSecretsAccess \
  --version-id v1 \
  --query 'PolicyVersion.Document'
```

Expected policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": [
        "arn:aws:secretsmanager:us-east-1:*:secret:rds-credentials-*",
        "arn:aws:secretsmanager:us-east-1:*:secret:jwt-secret-*"
      ]
    }
  ]
}
```

---

## Issue 4: Cannot Pull Container Image from ECR

### Error Message:
```
CannotPullContainerError: Error response from daemon: pull access denied
```

### Cause:
The `ecsTaskExecutionRole` doesn't have ECR permissions.

### Solution:

Attach the AWS managed policy:
```bash
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

### Verification:
```bash
aws iam list-attached-role-policies \
  --role-name ecsTaskExecutionRole
```

---

## Issue 5: Database Connection Timeout

### Error Message (in CloudWatch Logs):
```
Error: connect ETIMEDOUT
Connection refused on port 5432
```

### Cause:
Security groups don't allow traffic between ECS tasks and RDS.

### Solution:

1. **Allow Auth Service → RDS:**
   ```bash
   aws ec2 authorize-security-group-ingress \
     --group-id <RDS_SG_ID> \
     --protocol tcp \
     --port 5432 \
     --source-group <AUTH_SG_ID>
   ```

2. **Allow Task Service → RDS:**
   ```bash
   aws ec2 authorize-security-group-ingress \
     --group-id <RDS_SG_ID> \
     --protocol tcp \
     --port 5432 \
     --source-group <TASK_SG_ID>
   ```

3. **Allow outbound from services:**
   ```bash
   aws ec2 authorize-security-group-egress \
     --group-id <AUTH_SG_ID> \
     --protocol tcp \
     --port 5432 \
     --source-group <RDS_SG_ID>
   ```

### Verification:
```bash
# Check RDS security group inbound rules
aws ec2 describe-security-groups \
  --group-ids <RDS_SG_ID> \
  --query 'SecurityGroups[0].IpPermissions'
```

---

## Issue 6: Service Discovery Not Working

### Error Message (in CloudWatch Logs):
```
Error: getaddrinfo ENOTFOUND auth-service.task-management.local
```

### Cause:
Service discovery not configured or VPC DNS settings disabled.

### Solution:

1. **Enable VPC DNS settings:**
   ```bash
   aws ec2 modify-vpc-attribute \
     --vpc-id vpc-0792f2f110cb731ed \
     --enable-dns-support

   aws ec2 modify-vpc-attribute \
     --vpc-id vpc-0792f2f110cb731ed \
     --enable-dns-hostnames
   ```

2. **Verify service discovery is enabled on the service:**
   - ECS Console → Service → Configuration
   - Check "Service discovery" section

### Verification:
```bash
# Check VPC DNS settings
aws ec2 describe-vpc-attribute \
  --vpc-id vpc-0792f2f110cb731ed \
  --attribute enableDnsSupport

aws ec2 describe-vpc-attribute \
  --vpc-id vpc-0792f2f110cb731ed \
  --attribute enableDnsHostnames

# Check Cloud Map service
aws servicediscovery list-services \
  --filters Name=NAMESPACE_ID,Values=<NAMESPACE_ID>
```

---

## General Troubleshooting Steps

### 1. Check ECS Service Events
```bash
aws ecs describe-services \
  --cluster task-management-cluster \
  --services auth-service \
  --query 'services[0].events[0:5]' \
  --output table
```

### 2. Check Task Status
```bash
aws ecs list-tasks \
  --cluster task-management-cluster \
  --service-name auth-service \
  --desired-status STOPPED
```

### 3. Check CloudWatch Logs
```bash
# List log streams
aws logs describe-log-streams \
  --log-group-name /ecs/auth-service \
  --order-by LastEventTime \
  --descending \
  --max-items 5

# Get log events
aws logs get-log-events \
  --log-group-name /ecs/auth-service \
  --log-stream-name <LOG_STREAM_NAME>
```

### 4. Force New Deployment
After fixing issues, force a new deployment:
```bash
aws ecs update-service \
  --cluster task-management-cluster \
  --service auth-service \
  --force-new-deployment
```

---

## Quick Diagnostic Script

Save this as `diagnose-ecs.sh`:

```bash
#!/bin/bash

CLUSTER="task-management-cluster"
SERVICE="auth-service"
REGION="us-east-1"

echo "=== ECS Service Status ==="
aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --region $REGION \
  --query 'services[0].[serviceName,status,runningCount,desiredCount]' \
  --output table

echo ""
echo "=== Recent Service Events ==="
aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --region $REGION \
  --query 'services[0].events[0:3]' \
  --output table

echo ""
echo "=== IAM Role Policies ==="
aws iam list-attached-role-policies \
  --role-name ecsTaskExecutionRole \
  --output table

echo ""
echo "=== VPC Endpoints ==="
aws ec2 describe-vpc-endpoints \
  --region $REGION \
  --filters "Name=vpc-id,Values=vpc-0792f2f110cb731ed" \
  --query 'VpcEndpoints[*].[ServiceName,State]' \
  --output table

echo ""
echo "=== Security Group HTTPS Rule ==="
aws ec2 describe-security-groups \
  --region $REGION \
  --group-ids sg-0f19eb8f889b954d1 \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`443`]'
```

Run with: `bash diagnose-ecs.sh`

---

## Summary of Required Configuration

For ECS services to work in private subnets, you need:

✅ **Network Access** (choose one):
- VPC Endpoints (Secrets Manager, ECR API, ECR Docker, CloudWatch Logs, S3) + HTTPS security group rule
- OR NAT Gateway with proper route table

✅ **IAM Permissions**:
- `ecsTaskExecutionRole` with `AmazonECSTaskExecutionRolePolicy`
- `ecsTaskExecutionRole` with `TaskManagementSecretsAccess`

✅ **Security Groups**:
- ECS tasks → VPC Endpoints (HTTPS/443)
- ECS tasks → RDS (PostgreSQL/5432)
- Task Service → Auth Service (HTTP/3000)

✅ **VPC DNS**:
- DNS Support: Enabled
- DNS Hostnames: Enabled

✅ **Service Discovery**:
- Cloud Map namespace created
- Service discovery enabled on ECS service

---

## Getting Help

If you're still stuck:

1. Check CloudWatch Logs for application errors
2. Review ECS service events for deployment issues
3. Verify all security group rules
4. Confirm IAM policies are attached
5. Ensure VPC endpoints are in "available" state
6. Wait 2-3 minutes after making changes before retrying

