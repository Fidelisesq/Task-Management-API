# Quick Setup Guide

This guide will help you deploy the Task Management API infrastructure using Terraform and GitHub Actions.

## Prerequisites Checklist

- ✅ AWS Account ID: `211125602758`
- ✅ S3 Bucket for Terraform state: `foz-terraform-state-bucket`
- ✅ Route 53 Hosted Zone: `Z053615514X9UZZVP030H` (fozdigitalz.com)
- ✅ ACM Certificate: `arn:aws:acm:us-east-1:211125602758:certificate/697cf89b-9931-435f-a5f0-c8fd98a6ecdc`
- ✅ GitHub OIDC Role: `github-platform-actions-oidc`
- ✅ VPC ID: `vpc-0792f2f110cb731ed`
- ✅ Private Subnets: `subnet-01578e4938893297d`, `subnet-0bbad45200c46c4e5`

## Step 1: Create DynamoDB Table for State Locking

```bash
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

## Step 2: Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions → New repository secret

Add these secrets:

| Secret Name | Value |
|-------------|-------|
| `AWS_ACCOUNT_ID` | `211125602758` |
| `DOMAIN_NAME` | `fozdigitalz.com` |
| `ACM_CERTIFICATE_ARN` | `arn:aws:acm:us-east-1:211125602758:certificate/697cf89b-9931-435f-a5f0-c8fd98a6ecdc` |
| `DB_PASSWORD` | Your secure database password |
| `JWT_SECRET` | Your secure JWT secret key |
| `S3_BUCKET_NAME` | `task-management-frontend-1767876018` |
| `CLOUDFRONT_DISTRIBUTION_ID` | Will be created by Terraform |

## Step 3: Get Your Public Subnet IDs

You need to find your public subnet IDs:

```bash
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-0792f2f110cb731ed" \
  --query "Subnets[?MapPublicIpOnLaunch==\`true\`].{ID:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock}" \
  --output table
```

## Step 4: Create terraform.tfvars

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and update:

```hcl
# Update these values
public_subnet_ids  = ["subnet-XXXXX", "subnet-YYYYY"]  # From Step 3
db_password        = "YourSecurePassword123!"
jwt_secret         = "your-super-secret-jwt-key"
```

## Step 5: Initialize and Plan (Local Test)

```bash
terraform init
terraform plan
```

Review the plan to ensure everything looks correct.

## Step 6: Deploy via GitHub Actions

### Option A: Push to Main Branch

```bash
git add .
git commit -m "Add Terraform infrastructure"
git push origin main
```

The GitHub Actions workflow will automatically:
1. Run `terraform plan`
2. Apply the changes
3. Output the results

### Option B: Create Pull Request

```bash
git checkout -b terraform-setup
git add .
git commit -m "Add Terraform infrastructure"
git push origin terraform-setup
```

Create a PR on GitHub. The workflow will:
1. Run `terraform plan`
2. Comment the plan on the PR
3. Wait for approval before applying

## Step 7: Build and Push Docker Images

After infrastructure is deployed, build and push the initial Docker images:

```bash
# Get ECR login
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 211125602758.dkr.ecr.us-east-1.amazonaws.com

# Build and push auth-service
cd services/auth-service
docker build -t 211125602758.dkr.ecr.us-east-1.amazonaws.com/auth-service:latest .
docker push 211125602758.dkr.ecr.us-east-1.amazonaws.com/auth-service:latest

# Build and push task-service
cd ../task-service
docker build -t 211125602758.dkr.ecr.us-east-1.amazonaws.com/task-service:latest .
docker push 211125602758.dkr.ecr.us-east-1.amazonaws.com/task-service:latest
```

Or push to GitHub and let the workflow handle it:

```bash
git add services/
git commit -m "Update services"
git push origin main
```

## Step 8: Initialize Database

Get the RDS endpoint from Terraform outputs:

```bash
terraform output rds_endpoint
```

Connect and run the schema:

```bash
psql -h <rds-endpoint> -U postgres -d taskmanagement -f ../sql/schema.sql
```

## Step 9: Deploy Frontend

```bash
# Get S3 bucket name from Terraform output
terraform output frontend_bucket_name

# Upload frontend files
aws s3 sync ../frontend/ s3://<bucket-name>/ --exclude "*.md"

# Get CloudFront distribution ID
terraform output cloudfront_distribution_id

# Invalidate cache
aws cloudfront create-invalidation --distribution-id <dist-id> --paths "/*"
```

Or push to GitHub:

```bash
git add frontend/
git commit -m "Update frontend"
git push origin main
```

## Step 10: Verify Deployment

Check the outputs:

```bash
terraform output
```

Test the endpoints:

```bash
# Test API health
curl https://api.fozdigitalz.com/auth/health

# Test frontend
curl -I https://task-management.fozdigitalz.com
```

## Troubleshooting

### State Lock Issues

```bash
# List locks
aws dynamodb scan --table-name terraform-state-lock

# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

### ECS Tasks Not Starting

```bash
# Check logs
aws logs tail /ecs/auth-service --follow
aws logs tail /ecs/task-service --follow
```

### Database Connection Issues

```bash
# Test from EC2 instance in same VPC
psql -h <rds-endpoint> -U postgres -d taskmanagement
```

## Next Steps

1. ✅ Infrastructure deployed
2. ✅ Services running
3. ✅ Frontend accessible
4. ✅ Database initialized

Your Task Management API is now live at:
- **API**: https://api.fozdigitalz.com
- **Frontend**: https://task-management.fozdigitalz.com

## Cleanup

To destroy all infrastructure:

```bash
terraform destroy
```

Or use the cleanup script:

```bash
../scripts/cleanup-all-resources.sh
```
