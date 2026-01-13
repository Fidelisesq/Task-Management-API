# Task 21b: Deploy Frontend with Custom Domain (HTTPS)

## Overview

This guide deploys your frontend to S3 and CloudFront with a custom domain (task-management.fozdigitalz.com) and HTTPS support using your existing ACM certificate.

## Prerequisites

- Completed Task 10b (ALB with HTTPS and api.fozdigitalz.com)
- Domain: fozdigitalz.com in Route 53
- ACM Certificate for *.fozdigitalz.com
- Frontend files ready in `frontend/` directory
- S3 bucket created

## Architecture

```
User Browser
    ↓
Route 53: task-management.fozdigitalz.com
    ↓
CloudFront (HTTPS) + ACM Certificate
    ↓
S3 Bucket (Static Website)
    ↓
API Calls → https://api.fozdigitalz.com (ALB)
```

---

## Step 1: Update Frontend Configuration

### 1.1 Update API Base URL

Edit `frontend/app.js` line 2:

```javascript
// Configuration - Use your custom domain
const API_BASE_URL = 'https://api.fozdigitalz.com';
```

### 1.2 Verify Changes

```bash
# Check the update
grep "API_BASE_URL" frontend/app.js

# Should show: const API_BASE_URL = 'https://api.fozdigitalz.com';
```

---

## Step 2: Upload Frontend to S3

### 2.1 Set Bucket Name

```bash
# Use your existing bucket
BUCKET_NAME="task-management-frontend-1767876018"
```

### 2.2 Upload Files

```bash
# Navigate to frontend directory
cd frontend

# Upload all files with correct content types
aws s3 cp index.html s3://$BUCKET_NAME/ --content-type "text/html" --region us-east-1
aws s3 cp styles.css s3://$BUCKET_NAME/ --content-type "text/css" --region us-east-1
aws s3 cp app.js s3://$BUCKET_NAME/ --content-type "application/javascript" --region us-east-1

# Verify upload
aws s3 ls s3://$BUCKET_NAME/

cd ..
```

### 2.3 Test S3 Website (Optional)

```bash
# Get S3 website URL
echo "S3 Website: http://$BUCKET_NAME.s3-website-us-east-1.amazonaws.com"

# Test in browser (should work with HTTP)
```

---

## Step 3: Create CloudFront Distribution with Custom Domain

### 3.1 Get ACM Certificate ARN

**IMPORTANT**: For CloudFront, the certificate MUST be in us-east-1 (which yours is).

```bash
# Get certificate ARN
CERT_ARN=$(aws acm list-certificates \
  --region us-east-1 \
  --query 'CertificateSummaryList[?DomainName==`*.fozdigitalz.com`].CertificateArn' \
  --output text)

echo "Certificate ARN: $CERT_ARN"

# Verify certificate
aws acm describe-certificate \
  --certificate-arn $CERT_ARN \
  --region us-east-1 \
  --query 'Certificate.{Status:Status,Domain:DomainName}' \
  --output table
```

### 3.2 Create CloudFront Distribution

**Via AWS Console:**

1. Go to **CloudFront Console**
2. Click **Create distribution**

3. **Origin Settings**:
   - **Origin domain**: Select your S3 bucket from dropdown OR enter: `task-management-frontend-1767876018.s3-website-us-east-1.amazonaws.com`
   - **Protocol**: HTTP only (S3 website endpoint doesn't support HTTPS)
   - **Name**: Leave default

4. **Default Cache Behavior**:
   - **Viewer protocol policy**: Redirect HTTP to HTTPS
   - **Allowed HTTP methods**: GET, HEAD
   - **Cache policy**: CachingOptimized
   - Leave other settings as default

5. **Settings**:
   - **Price class**: Use all edge locations (best performance)
   - **Alternate domain names (CNAMEs)**: `task-management.fozdigitalz.com`
   - **Custom SSL certificate**: Select your certificate (*.fozdigitalz.com)
   - **Supported HTTP versions**: HTTP/2, HTTP/1.1
   - **Default root object**: `index.html`
   - **Standard logging**: Off (or enable if you want logs)

6. Click **Create distribution**

7. **Wait 15-20 minutes** for distribution to deploy globally

**Via AWS CLI:**

```bash
# Create distribution config JSON
cat > cloudfront-config.json <<EOF
{
  "CallerReference": "task-management-frontend-$(date +%s)",
  "Comment": "Task Management Frontend",
  "Enabled": true,
  "DefaultRootObject": "index.html",
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "S3-task-management-frontend",
        "DomainName": "$BUCKET_NAME.s3-website-us-east-1.amazonaws.com",
        "CustomOriginConfig": {
          "HTTPPort": 80,
          "HTTPSPort": 443,
          "OriginProtocolPolicy": "http-only"
        }
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-task-management-frontend",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    },
    "Compress": true,
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {
        "Forward": "none"
      }
    },
    "MinTTL": 0,
    "DefaultTTL": 86400,
    "MaxTTL": 31536000
  },
  "Aliases": {
    "Quantity": 1,
    "Items": ["task-management.fozdigitalz.com"]
  },
  "ViewerCertificate": {
    "ACMCertificateArn": "$CERT_ARN",
    "SSLSupportMethod": "sni-only",
    "MinimumProtocolVersion": "TLSv1.2_2021"
  },
  "CustomErrorResponses": {
    "Quantity": 2,
    "Items": [
      {
        "ErrorCode": 403,
        "ResponsePagePath": "/index.html",
        "ResponseCode": "200",
        "ErrorCachingMinTTL": 300
      },
      {
        "ErrorCode": 404,
        "ResponsePagePath": "/index.html",
        "ResponseCode": "200",
        "ErrorCachingMinTTL": 300
      }
    ]
  }
}
EOF

# Create distribution
aws cloudfront create-distribution \
  --distribution-config file://cloudfront-config.json \
  --region us-east-1

# Get distribution ID
DISTRIBUTION_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Comment=='Task Management Frontend'].Id" \
  --output text)

echo "Distribution ID: $DISTRIBUTION_ID"

# Get CloudFront domain
CF_DOMAIN=$(aws cloudfront get-distribution \
  --id $DISTRIBUTION_ID \
  --query 'Distribution.DomainName' \
  --output text)

echo "CloudFront Domain: $CF_DOMAIN"

# Clean up
rm cloudfront-config.json
```

### 3.3 Wait for Distribution Deployment

```bash
# Check distribution status
aws cloudfront get-distribution \
  --id $DISTRIBUTION_ID \
  --query 'Distribution.Status' \
  --output text

# Wait for "Deployed" status (15-20 minutes)
# You can continue with next steps while waiting
```

---

## Step 4: Configure Custom Error Pages (Important for SPA)

This ensures your single-page app routing works correctly.

### 4.1 Via AWS Console

1. Go to **CloudFront Console**
2. Select your distribution
3. Go to **Error pages** tab
4. Click **Create custom error response**

5. **For 403 Forbidden**:
   - **HTTP error code**: 403
   - **Customize error response**: Yes
   - **Response page path**: `/index.html`
   - **HTTP response code**: 200
   - Click **Create**

6. **For 404 Not Found**:
   - **HTTP error code**: 404
   - **Customize error response**: Yes
   - **Response page path**: `/index.html`
   - **HTTP response code**: 200
   - Click **Create**

### 4.2 Why This Is Needed

Single-page apps handle routing in JavaScript. When a user navigates to `/dashboard` and refreshes, CloudFront looks for a file called `dashboard` which doesn't exist (404). By returning `index.html` with a 200 status, the app loads and handles the routing.

---

## Step 5: Create Route 53 Record for Frontend

### 5.1 Get Hosted Zone ID

```bash
# Get hosted zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones \
  --query 'HostedZones[?Name==`fozdigitalz.com.`].Id' \
  --output text | cut -d'/' -f3)

echo "Hosted Zone ID: $HOSTED_ZONE_ID"
```

### 5.2 Get CloudFront Distribution Details

```bash
# Get CloudFront domain name
CF_DOMAIN=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Comment=='Task Management Frontend'].DomainName" \
  --output text)

echo "CloudFront Domain: $CF_DOMAIN"

# CloudFront hosted zone ID is always the same
CF_HOSTED_ZONE="Z2FDTNDATAQYW2"
```

### 5.3 Create A Record for task-management.fozdigitalz.com

**Via AWS Console:**

1. Go to **Route 53 Console** → **Hosted zones**
2. Click on **fozdigitalz.com**
3. Click **Create record**
4. Configure:
   - **Record name**: `task-management`
   - **Record type**: A
   - **Alias**: Toggle ON
   - **Route traffic to**:
     - Select: "Alias to CloudFront distribution"
     - Distribution: Select your distribution
   - **Routing policy**: Simple routing
5. Click **Create records**

**Via AWS CLI:**

```bash
# Create change batch
cat > change-batch-frontend.json <<EOF
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "task-management.fozdigitalz.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$CF_HOSTED_ZONE",
          "DNSName": "$CF_DOMAIN",
          "EvaluateTargetHealth": false
        }
      }
    }
  ]
}
EOF

# Create the record
aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch file://change-batch-frontend.json

echo "DNS record created for task-management.fozdigitalz.com"

# Clean up
rm change-batch-frontend.json
```

### 5.4 Wait for DNS Propagation

```bash
# Wait a minute
sleep 60

# Test DNS resolution
nslookup task-management.fozdigitalz.com

# Should resolve to CloudFront domain
```

---

## Step 6: Update CORS Configuration (Production)

Now that you have custom domains, update CORS to be more restrictive.

### 6.1 Update Backend Services

Edit `services/auth-service/src/index.js` and `services/task-service/src/index.js`:

```javascript
// CORS middleware - Production configuration
app.use((req, res, next) => {
  const allowedOrigins = [
    'https://task-management.fozdigitalz.com', // Production frontend
    'http://localhost:8000', // Local development (optional)
    'http://127.0.0.1:8000'  // Local development (optional)
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

### 6.2 Rebuild and Deploy Services

```bash
# Navigate to auth-service
cd services/auth-service

# Build v1.0.4 with production CORS
docker build -t auth-service:v1.0.4 .
docker tag auth-service:v1.0.4 211125602758.dkr.ecr.us-east-1.amazonaws.com/auth-service:v1.0.4
docker tag auth-service:v1.0.4 211125602758.dkr.ecr.us-east-1.amazonaws.com/auth-service:latest

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 211125602758.dkr.ecr.us-east-1.amazonaws.com

# Push
docker push 211125602758.dkr.ecr.us-east-1.amazonaws.com/auth-service:v1.0.4
docker push 211125602758.dkr.ecr.us-east-1.amazonaws.com/auth-service:latest

# Navigate to task-service
cd ../task-service

# Build v1.0.4
docker build -t task-service:v1.0.4 .
docker tag task-service:v1.0.4 211125602758.dkr.ecr.us-east-1.amazonaws.com/task-service:v1.0.4
docker tag task-service:v1.0.4 211125602758.dkr.ecr.us-east-1.amazonaws.com/task-service:latest

# Push
docker push 211125602758.dkr.ecr.us-east-1.amazonaws.com/task-service:v1.0.4
docker push 211125602758.dkr.ecr.us-east-1.amazonaws.com/task-service:latest

# Force new deployment
aws ecs update-service --cluster task-management-cluster --service auth-service --force-new-deployment --region us-east-1
aws ecs update-service --cluster task-management-cluster --service task-service --force-new-deployment --region us-east-1

cd ../..
```

---

## Step 7: Test Complete Setup

### 7.1 Test Frontend Access

```bash
# Test HTTPS access
curl -I https://task-management.fozdigitalz.com

# Expected: 200 OK with CloudFront headers
```

### 7.2 Test in Browser

1. Open browser and go to: **https://task-management.fozdigitalz.com**
2. You should see the login/register page
3. Check browser console (F12) - no errors
4. Check that it's using HTTPS (lock icon in address bar)

### 7.3 Test Complete Flow

1. **Register a new user**
   - Username: prodtest
   - Email: prod@test.com
   - Password: Test123!@#

2. **Login**
   - Should redirect to dashboard
   - Check localStorage has token (DevTools → Application → Local Storage)

3. **Create a task**
   - Click "Add Task"
   - Title: "Production Test"
   - Description: "Testing HTTPS setup"
   - Priority: High
   - Save

4. **Verify task appears**
   - Should see task card
   - Try editing
   - Try deleting

5. **Check Network Tab**
   - All API calls should go to `https://api.fozdigitalz.com`
   - All should return 200 status
   - No CORS errors

### 7.4 Test HTTP Redirect

```bash
# Test that HTTP redirects to HTTPS
curl -I http://task-management.fozdigitalz.com

# Expected: 301 or 302 redirect to HTTPS
```

---

## Step 8: Invalidate CloudFront Cache (When Updating Files)

Whenever you update your frontend files, you need to invalidate the CloudFront cache.

### 8.1 Upload New Files

```bash
# Upload updated files
cd frontend
aws s3 cp index.html s3://$BUCKET_NAME/ --content-type "text/html" --region us-east-1
aws s3 cp styles.css s3://$BUCKET_NAME/ --content-type "text/css" --region us-east-1
aws s3 cp app.js s3://$BUCKET_NAME/ --content-type "application/javascript" --region us-east-1
cd ..
```

### 8.2 Create Invalidation

```bash
# Invalidate all files
aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/*"

# Or invalidate specific files
aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/index.html" "/app.js" "/styles.css"
```

**Via AWS Console:**

1. Go to **CloudFront Console**
2. Select your distribution
3. Go to **Invalidations** tab
4. Click **Create invalidation**
5. Enter paths: `/*` (all files) or specific files
6. Click **Create invalidation**

**Note**: First 1,000 invalidation paths per month are free, then $0.005 per path.

---

## Verification Checklist

- [ ] Frontend files uploaded to S3
- [ ] API_BASE_URL updated to https://api.fozdigitalz.com
- [ ] CloudFront distribution created
- [ ] Custom domain (task-management.fozdigitalz.com) configured
- [ ] ACM certificate attached to CloudFront
- [ ] Custom error pages configured (403, 404 → index.html)
- [ ] Route 53 A record created
- [ ] DNS resolves to CloudFront
- [ ] HTTPS works (lock icon in browser)
- [ ] HTTP redirects to HTTPS
- [ ] Complete user flow works (register, login, CRUD tasks)
- [ ] No CORS errors in browser console
- [ ] Backend CORS updated to production config

---

## Cost Breakdown

### CloudFront Costs
- **Data Transfer Out**: $0.085/GB (first 10TB)
- **HTTPS Requests**: $0.010/10,000 requests
- **Invalidations**: First 1,000 paths/month free, then $0.005/path
- **Free Tier**: 1TB transfer + 10M requests/month for 12 months

### S3 Costs
- **Storage**: $0.023/GB/month (~$0.01 for 3 files)
- **Requests**: Minimal (CloudFront caches)

### Route 53 Costs
- **Hosted Zone**: $0.50/month (already paying)
- **Queries**: $0.40/million (~$0.01/month)

### ACM Certificate
- **FREE** (no charge for public certificates)

### Total Monthly Cost
- **First Year** (with free tier): ~$0.50/month
- **After Free Tier**: ~$2-3/month (low traffic)

---

## Troubleshooting

### Issue: CloudFront Shows "Access Denied"

**Solution**:
1. Verify S3 bucket policy allows public read
2. Check Block Public Access is disabled
3. Verify origin is S3 website endpoint (not S3 bucket endpoint)

### Issue: Custom Domain Not Working

**Solution**:
1. Verify certificate is in us-east-1
2. Check certificate covers domain (*.fozdigitalz.com)
3. Verify Route 53 record points to CloudFront
4. Wait for DNS propagation (up to 48 hours, usually 5-10 minutes)

### Issue: SPA Routing Broken (404 on Refresh)

**Solution**: Configure custom error pages (Step 4)

### Issue: CORS Errors

**Solution**:
1. Verify backend CORS includes frontend domain
2. Check backend services are running v1.0.4
3. Clear browser cache
4. Check browser console for exact error

### Issue: Old Files Showing

**Solution**: Create CloudFront invalidation (Step 8)

---

## Production Best Practices

### 1. Enable CloudFront Logging

```bash
# Create S3 bucket for logs
aws s3 mb s3://task-management-logs-$(date +%s) --region us-east-1

# Enable logging in CloudFront distribution settings
```

### 2. Enable WAF (Web Application Firewall)

Protect against common web exploits:
- SQL injection
- Cross-site scripting (XSS)
- Rate limiting

### 3. Set Cache Headers

Add cache headers to S3 files for better performance:

```bash
# Upload with cache control
aws s3 cp index.html s3://$BUCKET_NAME/ \
  --content-type "text/html" \
  --cache-control "max-age=300" \
  --region us-east-1

aws s3 cp styles.css s3://$BUCKET_NAME/ \
  --content-type "text/css" \
  --cache-control "max-age=31536000" \
  --region us-east-1

aws s3 cp app.js s3://$BUCKET_NAME/ \
  --content-type "application/javascript" \
  --cache-control "max-age=31536000" \
  --region us-east-1
```

### 4. Monitor with CloudWatch

Set up alarms for:
- 4xx error rate
- 5xx error rate
- Cache hit ratio
- Data transfer

---

## Summary

You now have a complete, production-ready setup:

✅ **Frontend**: https://task-management.fozdigitalz.com
✅ **Backend API**: https://api.fozdigitalz.com
✅ **HTTPS**: Enabled with ACM certificate
✅ **CDN**: CloudFront for global distribution
✅ **Custom Domains**: Professional URLs
✅ **CORS**: Configured for production
✅ **Security**: HTTPS everywhere, restricted CORS

---

## Next Steps

1. Test thoroughly from different devices/locations
2. Set up monitoring and alarms
3. Consider adding WAF for additional security
4. Document your domains and credentials
5. Set up automated deployments (CI/CD)

---

## Resources

- [CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [ACM Certificates](https://docs.aws.amazon.com/acm/)
- [Route 53 Alias Records](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-choosing-alias-non-alias.html)
- [S3 Static Website Hosting](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)

