# Deployment Checklist

Use this checklist to deploy your Task Management API infrastructure using Terraform and GitHub Actions.

## ✅ Pre-Deployment Checklist

### AWS Prerequisites
- [ ] AWS Account ID: `211125602758` ✓
- [ ] S3 Bucket exists: `foz-terraform-state-bucket` ✓
- [ ] Route 53 Hosted Zone: `Z053615514X9UZZVP030H` ✓
- [ ] ACM Certificate: `arn:aws:acm:us-east-1:211125602758:certificate/...` ✓
- [ ] VPC ID: `vpc-0792f2f110cb731ed` ✓
- [ ] Private Subnets: `subnet-01578e4938893297d`, `subnet-0bbad45200c46c4e5` ✓
- [ ] GitHub OIDC Role: `github-platform-actions-oidc` ✓

### To Do
- [ ] Find public subnet IDs
- [ ] Create DynamoDB table for state locking
- [ ] Configure GitHub secrets
- [ ] Create terraform.tfvars file

## 📋 Step-by-Step Deployment

### Step 1: Find Public Subnets

```bash
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-0792f2f110cb731ed" \
  --query "Subnets[?MapPublicIpOnLaunch==\`true\`].{ID:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock}" \
  --output table
```

**Result**: 
- Public Subnet 1: `_________________`
- Public Subnet 2: `_________________`

### Step 2: Create DynamoDB Table

```bash
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

- [ ] DynamoDB table created successfully

### Step 3: Configure GitHub Secrets

Go to: `https://github.com/<your-username>/<your-repo>/settings/secrets/actions`

Add these secrets:

- [ ] `AWS_ACCOUNT_ID` = `211125602758`
- [ ] `DOMAIN_NAME` = `fozdigitalz.com`
- [ ] `ACM_CERTIFICATE_ARN` = `arn:aws:acm:us-east-1:211125602758:certificate/697cf89b-9931-435f-a5f0-c8fd98a6ecdc`
- [ ] `DB_PASSWORD` = `<your-secure-password>`
- [ ] `JWT_SECRET` = `<your-jwt-secret>`
- [ ] `S3_BUCKET_NAME` = `task-management-frontend-1767876018`
- [ ] `CLOUDFRONT_DISTRIBUTION_ID` = `<leave-empty-for-now>`

### Step 4: Create terraform.tfvars

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and update:

```hcl
public_subnet_ids  = ["subnet-XXXXX", "subnet-YYYYY"]  # From Step 1
db_password        = "YourSecurePassword123!"
jwt_secret         = "your-super-secret-jwt-key"
```

- [ ] terraform.tfvars created and configured

### Step 5: Test Locally (Optional)

```bash
cd terraform
terraform init
terraform plan
```

- [ ] Terraform initialized successfully
- [ ] Plan looks correct (review output)

### Step 6: Commit and Push

```bash
git add .
git commit -m "Add Terraform infrastructure configuration"
git push origin main
```

- [ ] Code pushed to GitHub
- [ ] GitHub Actions workflow started

### Step 7: Monitor Deployment

Go to: `https://github.com/<your-username>/<your-repo>/actions`

- [ ] Workflow running
- [ ] Terraform plan completed
- [ ] Terraform apply completed
- [ ] No errors in logs

### Step 8: Get Terraform Outputs

After deployment completes:

```bash
cd terraform
terraform output
```

**Record these values**:
- ALB DNS Name: `_________________`
- API Endpoint: `_________________`
- Frontend URL: `_________________`
- RDS Endpoint: `_________________`
- ECR Auth Repo: `_________________`
- ECR Task Repo: `_________________`
- CloudFront Distribution ID: `_________________`

### Step 9: Update GitHub Secret

Update the CloudFront Distribution ID secret:

- [ ] `CLOUDFRONT_DISTRIBUTION_ID` = `<value-from-step-8>`

### Step 10: Build and Push Docker Images

```bash
# Login to ECR
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

- [ ] Auth service image built and pushed
- [ ] Task service image built and pushed

### Step 11: Initialize Database

```bash
# Get RDS endpoint from Step 8
psql -h <rds-endpoint> -U postgres -d taskmanagement -f sql/schema.sql
```

- [ ] Database schema created
- [ ] Tables created successfully

### Step 12: Deploy Frontend

```bash
# Upload frontend files
aws s3 sync frontend/ s3://task-management-frontend-1767876018/ --exclude "*.md"

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id <cloudfront-dist-id> \
  --paths "/*"
```

- [ ] Frontend files uploaded to S3
- [ ] CloudFront cache invalidated

### Step 13: Verify Deployment

Test the endpoints:

```bash
# Test API health
curl https://api.fozdigitalz.com/auth/health

# Test frontend
curl -I https://task-management.fozdigitalz.com

# Test registration
curl -X POST https://api.fozdigitalz.com/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"Test123!"}'
```

- [ ] API health check returns 200 OK
- [ ] Frontend returns 200 OK
- [ ] Registration works
- [ ] Login works
- [ ] Task creation works

### Step 14: Test in Browser

Open: `https://task-management.fozdigitalz.com`

- [ ] Frontend loads successfully
- [ ] Can register a new user
- [ ] Can login
- [ ] Can create tasks
- [ ] Can view tasks
- [ ] Can edit tasks
- [ ] Can delete tasks
- [ ] Can logout

## ✅ Post-Deployment Checklist

### Monitoring
- [ ] Check CloudWatch logs for errors
- [ ] Verify ECS tasks are running
- [ ] Check RDS connections
- [ ] Monitor ALB health checks

### Security
- [ ] Review security group rules
- [ ] Verify HTTPS is working
- [ ] Check Secrets Manager access
- [ ] Review IAM roles and policies

### Documentation
- [ ] Update README with new endpoints
- [ ] Document any custom configurations
- [ ] Save Terraform outputs for reference

### Backup
- [ ] Verify RDS automated backups are enabled
- [ ] Test database restore procedure
- [ ] Document disaster recovery process

## 🎉 Deployment Complete!

Your Task Management API is now live:

- **API**: https://api.fozdigitalz.com
- **Frontend**: https://task-management.fozdigitalz.com

## 📊 Next Steps

1. **Monitor** the application for 24-48 hours
2. **Test** all functionality thoroughly
3. **Set up** CloudWatch alarms for critical metrics
4. **Configure** auto-scaling if needed
5. **Plan** for regular updates and maintenance

## 🆘 Troubleshooting

If something goes wrong:

1. Check GitHub Actions logs
2. Check CloudWatch logs: `/ecs/auth-service` and `/ecs/task-service`
3. Verify security group rules
4. Check ECS task status
5. Review Terraform state: `terraform show`

## 🧹 Cleanup (If Needed)

To destroy all infrastructure:

```bash
cd terraform
terraform destroy
```

Or use the cleanup script:

```bash
./scripts/cleanup-all-resources.sh
```

---

**Congratulations on your automated infrastructure deployment!** 🚀
