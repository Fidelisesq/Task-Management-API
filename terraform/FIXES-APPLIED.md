# Terraform Configuration Fixes Applied

## Issues Fixed

### 1. Invalid Public Subnet IDs ✅
**Problem:** The `public_subnet_ids` variable had placeholder values that don't exist in your VPC.

**Solution:** 
- Added data source to automatically fetch public subnets from your VPC
- Created local variable that uses provided subnet IDs or auto-fetches them
- Updated ALB to use the local variable

**Files Changed:**
- `terraform/main.tf` - Added data source and local variable
- `terraform/variables.tf` - Changed default to empty list
- `terraform/alb.tf` - Updated to use `local.public_subnet_ids`

### 2. PostgreSQL Version Not Available ✅
**Problem:** PostgreSQL version 15.4 doesn't exist in AWS RDS.

**Solution:** Changed to version 15.7 (latest available in PostgreSQL 15.x series)

**Files Changed:**
- `terraform/rds.tf` - Updated `engine_version` from "15.4" to "15.7"

### 3. CloudFront Certificate Configuration ✅
**Problem:** CloudFront viewer certificate configuration issue.

**Solution:** The configuration is actually correct. The issue might be:
- ACM certificate must be in `us-east-1` region (which yours is)
- Certificate must be validated and issued
- The error might resolve once other issues are fixed

**Note:** Your ACM certificate ARN is already in us-east-1, which is correct for CloudFront.

## What Changed

### terraform/main.tf
```terraform
# Added data source to fetch public subnets
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

# Added local variable for subnet selection
locals {
  public_subnet_ids = length(var.public_subnet_ids) > 0 ? var.public_subnet_ids : data.aws_subnets.public.ids
}
```

### terraform/variables.tf
```terraform
variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
  default     = []  # Will be fetched via data source if empty
}
```

### terraform/alb.tf
```terraform
resource "aws_lb" "main" {
  # ...
  subnets = local.public_subnet_ids  # Changed from var.public_subnet_ids
}
```

### terraform/rds.tf
```terraform
resource "aws_db_instance" "main" {
  # ...
  engine_version = "15.7"  # Changed from "15.4"
}
```

## Next Steps

1. Commit and push these changes:
   ```bash
   git add terraform/
   git commit -m "Fix Terraform configuration errors"
   git push
   ```

2. The workflow will automatically run and should now succeed

3. If CloudFront still fails, verify:
   - ACM certificate is in ISSUED status
   - Certificate covers `*.fozdigitalz.com` or `task-management.fozdigitalz.com`
   - Run: `aws acm describe-certificate --certificate-arn arn:aws:acm:us-east-1:211125602758:certificate/697cf89b-9931-435f-a5f0-c8fd98a6ecdc --region us-east-1`

## Verification Commands

### Check if public subnets exist:
```bash
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-0792f2f110cb731ed" "Name=map-public-ip-on-launch,Values=true" \
  --query "Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]" \
  --output table
```

### Check PostgreSQL versions available:
```bash
aws rds describe-db-engine-versions \
  --engine postgres \
  --engine-version 15 \
  --query "DBEngineVersions[*].EngineVersion" \
  --output table
```

### Check ACM certificate status:
```bash
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:211125602758:certificate/697cf89b-9931-435f-a5f0-c8fd98a6ecdc \
  --region us-east-1 \
  --query "Certificate.{Status:Status,DomainName:DomainName,SubjectAlternativeNames:SubjectAlternativeNames}"
```

## Troubleshooting

### If ALB still fails with subnet error:
Your VPC might not have public subnets. Check with:
```bash
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-0792f2f110cb731ed" --query "Subnets[*].[SubnetId,MapPublicIpOnLaunch,AvailabilityZone]" --output table
```

If no public subnets exist, you'll need to either:
1. Create public subnets in your VPC
2. Use an internet-facing ALB in private subnets with NAT Gateway
3. Use an internal ALB (set `internal = true` in alb.tf)

### If CloudFront still fails:
The certificate might not be validated. Check status and validate if needed:
```bash
aws acm describe-certificate --certificate-arn arn:aws:acm:us-east-1:211125602758:certificate/697cf89b-9931-435f-a5f0-c8fd98a6ecdc --region us-east-1
```
