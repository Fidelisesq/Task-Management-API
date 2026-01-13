# Task 10: Application Load Balancer Configuration

## Overview

This guide walks you through creating an Application Load Balancer (ALB) to expose your ECS services to the internet. The ALB will route traffic to your auth-service and task-service based on URL paths.

## Prerequisites

- Completed Tasks 1-9
- Both services (auth-service and task-service) running with 2 tasks each
- VPC with public subnets
- Security groups created in Task 1

## Architecture

```
Internet
    ↓
Application Load Balancer (Public Subnets)
    ↓
    ├─> /auth/*  → Auth Service Target Group → Auth Service Tasks (Private Subnets)
    └─> /tasks/* → Task Service Target Group → Task Service Tasks (Private Subnets)
```

---

## Step 1: Create Target Groups

Target groups define where the ALB should route traffic. We need two target groups - one for each service.

### 1.1 Create Auth Service Target Group

**Via AWS Console:**

1. Go to **EC2 Console** → **Target Groups** (left sidebar)
2. Click **Create target group**
3. Configure:
   - **Target type**: IP addresses
   - **Target group name**: `auth-service-tg`
   - **Protocol**: HTTP
   - **Port**: 3000
   - **VPC**: Select your VPC (vpc-0792f2f110cb731ed)
   - **Protocol version**: HTTP1

4. **Health checks**:
   - **Health check protocol**: HTTP
   - **Health check path**: `/auth/health`
   - **Advanced health check settings**:
     - **Healthy threshold**: 2
     - **Unhealthy threshold**: 3
     - **Timeout**: 5 seconds
     - **Interval**: 30 seconds
     - **Success codes**: 200

5. Click **Next**
6. **Don't register any targets yet** (ECS will do this automatically)
7. Click **Create target group**

**Via AWS CLI:**

```bash
# Create auth-service target group
aws elbv2 create-target-group \
  --name auth-service-tg \
  --protocol HTTP \
  --port 3000 \
  --vpc-id vpc-0792f2f110cb731ed \
  --target-type ip \
  --health-check-enabled \
  --health-check-protocol HTTP \
  --health-check-path /auth/health \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --matcher HttpCode=200 \
  --region us-east-1

# Save the target group ARN
AUTH_TG_ARN=$(aws elbv2 describe-target-groups \
  --names auth-service-tg \
  --region us-east-1 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

echo "Auth Target Group ARN: $AUTH_TG_ARN"
```

### 1.2 Create Task Service Target Group

**Via AWS Console:**

1. Click **Create target group** again
2. Configure:
   - **Target type**: IP addresses
   - **Target group name**: `task-service-tg`
   - **Protocol**: HTTP
   - **Port**: 3000
   - **VPC**: Select your VPC (vpc-0792f2f110cb731ed)
   - **Protocol version**: HTTP1

3. **Health checks**:
   - **Health check protocol**: HTTP
   - **Health check path**: `/tasks/health`
   - **Advanced health check settings**:
     - **Healthy threshold**: 2
     - **Unhealthy threshold**: 3
     - **Timeout**: 5 seconds
     - **Interval**: 30 seconds
     - **Success codes**: 200

4. Click **Next**
5. **Don't register any targets yet**
6. Click **Create target group**

**Via AWS CLI:**

```bash
# Create task-service target group
aws elbv2 create-target-group \
  --name task-service-tg \
  --protocol HTTP \
  --port 3000 \
  --vpc-id vpc-0792f2f110cb731ed \
  --target-type ip \
  --health-check-enabled \
  --health-check-protocol HTTP \
  --health-check-path /tasks/health \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --matcher HttpCode=200 \
  --region us-east-1

# Save the target group ARN
TASK_TG_ARN=$(aws elbv2 describe-target-groups \
  --names task-service-tg \
  --region us-east-1 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

echo "Task Target Group ARN: $TASK_TG_ARN"
```

### 1.3 Verify Target Groups

```bash
# List target groups
aws elbv2 describe-target-groups \
  --region us-east-1 \
  --query 'TargetGroups[?contains(TargetGroupName, `service`)].{Name:TargetGroupName,Port:Port,HealthCheckPath:HealthCheckPath}' \
  --output table
```

Expected output:
```
---------------------------------------------------------
|              DescribeTargetGroups                     |
+------------------+------+----------------------------+
|  HealthCheckPath | Port |           Name             |
+------------------+------+----------------------------+
|  /auth/health    |  3000|  auth-service-tg           |
|  /tasks/health   |  3000|  task-service-tg           |
+------------------+------+----------------------------+
```

---

## Step 2: Create Application Load Balancer

### 2.1 Get Public Subnet IDs

```bash
# Get public subnet IDs
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-0792f2f110cb731ed" "Name=tag:Name,Values=*public*" \
  --region us-east-1 \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]' \
  --output table
```

Note down the two public subnet IDs (one in each AZ).

### 2.2 Get ALB Security Group ID

```bash
# Get ALB security group ID
ALB_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=task-mgmt-alb-sg" \
  --region us-east-1 \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

echo "ALB Security Group: $ALB_SG_ID"
```

### 2.3 Create ALB

**Via AWS Console:**

1. Go to **EC2 Console** → **Load Balancers** (left sidebar)
2. Click **Create Load Balancer**
3. Select **Application Load Balancer** → Click **Create**

4. **Basic Configuration**:
   - **Load balancer name**: `task-management-alb`
   - **Scheme**: Internet-facing
   - **IP address type**: IPv4

5. **Network mapping**:
   - **VPC**: Select your VPC (vpc-0792f2f110cb731ed)
   - **Mappings**: Select **both public subnets** (one in each AZ)
     - us-east-1a: subnet-XXXXXXXX
     - us-east-1b: subnet-XXXXXXXX

6. **Security groups**:
   - Remove default security group
   - Select **task-mgmt-alb-sg** (the ALB security group from Task 1)

7. **Listeners and routing**:
   - **Protocol**: HTTP
   - **Port**: 80
   - **Default action**: Select `auth-service-tg` (we'll add routing rules later)

8. Click **Create load balancer**

9. Wait for ALB to become **Active** (~2-3 minutes)

**Via AWS CLI:**

```bash
# Get public subnet IDs
PUBLIC_SUBNET_1=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-0792f2f110cb731ed" "Name=availability-zone,Values=us-east-1a" "Name=tag:Name,Values=*public*" \
  --region us-east-1 \
  --query 'Subnets[0].SubnetId' \
  --output text)

PUBLIC_SUBNET_2=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-0792f2f110cb731ed" "Name=availability-zone,Values=us-east-1b" "Name=tag:Name,Values=*public*" \
  --region us-east-1 \
  --query 'Subnets[0].SubnetId' \
  --output text)

echo "Public Subnets: $PUBLIC_SUBNET_1, $PUBLIC_SUBNET_2"

# Create ALB
aws elbv2 create-load-balancer \
  --name task-management-alb \
  --subnets $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 \
  --security-groups $ALB_SG_ID \
  --scheme internet-facing \
  --type application \
  --ip-address-type ipv4 \
  --region us-east-1

# Get ALB ARN
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names task-management-alb \
  --region us-east-1 \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

echo "ALB ARN: $ALB_ARN"

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names task-management-alb \
  --region us-east-1 \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo "ALB DNS Name: $ALB_DNS"
```

### 2.4 Wait for ALB to be Active

```bash
# Wait for ALB to be active
aws elbv2 wait load-balancer-available \
  --load-balancer-arns $ALB_ARN \
  --region us-east-1

echo "ALB is now active!"
```

---

## Step 3: Configure Listener Rules

Now we need to configure routing rules so the ALB knows where to send traffic based on the URL path.

### 3.1 Get Listener ARN

```bash
# Get listener ARN
LISTENER_ARN=$(aws elbv2 describe-listeners \
  --load-balancer-arn $ALB_ARN \
  --region us-east-1 \
  --query 'Listeners[0].ListenerArn' \
  --output text)

echo "Listener ARN: $LISTENER_ARN"
```

### 3.2 Create Routing Rules

**Via AWS Console:**

1. Go to **EC2 Console** → **Load Balancers**
2. Select **task-management-alb**
3. Go to **Listeners** tab
4. Click on **HTTP:80** listener
5. Click **Manage rules**

6. **Add rule for /auth/***:
   - Click **Insert Rule** (+ icon at top)
   - **Add condition**: Path is `/auth/*`
   - **Add action**: Forward to `auth-service-tg`
   - **Priority**: 1
   - Click **Save**

7. **Add rule for /tasks/***:
   - Click **Insert Rule** again
   - **Add condition**: Path is `/tasks/*`
   - **Add action**: Forward to `task-service-tg`
   - **Priority**: 2
   - Click **Save**

8. **Update default rule** (optional):
   - Select the default rule (last one)
   - Change action to: Return fixed response
   - Response code: 404
   - Content-Type: text/plain
   - Response body: "Not Found"
   - Click **Update**

**Via AWS CLI:**

```bash
# Create rule for /auth/*
aws elbv2 create-rule \
  --listener-arn $LISTENER_ARN \
  --priority 1 \
  --conditions Field=path-pattern,Values='/auth/*' \
  --actions Type=forward,TargetGroupArn=$AUTH_TG_ARN \
  --region us-east-1

# Create rule for /tasks/*
aws elbv2 create-rule \
  --listener-arn $LISTENER_ARN \
  --priority 2 \
  --conditions Field=path-pattern,Values='/tasks/*' \
  --actions Type=forward,TargetGroupArn=$TASK_TG_ARN \
  --region us-east-1

echo "Routing rules created!"
```

### 3.3 Verify Rules

```bash
# List listener rules
aws elbv2 describe-rules \
  --listener-arn $LISTENER_ARN \
  --region us-east-1 \
  --query 'Rules[*].{Priority:Priority,PathPattern:Conditions[0].Values[0],TargetGroup:Actions[0].TargetGroupArn}' \
  --output table
```

Expected output:
```
----------------------------------------------------------------------------------
|                                DescribeRules                                   |
+----------------+------------------+--------------------------------------------+
|  PathPattern   |    Priority      |              TargetGroup                   |
+----------------+------------------+--------------------------------------------+
|  /auth/*       |  1               |  arn:aws:elasticloadbalancing:...auth-...  |
|  /tasks/*      |  2               |  arn:aws:elasticloadbalancing:...task-...  |
|  None          |  default         |  arn:aws:elasticloadbalancing:...auth-...  |
+----------------+------------------+--------------------------------------------+
```

---

## Step 4: Update ECS Services to Register with Target Groups

Now we need to tell ECS to register the tasks with the ALB target groups.

### 4.1 Update Auth Service

**Via AWS Console:**

1. Go to **ECS Console** → **Clusters** → **task-management-cluster**
2. Click on **auth-service**
3. Click **Update**
4. Scroll to **Load balancing**
5. **Load balancer type**: Application Load Balancer
6. **Load balancer name**: task-management-alb
7. **Container to load balance**: 
   - **Container name**: auth-service:3000
   - Click **Add to load balancer**
8. **Production listener port**: 80:HTTP
9. **Target group name**: auth-service-tg
10. Click **Update**

**Via AWS CLI:**

```bash
# Update auth-service to use target group
aws ecs update-service \
  --cluster task-management-cluster \
  --service auth-service \
  --load-balancers targetGroupArn=$AUTH_TG_ARN,containerName=auth-service,containerPort=3000 \
  --region us-east-1

echo "Auth service updated with target group"
```

### 4.2 Update Task Service

**Via AWS Console:**

1. Go to **ECS Console** → **Clusters** → **task-management-cluster**
2. Click on **task-service**
3. Click **Update**
4. Scroll to **Load balancing**
5. **Load balancer type**: Application Load Balancer
6. **Load balancer name**: task-management-alb
7. **Container to load balance**:
   - **Container name**: task-service:3000
   - Click **Add to load balancer**
8. **Production listener port**: 80:HTTP
9. **Target group name**: task-service-tg
10. Click **Update**

**Via AWS CLI:**

```bash
# Update task-service to use target group
aws ecs update-service \
  --cluster task-management-cluster \
  --service task-service \
  --load-balancers targetGroupArn=$TASK_TG_ARN,containerName=task-service,containerPort=3000 \
  --region us-east-1

echo "Task service updated with target group"
```

### 4.3 Wait for Services to Stabilize

```bash
# Wait for services to stabilize (~5 minutes)
aws ecs wait services-stable \
  --cluster task-management-cluster \
  --services auth-service task-service \
  --region us-east-1

echo "Services are stable!"
```

---

## Step 5: Verify Target Health

### 5.1 Check Target Group Health

```bash
# Check auth-service targets
aws elbv2 describe-target-health \
  --target-group-arn $AUTH_TG_ARN \
  --region us-east-1 \
  --query 'TargetHealthDescriptions[*].{Target:Target.Id,Port:Target.Port,Health:TargetHealth.State}' \
  --output table

# Check task-service targets
aws elbv2 describe-target-health \
  --target-group-arn $TASK_TG_ARN \
  --region us-east-1 \
  --query 'TargetHealthDescriptions[*].{Target:Target.Id,Port:Target.Port,Health:TargetHealth.State}' \
  --output table
```

Expected output for each:
```
-----------------------------------------------
|         DescribeTargetHealth                |
+----------------+------+---------------------+
|     Health     | Port |       Target        |
+----------------+------+---------------------+
|  healthy       |  3000|  10.0.xxx.xxx       |
|  healthy       |  3000|  10.0.xxx.xxx       |
+----------------+------+---------------------+
```

**Note**: It may take 2-3 minutes for targets to become healthy. If they show "initial" or "unhealthy", wait a bit and check again.

### 5.2 Troubleshoot Unhealthy Targets

If targets remain unhealthy:

```bash
# Check target health details
aws elbv2 describe-target-health \
  --target-group-arn $AUTH_TG_ARN \
  --region us-east-1 \
  --query 'TargetHealthDescriptions[*].{Target:Target.Id,Health:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}' \
  --output table
```

Common issues:
- **Connection timeout**: Security group not allowing traffic from ALB
- **Health check failed**: Health endpoint not responding correctly
- **Target not registered**: ECS service not updated correctly

---

## Step 6: Test ALB Endpoints

### 6.1 Get ALB DNS Name

```bash
# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names task-management-alb \
  --region us-east-1 \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo "ALB DNS: $ALB_DNS"
echo "Test URLs:"
echo "  Auth Health: http://$ALB_DNS/auth/health"
echo "  Task Health: http://$ALB_DNS/tasks/health"
```

### 6.2 Test Health Endpoints

```bash
# Test auth-service health
curl http://$ALB_DNS/auth/health

# Expected: {"status":"healthy","service":"auth-service"}

# Test task-service health
curl http://$ALB_DNS/tasks/health

# Expected: {"status":"healthy","service":"task-service"}
```

### 6.3 Test Complete Flow

```bash
# Register a user
curl -X POST http://$ALB_DNS/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"albtestuser","email":"albtest@example.com","password":"Test123!@#"}'

# Expected: {"message":"User registered successfully","user":{...}}

# Login
TOKEN=$(curl -s -X POST http://$ALB_DNS/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"albtestuser","password":"Test123!@#"}' | grep -o '"token":"[^"]*' | cut -d'"' -f4)

echo "Token: $TOKEN"

# Create a task
curl -X POST http://$ALB_DNS/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title":"Test via ALB","description":"Testing ALB routing","priority":"high"}'

# Expected: {"message":"Task created successfully","task":{...}}

# Get all tasks
curl -X GET http://$ALB_DNS/tasks \
  -H "Authorization: Bearer $TOKEN"

# Expected: {"tasks":[...],"count":1}
```

---

## Step 7: Update Security Groups (If Needed)

### 7.1 Verify ALB Security Group

The ALB security group should allow:
- **Inbound**: HTTP (80) from 0.0.0.0/0
- **Outbound**: All traffic to 0.0.0.0/0

```bash
# Check ALB security group rules
aws ec2 describe-security-groups \
  --group-ids $ALB_SG_ID \
  --region us-east-1 \
  --query 'SecurityGroups[0].{Ingress:IpPermissions,Egress:IpPermissionsEgress}' \
  --output json
```

### 7.2 Verify ECS Task Security Groups

Both auth-service and task-service security groups should allow:
- **Inbound**: HTTP (3000) from ALB security group
- **Outbound**: All traffic

```bash
# Get auth-service security group
AUTH_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=task-mgmt-auth-sg" \
  --region us-east-1 \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

# Check if ALB can reach auth-service
aws ec2 describe-security-groups \
  --group-ids $AUTH_SG_ID \
  --region us-east-1 \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`3000`]' \
  --output json
```

If the rule is missing, add it:

```bash
# Add rule to allow ALB to reach auth-service
aws ec2 authorize-security-group-ingress \
  --group-id $AUTH_SG_ID \
  --protocol tcp \
  --port 3000 \
  --source-group $ALB_SG_ID \
  --region us-east-1

# Repeat for task-service security group
TASK_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=task-mgmt-task-sg" \
  --region us-east-1 \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $TASK_SG_ID \
  --protocol tcp \
  --port 3000 \
  --source-group $ALB_SG_ID \
  --region us-east-1
```

---

## Step 8: Document ALB Information

### 8.1 Save ALB Details

```bash
# Get all ALB information
echo "=== ALB Configuration ==="
echo "ALB Name: task-management-alb"
echo "ALB DNS: $ALB_DNS"
echo "ALB ARN: $ALB_ARN"
echo ""
echo "=== Target Groups ==="
echo "Auth TG ARN: $AUTH_TG_ARN"
echo "Task TG ARN: $TASK_TG_ARN"
echo ""
echo "=== Test URLs ==="
echo "Auth Health: http://$ALB_DNS/auth/health"
echo "Task Health: http://$ALB_DNS/tasks/health"
echo "Register: http://$ALB_DNS/auth/register"
echo "Login: http://$ALB_DNS/auth/login"
echo "Tasks: http://$ALB_DNS/tasks"
```

### 8.2 Update Resource Inventory

Add this information to `docs/resource-inventory.md`:

```markdown
## Application Load Balancer

- **Name**: task-management-alb
- **DNS Name**: [YOUR-ALB-DNS].us-east-1.elb.amazonaws.com
- **ARN**: arn:aws:elasticloadbalancing:us-east-1:211125602758:loadbalancer/app/task-management-alb/...
- **Scheme**: Internet-facing
- **Subnets**: Public subnets in us-east-1a and us-east-1b
- **Security Group**: task-mgmt-alb-sg

## Target Groups

### Auth Service Target Group
- **Name**: auth-service-tg
- **Port**: 3000
- **Health Check**: /auth/health
- **ARN**: arn:aws:elasticloadbalancing:us-east-1:211125602758:targetgroup/auth-service-tg/...

### Task Service Target Group
- **Name**: task-service-tg
- **Port**: 3000
- **Health Check**: /tasks/health
- **ARN**: arn:aws:elasticloadbalancing:us-east-1:211125602758:targetgroup/task-service-tg/...
```

---

## Troubleshooting

### Issue: Targets Not Registering

**Symptom**: Target groups show 0 registered targets

**Solution**:
1. Verify ECS services were updated with load balancer configuration
2. Check that services are running
3. Force new deployment:
   ```bash
   aws ecs update-service --cluster task-management-cluster --service auth-service --force-new-deployment --region us-east-1
   ```

### Issue: Targets Unhealthy

**Symptom**: Targets show "unhealthy" status

**Solution**:
1. Check health endpoint is responding:
   ```bash
   # Get task IP
   TASK_IP=$(aws ecs describe-tasks --cluster task-management-cluster --tasks $(aws ecs list-tasks --cluster task-management-cluster --service-name auth-service --region us-east-1 --query 'taskArns[0]' --output text) --region us-east-1 --query 'tasks[0].containers[0].networkInterfaces[0].privateIpv4Address' --output text)
   
   # Test directly
   curl http://$TASK_IP:3000/auth/health
   ```

2. Check security groups allow ALB → ECS traffic
3. Check CloudWatch logs for errors

### Issue: 503 Service Unavailable

**Symptom**: ALB returns 503 error

**Solution**:
1. Check target health (all targets must be healthy)
2. Verify routing rules are configured correctly
3. Check ECS tasks are running

### Issue: 404 Not Found

**Symptom**: ALB returns 404 for valid paths

**Solution**:
1. Verify routing rules include correct path patterns
2. Check rule priorities (lower number = higher priority)
3. Ensure paths include trailing `/*` (e.g., `/auth/*` not `/auth`)

### Issue: Connection Timeout

**Symptom**: Requests timeout

**Solution**:
1. Verify ALB security group allows inbound HTTP (80) from 0.0.0.0/0
2. Check ALB is in public subnets
3. Verify Internet Gateway is attached to VPC

---

## Cost Breakdown

### ALB Costs
- **ALB Hour**: $0.0225/hour = ~$16.20/month
- **LCU (Load Balancer Capacity Units)**: $0.008/LCU-hour
  - New connections: 25/second
  - Active connections: 3,000/minute
  - Processed bytes: 1GB/hour
  - Rule evaluations: 1,000/second
- **Estimated LCU cost**: ~$5-10/month (low traffic)

### Total Estimated Cost
- **ALB**: ~$16-26/month
- **Target Groups**: Free
- **Health Checks**: Included

---

## Verification Checklist

- [ ] Two target groups created (auth-service-tg, task-service-tg)
- [ ] Health checks configured correctly
- [ ] ALB created in public subnets
- [ ] ALB security group allows HTTP from internet
- [ ] Listener rules configured for /auth/* and /tasks/*
- [ ] ECS services updated with target groups
- [ ] All targets showing "healthy" status
- [ ] Health endpoints accessible via ALB
- [ ] Complete auth flow works via ALB
- [ ] Complete task CRUD works via ALB
- [ ] ALB DNS name documented

---

## Next Steps

After completing Task 10:

1. **Task 11**: Configure Auto Scaling
2. **Task 12**: Set up CloudWatch Monitoring and Alarms
3. **Task 21**: Deploy Frontend to S3/CloudFront (using ALB DNS)

---

## Resources

- [ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [Target Groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)
- [Health Checks](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html)
- [Listener Rules](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-update-rules.html)

