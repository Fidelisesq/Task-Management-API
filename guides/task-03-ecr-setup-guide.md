# Task 3: Container Registry Setup (ECR) - Manual Guide

This guide walks you through creating Amazon ECR repositories for your Auth Service and Task Service containers.

---

## Overview

You'll create two private ECR repositories to store Docker images for:
1. **auth-service** - Authentication and JWT token management
2. **task-service** - Task CRUD operations

**Estimated Time**: 10-15 minutes

---

## Step 1: Create Auth Service Repository

### AWS Console Steps:

1. Go to **Amazon ECR Console** → **Repositories** → **Create repository**

2. **General settings**:
   - **Visibility settings**: Select **Private**
   - **Repository name**: `auth-service`
   - **Tag immutability**: Leave **Disabled** (for learning flexibility)

3. **Image scan settings**:
   - ✅ Check **Scan on push**
   - This automatically scans images for vulnerabilities when pushed

4. **Encryption settings**:
   - Select **AES-256** (default)
   - This encrypts images at rest

5. Click **Create repository**

### Verify Creation:

- Repository should appear in the list
- Status: Active
- Note the **URI**: `<account-id>.dkr.ecr.us-east-1.amazonaws.com/auth-service`

### Document the URI:

Copy the repository URI and add it to `docs/resource-inventory.md`:

```
Repository Name: auth-service
URI: <account-id>.dkr.ecr.us-east-1.amazonaws.com/auth-service
```

---

## Step 2: Create Task Service Repository

Repeat the same process for the task service:

1. **ECR Console** → **Repositories** → **Create repository**

2. **General settings**:
   - **Visibility settings**: Private
   - **Repository name**: `task-service`
   - **Tag immutability**: Disabled

3. **Image scan settings**:
   - ✅ Check **Scan on push**

4. **Encryption settings**:
   - AES-256 (default)

5. Click **Create repository**

### Document the URI:

```
Repository Name: task-service
URI: <account-id>.dkr.ecr.us-east-1.amazonaws.com/task-service
```

---

## Step 3: Configure Lifecycle Policies

Lifecycle policies automatically delete old images to save storage costs.

### For Auth Service Repository:

1. Go to **ECR Console** → **Repositories** → Click **auth-service**

2. Click **Lifecycle Policy** tab → **Create rule**

3. **Rule priority**: `1`

4. **Rule description**: `Keep last 10 images`

5. **Image status**: Select **Any**

6. **Match criteria**:
   - Select **Image count more than**
   - Enter: `10`

7. Click **Save**

### For Task Service Repository:

Repeat the same steps for `task-service`:

1. Click **task-service** repository
2. **Lifecycle Policy** tab → **Create rule**
3. **Rule priority**: `1`
4. **Rule description**: `Keep last 10 images`
5. **Image status**: Any
6. **Match criteria**: Image count more than `10`
7. **Save**

---

## Step 4: Test Repository Access (Optional)

You can test that your repositories are accessible:

### Get Login Command:

```bash
# Get Docker login command
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
```

This command authenticates Docker to your ECR registry. You'll use this later when pushing images.

---

## Alternative: AWS CLI Method (Faster)

If you prefer CLI, you can create both repositories quickly:

```bash
# Create auth-service repository
aws ecr create-repository \
  --repository-name auth-service \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256 \
  --region us-east-1

# Create task-service repository
aws ecr create-repository \
  --repository-name task-service \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256 \
  --region us-east-1

# Create lifecycle policy for auth-service
aws ecr put-lifecycle-policy \
  --repository-name auth-service \
  --lifecycle-policy-text '{
    "rules": [{
      "rulePriority": 1,
      "description": "Keep last 10 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    }]
  }' \
  --region us-east-1

# Create lifecycle policy for task-service
aws ecr put-lifecycle-policy \
  --repository-name task-service \
  --lifecycle-policy-text '{
    "rules": [{
      "rulePriority": 1,
      "description": "Keep last 10 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    }]
  }' \
  --region us-east-1

# Get repository URIs
aws ecr describe-repositories \
  --repository-names auth-service task-service \
  --region us-east-1 \
  --query 'repositories[*].[repositoryName,repositoryUri]' \
  --output table
```

---

## Verification Checklist

Before moving to Task 4, verify:

- [ ] `auth-service` repository created
- [ ] `task-service` repository created
- [ ] Both repositories have **Scan on push** enabled
- [ ] Both repositories have lifecycle policy (keep last 10 images)
- [ ] Repository URIs documented in `docs/resource-inventory.md`
- [ ] Both repositories show status: **Active**

---

## Understanding ECR Components

### Repository URI Format:
```
<account-id>.dkr.ecr.<region>.amazonaws.com/<repository-name>
```

Example:
```
211125602758.dkr.ecr.us-east-1.amazonaws.com/auth-service
```

### Image Tag Format:
```
<repository-uri>:<tag>
```

Example:
```
211125602758.dkr.ecr.us-east-1.amazonaws.com/auth-service:v1.0.0
```

You'll use these URIs in Tasks 4 and 5 when building and pushing Docker images.

---

## Cost Information

**ECR Pricing**:
- **Storage**: $0.10 per GB per month
- **Data transfer**: First 1 GB free, then $0.09 per GB
- **Estimated cost**: ~$1-2/month for this project (very small images)

With lifecycle policies keeping only 10 images, storage costs stay minimal.

---

## Troubleshooting

### Can't see repositories?

**Check region**: Make sure you're in **us-east-1** region in the console

### Permission denied when creating repository?

**Check IAM permissions**: Your user needs `ecr:CreateRepository` permission

### Scan on push not working?

**Wait a few minutes**: Scans start automatically after the first image is pushed (in Task 4)

---

## Next Steps

Once both repositories are created and verified, you're ready for:

**Task 4: Build and Push Auth Service Container**

This involves:
- Creating the Auth Service application code (Node.js/Express)
- Writing a Dockerfile
- Building the Docker image
- Pushing to ECR

Great progress! 🎉

---

## Quick Reference

### Useful ECR Commands:

```bash
# List repositories
aws ecr describe-repositories --region us-east-1

# Get login command
aws ecr get-login-password --region us-east-1

# List images in a repository
aws ecr list-images --repository-name auth-service --region us-east-1

# Delete a repository (careful!)
aws ecr delete-repository --repository-name auth-service --force --region us-east-1
```

---

## Summary

You've created:
- ✅ Two private ECR repositories
- ✅ Enabled vulnerability scanning
- ✅ Configured automatic cleanup (lifecycle policies)
- ✅ Documented repository URIs

Ready to build Docker images! 🚀
