# Task 6: ECS Cluster and Service Discovery Setup Guide

This guide provides step-by-step instructions for creating the ECS cluster, CloudWatch log groups, and AWS Cloud Map namespace for service discovery.

## Prerequisites

- AWS Console access
- Completed Tasks 1-5 (VPC, Security Groups, IAM Roles, Database, Container Images)
- Both container images pushed to ECR

## Overview

In this task, you will:
1. Create an ECS cluster using Fargate
2. Create CloudWatch log groups for both services
3. Set up AWS Cloud Map for service discovery
4. Verify all resources are created correctly

---

## Step 1: Create ECS Cluster

### 1.1 Navigate to ECS Console

1. Open the AWS Console
2. Search for **ECS** in the search bar
3. Click on **Elastic Container Service**
4. Make sure you're in the **us-east-1** region (check top-right corner)

### 1.2 Create Cluster

1. Click **Clusters** in the left sidebar
2. Click **Create cluster** button
3. Configure the cluster:

   **Cluster configuration:**
   - **Cluster name:** `task-management-cluster`
   - **Namespace:** Leave empty (we'll create this separately)

   **Infrastructure:**
   - Select **AWS Fargate (serverless)**
   - Do NOT select EC2 instances

   **Monitoring:**
   - Check ✅ **Use Container Insights**
   - This enables detailed monitoring and metrics

   **Tags (Optional but recommended):**
   - Key: `Project`, Value: `task-management`
   - Key: `Environment`, Value: `learning`

4. Click **Create**

### 1.3 Verify Cluster Creation

1. Wait for the cluster to be created (should take ~30 seconds)
2. You should see the cluster status as **Active**
3. Click on the cluster name to view details
4. Note down the cluster ARN for your records

**Expected Result:**
```
Cluster Name: task-management-cluster
Status: Active
Capacity providers: FARGATE, FARGATE_SPOT
```

---

## Step 2: Create CloudWatch Log Groups

CloudWatch log groups will store logs from your ECS tasks.

### 2.1 Navigate to CloudWatch Console

1. Open a new tab in AWS Console
2. Search for **CloudWatch** in the search bar
3. Click on **CloudWatch**
4. Click **Log groups** in the left sidebar (under Logs section)

### 2.2 Create Auth Service Log Group

1. Click **Create log group** button
2. Configure the log group:

   **Log group name:** `/ecs/auth-service`
   
   **Retention setting:** `30 days`
   
   **KMS key ARN:** Leave empty (default encryption)

   **Tags (Optional):**
   - Key: `Project`, Value: `task-management`
   - Key: `Service`, Value: `auth-service`

3. Click **Create log group**

### 2.3 Create Task Service Log Group

1. Click **Create log group** button again
2. Configure the log group:

   **Log group name:** `/ecs/task-service`
   
   **Retention setting:** `30 days`
   
   **KMS key ARN:** Leave empty (default encryption)

   **Tags (Optional):**
   - Key: `Project`, Value: `task-management`
   - Key: `Service`, Value: `task-service`

3. Click **Create log group**

### 2.4 Verify Log Groups

1. You should now see both log groups in the list:
   - `/ecs/auth-service` (Retention: 30 days)
   - `/ecs/task-service` (Retention: 30 days)

2. Click on each log group to verify:
   - Retention period is set to 30 days
   - No log streams yet (these will be created when tasks start)

**Expected Result:**
```
Log Group Name              Retention    Stored Bytes
/ecs/auth-service          30 days      0 B
/ecs/task-service          30 days      0 B
```

---

## Step 3: Create AWS Cloud Map Namespace (Service Discovery)

AWS Cloud Map enables service-to-service discovery using DNS.

### 3.1 Navigate to Cloud Map Console

1. Open a new tab in AWS Console
2. Search for **Cloud Map** in the search bar
3. Click on **AWS Cloud Map**
4. Click **Namespaces** in the left sidebar

### 3.2 Create Private DNS Namespace

1. Click **Create namespace** button
2. Configure the namespace:

   **Namespace type:**
   - Select **API calls and DNS queries in VPCs** (Private DNS namespace)

   **Namespace name:** `task-management.local`
   
   **Description (Optional):** `Private DNS namespace for Task Management API services`

   **VPC:**
   - Select your VPC: `vpc-0792f2f110cb731ed` (the one from Task 1)

   **Tags (Optional):**
   - Key: `Project`, Value: `task-management`

3. Click **Create namespace**

### 3.3 Verify Namespace Creation

1. Wait for the namespace to be created (~1-2 minutes)
2. You should see the namespace status as **Active**
3. Click on the namespace to view details
4. Note down:
   - **Namespace ID** (e.g., `ns-xxxxxxxxx`)
   - **Namespace ARN**
   - **Hosted zone ID** (this is created automatically in Route 53)

**Expected Result:**
```
Namespace name: task-management.local
Type: DNS private
VPC: vpc-0792f2f110cb731ed
Status: Active
```

### 3.4 Verify in Route 53 (Optional)

1. Navigate to **Route 53** console
2. Click **Hosted zones** in the left sidebar
3. You should see a new private hosted zone: `task-management.local`
4. This was automatically created by Cloud Map
5. Click on it to see it's associated with your VPC

---

## Step 4: Verification Checklist

Before proceeding to Task 7, verify all resources are created:

### ✅ ECS Cluster Verification

- [ ] Cluster name: `task-management-cluster`
- [ ] Status: Active
- [ ] Capacity providers: FARGATE, FARGATE_SPOT
- [ ] Container Insights: Enabled
- [ ] Running tasks: 0 (we haven't deployed services yet)

**How to verify:**
1. Go to ECS Console → Clusters
2. Click on `task-management-cluster`
3. Check the cluster details

### ✅ CloudWatch Log Groups Verification

- [ ] Log group `/ecs/auth-service` exists
- [ ] Log group `/ecs/task-service` exists
- [ ] Both have 30-day retention
- [ ] Both show 0 B stored (no logs yet)

**How to verify:**
1. Go to CloudWatch Console → Log groups
2. Search for `/ecs/`
3. Verify both log groups appear

### ✅ Cloud Map Namespace Verification

- [ ] Namespace `task-management.local` exists
- [ ] Type: DNS private
- [ ] Status: Active
- [ ] Associated with VPC: `vpc-0792f2f110cb731ed`
- [ ] Hosted zone created in Route 53

**How to verify:**
1. Go to Cloud Map Console → Namespaces
2. Click on `task-management.local`
3. Verify VPC association

### ✅ Route 53 Hosted Zone Verification

- [ ] Private hosted zone `task-management.local` exists
- [ ] Associated with VPC: `vpc-0792f2f110cb731ed`
- [ ] No records yet (will be created when services are deployed)

**How to verify:**
1. Go to Route 53 Console → Hosted zones
2. Find `task-management.local`
3. Verify VPC association

---

## Step 5: Document Resource IDs

Update your `docs/resource-inventory.md` file with the following information:

```markdown
## Task 6: ECS Cluster

### ECS Cluster

| Resource | Value |
|----------|-------|
| Cluster Name | task-management-cluster |
| Cluster ARN | [Your cluster ARN] |
| Launch Type | Fargate |
| Container Insights | Enabled |

### CloudWatch Log Groups

| Log Group | Retention |
|-----------|-----------|
| /ecs/auth-service | 30 days |
| /ecs/task-service | 30 days |

### Service Discovery

| Resource | Value |
|----------|-------|
| Namespace | task-management.local |
| Namespace ID | [Your namespace ID] |
| Type | Private DNS |
| VPC | vpc-0792f2f110cb731ed |
| Hosted Zone ID | [Your hosted zone ID] |
```

---

## Troubleshooting

### Issue: Cannot create ECS cluster

**Solution:**
- Verify you have the necessary IAM permissions
- Check you're in the correct region (us-east-1)
- Try refreshing the console and trying again

### Issue: Log groups already exist

**Solution:**
- If log groups already exist from previous attempts, you can either:
  - Delete them and recreate with correct settings
  - Or use the existing ones if they have the correct retention period

### Issue: Cloud Map namespace creation fails

**Solution:**
- Verify the VPC ID is correct
- Check that the namespace name doesn't already exist
- Ensure the VPC has DNS resolution and DNS hostnames enabled

### Issue: Cannot find Cloud Map in console

**Solution:**
- Search for "Cloud Map" or "Service Discovery" in the AWS Console search bar
- Make sure you're in the us-east-1 region

---

## Next Steps

Once you've completed all verification steps:

1. ✅ Mark Task 6 as complete
2. Update your resource inventory document
3. Proceed to **Task 7: Deploy Auth Service to ECS**

In Task 7, you will:
- Create a task definition for the Auth Service
- Configure environment variables from Secrets Manager
- Deploy the Auth Service with 2 tasks
- Register the service with Cloud Map for service discovery

---

## Key Concepts Learned

### ECS Cluster
- A logical grouping of tasks and services
- Fargate removes the need to manage EC2 instances
- Container Insights provides detailed monitoring

### CloudWatch Log Groups
- Centralized logging for all container output
- Retention policies control storage costs
- Essential for debugging and monitoring

### AWS Cloud Map (Service Discovery)
- Enables services to discover each other using DNS
- Private DNS namespace keeps traffic within VPC
- Automatically updates DNS when tasks start/stop
- Eliminates need for hardcoded IP addresses

### Service Discovery Benefits
- Task Service can call `auth-service.task-management.local:3000`
- DNS automatically resolves to healthy Auth Service tasks
- Load balancing across multiple task instances
- Automatic updates when tasks scale up/down

---

## Cost Considerations

**ECS Cluster:** Free (you only pay for running tasks)

**CloudWatch Logs:** 
- First 5 GB per month: Free
- After that: $0.50 per GB ingested
- Storage: $0.03 per GB per month

**Cloud Map:**
- Namespace: Free
- Service discovery queries: $0.0000001 per query (essentially free for this project)

**Estimated monthly cost for this task:** ~$1-2 (mostly CloudWatch logs)

---

## Summary

You have successfully:
- ✅ Created an ECS cluster with Fargate and Container Insights
- ✅ Set up CloudWatch log groups for both services
- ✅ Created a private DNS namespace for service discovery
- ✅ Verified all resources are active and properly configured

Your infrastructure is now ready to deploy containerized services!

