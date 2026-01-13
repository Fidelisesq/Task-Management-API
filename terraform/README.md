# Task Management API - Terraform Infrastructure

This directory contains Terraform configuration for deploying the complete Task Management API infrastructure on AWS.

## Architecture

The infrastructure includes:
- **ECS Fargate** cluster with auth-service and task-service
- **Application Load Balancer** with HTTPS support
- **RDS PostgreSQL** database
- **VPC Endpoints** for private AWS service access
- **CloudFront** distribution for frontend
- **S3** bucket for static frontend hosting
- **Route 53** DNS records
- **ECR** repositories for Docker images
- **Secrets Manager** for sensitive data
- **IAM** roles and policies

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** v1.6.0 or later
3. **AWS CLI** configured
4. **Domain** registered in Route 53
5. **ACM Certificate** for your domain (in us-east-1)
6. **GitHub OIDC Role** named `github-platform-actions-oidc`

## Initial Setup

### 1. Create DynamoDB Table for State Locking (One-time setup)

Your S3 bucket `foz-terraform-state-bucket` is already configured. You just need to create the DynamoDB table for state locking:

```bash
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 2. Backend Configuration

The backend is already configured to use your existing S3 bucket:

```hcl
terraform {
  backend "s3" {
    bucket         = "foz-terraform-state-bucket"
    key            = "task-management-api/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

### 3. Create terraform.tfvars

Copy the example file and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_account_id      = "211125602758"
aws_region          = "us-east-1"
project_name        = "task-management"
environment         = "production"

# VPC Configuration
vpc_id              = "vpc-0792f2f110cb731ed"
private_subnet_ids  = ["subnet-01578e4938893297d", "subnet-0bbad45200c46c4e5"]
public_subnet_ids   = ["subnet-0a1b2c3d4e5f6g7h8", "subnet-0b2c3d4e5f6g7h8i9"]

# Domain Configuration (using existing hosted zone)
domain_name         = "fozdigitalz.com"
hosted_zone_id      = "Z053615514X9UZZVP030H"
acm_certificate_arn = "arn:aws:acm:us-east-1:211125602758:certificate/697cf89b-9931-435f-a5f0-c8fd98a6ecdc"

# Database Configuration
db_name             = "taskmanagement"
db_username         = "postgres"
db_password         = "YourSecurePassword123!"  # Change this!

# JWT Configuration
jwt_secret          = "your-super-secret-jwt-key-change-this"  # Change this!
jwt_expiration      = "3600"

# Frontend Configuration
frontend_bucket_name = "task-management-frontend-1767876018"
```

### 4. Initialize Terraform

```bash
cd terraform
terraform init
```

## Deployment

### Local Deployment

```bash
# Plan changes
terraform plan

# Apply changes
terraform apply

# Destroy infrastructure
terraform destroy
```

### GitHub Actions Deployment

The infrastructure is automatically deployed via GitHub Actions when changes are pushed to the `main` branch.

#### Required GitHub Secrets

Configure these secrets in your GitHub repository (Settings → Secrets and variables → Actions):

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AWS_ACCOUNT_ID` | Your AWS Account ID | `211125602758` |
| `DOMAIN_NAME` | Your domain name | `fozdigitalz.com` |
| `ACM_CERTIFICATE_ARN` | ACM certificate ARN | `arn:aws:acm:us-east-1:...` |
| `DB_PASSWORD` | RDS database password | `SecurePassword123!` |
| `JWT_SECRET` | JWT signing secret | `your-jwt-secret-key` |
| `S3_BUCKET_NAME` | Frontend S3 bucket name | `task-management-frontend-...` |
| `CLOUDFRONT_DISTRIBUTION_ID` | CloudFront distribution ID | `E2KQ99T4J3AKAR` |

#### Workflows

1. **terraform-deploy.yml** - Deploys infrastructure changes
2. **build-and-deploy-services.yml** - Builds and deploys Docker images
3. **deploy-frontend.yml** - Deploys frontend to S3

## Post-Deployment Steps

### 1. Build and Push Initial Docker Images

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build and push auth-service
cd services/auth-service
docker build -t <account-id>.dkr.ecr.us-east-1.amazonaws.com/auth-service:latest .
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/auth-service:latest

# Build and push task-service
cd ../task-service
docker build -t <account-id>.dkr.ecr.us-east-1.amazonaws.com/task-service:latest .
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/task-service:latest
```

### 2. Initialize Database Schema

```bash
# Get RDS endpoint from Terraform output
terraform output rds_endpoint

# Connect to RDS from EC2 instance or local machine with VPN
psql -h <rds-endpoint> -U postgres -d taskmanagement -f ../sql/schema.sql
```

### 3. Deploy Frontend

```bash
# Upload frontend files to S3
aws s3 sync ../frontend/ s3://<bucket-name>/ --exclude "*.md"

# Invalidate CloudFront cache
aws cloudfront create-invalidation --distribution-id <dist-id> --paths "/*"
```

## Terraform Modules

### Main Resources

- **main.tf** - Provider and backend configuration
- **variables.tf** - Input variables
- **outputs.tf** - Output values
- **terraform.tfvars** - Variable values (gitignored)

### Infrastructure Components

- **security_groups.tf** - Security groups for ALB, ECS, RDS, VPC Endpoints
- **vpc_endpoints.tf** - VPC endpoints for ECR, S3, Secrets Manager, CloudWatch
- **rds.tf** - PostgreSQL database
- **ecr.tf** - Docker image repositories
- **iam.tf** - IAM roles and policies
- **ecs.tf** - ECS cluster, services, and task definitions
- **alb.tf** - Application Load Balancer and target groups
- **route53.tf** - DNS records
- **frontend.tf** - S3 bucket and CloudFront distribution

## Outputs

After deployment, Terraform outputs important values:

```bash
terraform output
```

Key outputs:
- `alb_dns_name` - Load balancer DNS name
- `api_endpoint` - API endpoint URL
- `frontend_url` - Frontend URL
- `rds_endpoint` - Database endpoint
- `ecr_auth_repository_url` - Auth service ECR URL
- `ecr_task_repository_url` - Task service ECR URL

## Cost Estimation

Monthly costs (approximate):
- **ECS Fargate**: $30-40 (2 services, 2 tasks each)
- **RDS db.t3.micro**: $15-20
- **Application Load Balancer**: $20-25
- **VPC Endpoints**: $29 (5 endpoints × $7.20/month × 0.8 usage)
- **CloudFront**: $1-5 (depends on traffic)
- **S3**: $1-2
- **Route 53**: $1 (2 hosted zone queries)
- **Secrets Manager**: $1 (2 secrets)
- **ECR**: $1 (storage)

**Total**: ~$100-125/month

## Troubleshooting

### State Lock Issues

If Terraform state is locked:

```bash
# List locks
aws dynamodb scan --table-name terraform-state-lock

# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

### ECS Service Not Starting

Check CloudWatch logs:

```bash
aws logs tail /ecs/auth-service --follow
aws logs tail /ecs/task-service --follow
```

### Database Connection Issues

Verify security group rules and VPC endpoint connectivity:

```bash
# Test from EC2 instance in same VPC
psql -h <rds-endpoint> -U postgres -d taskmanagement
```

## Cleanup

To destroy all infrastructure:

```bash
# Destroy via Terraform
terraform destroy

# Or use the cleanup script
../scripts/cleanup-all-resources.sh
```

## Security Best Practices

1. **Never commit** `terraform.tfvars` or `.tfstate` files
2. **Use Secrets Manager** for sensitive data
3. **Enable encryption** for RDS, S3, and ECS
4. **Use private subnets** for ECS tasks and RDS
5. **Restrict security groups** to minimum required access
6. **Enable VPC Flow Logs** for network monitoring
7. **Use HTTPS** for all external endpoints
8. **Rotate secrets** regularly

## Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
