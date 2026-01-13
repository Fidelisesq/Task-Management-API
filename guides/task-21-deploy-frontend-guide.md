# Task 21: Deploy Frontend to S3 and CloudFront

## Overview

This guide walks you through deploying the Task Management frontend as a static website on S3 with CloudFront CDN distribution.

## Prerequisites

- Completed Tasks 1-10 (ALB must be deployed and accessible)
- ALB DNS name available
- AWS CLI configured
- Frontend files created in `frontend/` directory

## Architecture

```
User Browser → CloudFront (HTTPS) → S3 Static Website → ALB (HTTP) → ECS Services
```

---

## Step 1: Update Backend Services with CORS Support

### 1.1 Rebuild Backend Images with CORS

The backend services have been updated with CORS middleware. You need to rebuild and redeploy them.

```bash
# Navigate to auth-service
cd services/auth-service

# Build new image with CORS support (v1.0.3)
docker build -t auth-service:v1.0.3 .

# Tag for ECR
docker tag auth-service:v1.0.3 211125602758.dkr.ecr.us-east-1.amazonaws.com/auth-service:v1.0.3
docker tag auth-service:v1.0.3 211125602758.dkr.ecr.us-east-1.amazonaws.com/auth-service:latest

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 211125602758.dkr.ecr.us-east-1.amazonaws.com

# Push to ECR
docker push 211125602758.dkr.ecr.us-east-1.amazonaws.com/auth-service:v1.0.3
docker push 211125602758.dkr.ecr.us-east-1.amazonaws.com/auth-service:latest

# Navigate to task-service
cd ../task-service

# Build new image with CORS support (v1.0.3)
docker build -t task-service:v1.0.3 .

# Tag for ECR
docker tag task-service:v1.0.3 211125602758.dkr.ecr.us-east-1.amazonaws.com/task-service:v1.0.3
docker tag task-service:v1.0.3 211125602758.dkr.ecr.us-east-1.amazonaws.com/task-service:latest

# Push to ECR
docker push 211125602758.dkr.ecr.us-east-1.amazonaws.com/task-service:v1.0.3
docker push 211125602758.dkr.ecr.us-east-1.amazonaws.com/task-service:latest
```

### 1.2 Update ECS Services

```bash
# Force new deployment for both services to pull updated images
aws ecs update-service --cluster task-management-cluster --service auth-service --force-new-deployment --region us-east-1

aws ecs update-service --cluster task-management-cluster --service task-service --force-new-deployment --region us-east-1

# Wait for deployments to complete (~5 minutes)
aws ecs wait services-stable --cluster task-management-cluster --services auth-service task-service --region us-east-1
```

---

## Step 2: Update Frontend Configuration

### 2.1 Get ALB DNS Name

```bash
# Get your ALB DNS name
aws elbv2 describe-load-balancers --region us-east-1 --query "LoadBalancers[?contains(LoadBalancerName, 'task-management')].DNSName" --output text
```

Example output: `task-management-alb-123456789.us-east-1.elb.amazonaws.com`

### 2.2 Update app.js

Edit `frontend/app.js` and update line 2:

```javascript
const API_BASE_URL = 'http://task-management-alb-123456789.us-east-1.elb.amazonaws.com';
```

Replace with your actual ALB DNS name.

---

## Step 3: Create S3 Bucket for Static Website

### 3.1 Create Bucket

```bash
# Create S3 bucket (bucket names must be globally unique)
BUCKET_NAME="task-management-frontend-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME --region us-east-1

echo "Bucket created: $BUCKET_NAME"
```

### 3.2 Enable Static Website Hosting

```bash
# Enable static website hosting
aws s3 website s3://$BUCKET_NAME --index-document index.html --error-document index.html
```

### 3.3 Configure Bucket Policy for Public Read

Create a file `bucket-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::BUCKET_NAME/*"
    }
  ]
}
```

Replace `BUCKET_NAME` with your actual bucket name, then apply:

```bash
# Update the policy file with your bucket name
sed -i "s/BUCKET_NAME/$BUCKET_NAME/g" bucket-policy.json

# Apply bucket policy
aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy file://bucket-policy.json
```

### 3.4 Disable Block Public Access

```bash
# Disable block public access (required for public website)
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
  "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"
```

---

## Step 4: Upload Frontend Files to S3

### 4.1 Upload Files

```bash
# Navigate to frontend directory
cd frontend

# Upload all files to S3
aws s3 cp index.html s3://$BUCKET_NAME/
aws s3 cp styles.css s3://$BUCKET_NAME/
aws s3 cp app.js s3://$BUCKET_NAME/

# Set correct content types
aws s3 cp index.html s3://$BUCKET_NAME/ --content-type "text/html"
aws s3 cp styles.css s3://$BUCKET_NAME/ --content-type "text/css"
aws s3 cp app.js s3://$BUCKET_NAME/ --content-type "application/javascript"
```

### 4.2 Verify Upload

```bash
# List files in bucket
aws s3 ls s3://$BUCKET_NAME/

# Should show:
# index.html
# styles.css
# app.js
```

---

## Step 5: Test S3 Website

### 5.1 Get Website URL

```bash
# Get website endpoint
echo "Website URL: http://$BUCKET_NAME.s3-website-us-east-1.amazonaws.com"
```

### 5.2 Test in Browser

Open the URL in your browser. You should see:
- Login/Register page
- Ability to register a new user
- Ability to login
- Dashboard with task management

---

## Step 6: Create CloudFront Distribution (Optional but Recommended)

CloudFront provides:
- HTTPS support
- Global CDN (faster loading)
- Custom domain support
- Better security

### 6.1 Create Distribution

```bash
# Create CloudFront distribution
aws cloudfront create-distribution \
  --origin-domain-name $BUCKET_NAME.s3-website-us-east-1.amazonaws.com \
  --default-root-object index.html \
  --region us-east-1 \
  --query 'Distribution.DomainName' \
  --output text
```

**Note**: This takes 15-20 minutes to deploy globally.

### 6.2 Configure Custom Error Pages

Via AWS Console:
1. Go to CloudFront → Distributions
2. Select your distribution
3. Go to Error Pages tab
4. Create custom error response:
   - HTTP Error Code: 403, 404
   - Customize Error Response: Yes
   - Response Page Path: /index.html
   - HTTP Response Code: 200

This ensures the SPA routing works correctly.

### 6.3 Get CloudFront URL

```bash
# List distributions
aws cloudfront list-distributions --query "DistributionList.Items[0].DomainName" --output text
```

Example: `d1234567890abc.cloudfront.net`

---

## Step 7: Update CORS Configuration (Production)

For production, update CORS to only allow your CloudFront domain:

In `services/auth-service/src/index.js` and `services/task-service/src/index.js`:

```javascript
// CORS middleware - Production configuration
app.use((req, res, next) => {
  const allowedOrigins = [
    'http://your-bucket.s3-website-us-east-1.amazonaws.com',
    'https://d1234567890abc.cloudfront.net'
  ];
  
  const origin = req.headers.origin;
  if (allowedOrigins.includes(origin)) {
    res.header('Access-Control-Allow-Origin', origin);
  }
  
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  
  next();
});
```

Then rebuild and redeploy services.

---

## Step 8: Verification

### 8.1 Test Complete Flow

1. **Open frontend** (S3 or CloudFront URL)
2. **Register a new user**
   - Should see success message
3. **Login with credentials**
   - Should redirect to dashboard
4. **Create a task**
   - Click "Add Task"
   - Fill in details
   - Save
5. **View tasks**
   - Should see task card
6. **Edit task**
   - Click Edit button
   - Update details
   - Save
7. **Filter tasks**
   - Try different status filters
8. **Delete task**
   - Click Delete button
   - Confirm deletion
9. **Logout**
   - Click Logout
   - Should return to login page

### 8.2 Check Browser Console

Open browser DevTools (F12) and check:
- No CORS errors
- API requests returning 200 status
- JWT token in localStorage

---

## Troubleshooting

### Issue: CORS Error

**Symptom**: Browser console shows "CORS policy" error

**Solution**:
1. Verify backend services have CORS middleware
2. Check services are running latest image (v1.0.3)
3. Verify ALB is accessible

### Issue: 401 Unauthorized

**Symptom**: All API requests return 401

**Solution**:
1. Check JWT token in localStorage (DevTools → Application → Local Storage)
2. Verify token hasn't expired (1 hour expiration)
3. Try logging out and logging back in

### Issue: Can't Connect to API

**Symptom**: Network errors, can't reach API

**Solution**:
1. Verify `API_BASE_URL` in `app.js` is correct
2. Check ALB is running and healthy
3. Verify ALB security group allows HTTP traffic from 0.0.0.0/0

### Issue: S3 Website Not Loading

**Symptom**: 403 Forbidden or Access Denied

**Solution**:
1. Verify bucket policy is applied
2. Check public access block is disabled
3. Verify files are uploaded with correct permissions

---

## Cost Breakdown

### S3 Costs
- **Storage**: $0.023/GB/month (~$0.01 for 3 small files)
- **Requests**: $0.0004/1000 GET requests
- **Data Transfer**: First 1GB free, then $0.09/GB

### CloudFront Costs (Optional)
- **Data Transfer**: $0.085/GB (first 10TB)
- **Requests**: $0.0075/10,000 HTTPS requests
- **Free Tier**: 1TB transfer + 10M requests/month for 12 months

### Estimated Monthly Cost
- **Without CloudFront**: ~$0.50/month (low traffic)
- **With CloudFront**: ~$1-2/month (low traffic, within free tier first year)

---

## Cleanup (When Done Testing)

```bash
# Delete S3 bucket contents
aws s3 rm s3://$BUCKET_NAME --recursive

# Delete S3 bucket
aws s3 rb s3://$BUCKET_NAME

# Delete CloudFront distribution (if created)
# Must be done via Console - disable first, then delete after ~15 minutes
```

---

## Next Steps

After completing this task:
- ✅ Frontend is deployed and accessible
- ✅ Users can manage tasks via browser
- ✅ CORS is configured correctly
- ✅ Optional HTTPS via CloudFront

You can now proceed with the remaining tasks in your implementation plan!

---

## Resources

- [S3 Static Website Hosting](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)
- [CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [CORS Configuration](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)

