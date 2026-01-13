# Task 10b: Add HTTPS Listener and Custom Domain to ALB

## Overview

This guide adds HTTPS support to your Application Load Balancer using your existing ACM certificate and configures a custom domain (api.fozdigitalz.com) for your backend API.

## Prerequisites

- Completed Task 10 (ALB with HTTP listener)
- Domain: fozdigitalz.com registered and hosted in Route 53
- ACM Certificate for *.fozdigitalz.com in us-east-1 (already exists)
- ALB running and accessible via HTTP

## Architecture

```
Internet
    ↓
Route 53: api.fozdigitalz.com
    ↓
ALB (HTTPS:443 + HTTP:80)
    ↓
    ├─> /auth/*  → Auth Service (ECS)
    └─> /tasks/* → Task Service (ECS)
```

---

## Step 1: Get Your ACM Certificate ARN

### 1.1 List Certificates

```bash
# List all certificates in us-east-1
aws acm list-certificates --region us-east-1 --query 'CertificateSummaryList[*].[DomainName,CertificateArn]' --output table
```

### 1.2 Get Certificate Details

```bash
# Get certificate ARN for fozdigitalz.com
CERT_ARN=$(aws acm list-certificates \
  --region us-east-1 \
  --query 'CertificateSummaryList[?DomainName==`*.fozdigitalz.com`].CertificateArn' \
  --output text)

echo "Certificate ARN: $CERT_ARN"

# Verify certificate status (should be ISSUED)
aws acm describe-certificate \
  --certificate-arn $CERT_ARN \
  --region us-east-1 \
  --query 'Certificate.{Status:Status,Domain:DomainName,SANs:SubjectAlternativeNames}' \
  --output table
```

Expected output:
```
---------------------------------------------------------
|              DescribeCertificate                      |
+------------------+------------------------------------+
|     Domain       |            Status                  |
+------------------+------------------------------------+
|  *.fozdigitalz.com |  ISSUED                          |
+------------------+------------------------------------+
```

---

## Step 2: Add HTTPS Listener to ALB

### 2.1 Get ALB ARN

```bash
# Get ALB ARN
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names task-management-alb \
  --region us-east-1 \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

echo "ALB ARN: $ALB_ARN"
```

### 2.2 Get Target Group ARNs

```bash
# Get target group ARNs
AUTH_TG_ARN=$(aws elbv2 describe-target-groups \
  --names auth-service-tg \
  --region us-east-1 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

TASK_TG_ARN=$(aws elbv2 describe-target-groups \
  --names task-service-tg \
  --region us-east-1 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

echo "Auth TG ARN: $AUTH_TG_ARN"
echo "Task TG ARN: $TASK_TG_ARN"
```

### 2.3 Create HTTPS Listener

**Via AWS Console:**

1. Go to **EC2 Console** → **Load Balancers**
2. Select **task-management-alb**
3. Go to **Listeners** tab
4. Click **Add listener**
5. Configure:
   - **Protocol**: HTTPS
   - **Port**: 443
   - **Default action**: Forward to `auth-service-tg`
   - **Security policy**: ELBSecurityPolicy-2016-08 (recommended)
   - **Default SSL certificate**: Select your certificate (*.fozdigitalz.com)
6. Click **Add**

**Via AWS CLI:**

```bash
# Create HTTPS listener
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn=$CERT_ARN \
  --default-actions Type=forward,TargetGroupArn=$AUTH_TG_ARN \
  --region us-east-1

# Get HTTPS listener ARN
HTTPS_LISTENER_ARN=$(aws elbv2 describe-listeners \
  --load-balancer-arn $ALB_ARN \
  --region us-east-1 \
  --query 'Listeners[?Port==`443`].ListenerArn' \
  --output text)

echo "HTTPS Listener ARN: $HTTPS_LISTENER_ARN"
```

### 2.4 Add Routing Rules to HTTPS Listener

**Via AWS Console:**

1. Click on the **HTTPS:443** listener
2. Click **Manage rules**
3. Add the same rules as HTTP listener:
   - **Rule 1**: Path is `/auth/*` → Forward to `auth-service-tg` (Priority: 1)
   - **Rule 2**: Path is `/tasks/*` → Forward to `task-service-tg` (Priority: 2)

**Via AWS CLI:**

```bash
# Create rule for /auth/*
aws elbv2 create-rule \
  --listener-arn $HTTPS_LISTENER_ARN \
  --priority 1 \
  --conditions Field=path-pattern,Values='/auth/*' \
  --actions Type=forward,TargetGroupArn=$AUTH_TG_ARN \
  --region us-east-1

# Create rule for /tasks/*
aws elbv2 create-rule \
  --listener-arn $HTTPS_LISTENER_ARN \
  --priority 2 \
  --conditions Field=path-pattern,Values='/tasks/*' \
  --actions Type=forward,TargetGroupArn=$TASK_TG_ARN \
  --region us-east-1

echo "HTTPS routing rules created!"
```

### 2.5 Verify HTTPS Listener

```bash
# List all listeners
aws elbv2 describe-listeners \
  --load-balancer-arn $ALB_ARN \
  --region us-east-1 \
  --query 'Listeners[*].{Protocol:Protocol,Port:Port,Certificate:Certificates[0].CertificateArn}' \
  --output table
```

Expected output:
```
----------------------------------------------------------------------------------
|                              DescribeListeners                                 |
+---------------+------+--------------------------------------------------------+
| Certificate   | Port |                      Protocol                          |
+---------------+------+--------------------------------------------------------+
|  None         |  80  |  HTTP                                                  |
|  arn:aws:...  |  443 |  HTTPS                                                 |
+---------------+------+--------------------------------------------------------+
```

---

## Step 3: Update HTTP Listener to Redirect to HTTPS (Optional but Recommended)

This ensures all HTTP traffic is automatically redirected to HTTPS.

### 3.1 Get HTTP Listener ARN

```bash
# Get HTTP listener ARN
HTTP_LISTENER_ARN=$(aws elbv2 describe-listeners \
  --load-balancer-arn $ALB_ARN \
  --region us-east-1 \
  --query 'Listeners[?Port==`80`].ListenerArn' \
  --output text)

echo "HTTP Listener ARN: $HTTP_LISTENER_ARN"
```

### 3.2 Modify HTTP Listener to Redirect

**Via AWS Console:**

1. Go to **Listeners** tab
2. Select **HTTP:80** listener
3. Click **Edit**
4. Change **Default action** to:
   - **Action type**: Redirect
   - **Protocol**: HTTPS
   - **Port**: 443
   - **Status code**: 301 (Permanent redirect)
5. Click **Save**

**Via AWS CLI:**

```bash
# Modify HTTP listener to redirect to HTTPS
aws elbv2 modify-listener \
  --listener-arn $HTTP_LISTENER_ARN \
  --default-actions Type=redirect,RedirectConfig="{Protocol=HTTPS,Port=443,StatusCode=HTTP_301}" \
  --region us-east-1

echo "HTTP listener now redirects to HTTPS!"
```

### 3.3 Remove HTTP Routing Rules (Optional)

Since HTTP now redirects to HTTPS, you can remove the HTTP routing rules:

**Via AWS Console:**
1. Click on **HTTP:80** listener
2. Click **Manage rules**
3. Delete the /auth/* and /tasks/* rules (keep only default redirect)

**Via AWS CLI:**

```bash
# List HTTP rules
aws elbv2 describe-rules \
  --listener-arn $HTTP_LISTENER_ARN \
  --region us-east-1 \
  --query 'Rules[?Priority!=`default`].RuleArn' \
  --output text | while read RULE_ARN; do
    aws elbv2 delete-rule --rule-arn $RULE_ARN --region us-east-1
done

echo "HTTP routing rules removed (redirect only)"
```

---

## Step 4: Create Route 53 Record for Custom Domain

### 4.1 Get Hosted Zone ID

```bash
# Get hosted zone ID for fozdigitalz.com
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones \
  --query 'HostedZones[?Name==`fozdigitalz.com.`].Id' \
  --output text | cut -d'/' -f3)

echo "Hosted Zone ID: $HOSTED_ZONE_ID"
```

### 4.2 Get ALB DNS Name and Hosted Zone ID

```bash
# Get ALB details
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names task-management-alb \
  --region us-east-1 \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

ALB_HOSTED_ZONE=$(aws elbv2 describe-load-balancers \
  --names task-management-alb \
  --region us-east-1 \
  --query 'LoadBalancers[0].CanonicalHostedZoneId' \
  --output text)

echo "ALB DNS: $ALB_DNS"
echo "ALB Hosted Zone: $ALB_HOSTED_ZONE"
```

### 4.3 Create A Record (Alias) for api.fozdigitalz.com

**Via AWS Console:**

1. Go to **Route 53 Console** → **Hosted zones**
2. Click on **fozdigitalz.com**
3. Click **Create record**
4. Configure:
   - **Record name**: `api`
   - **Record type**: A
   - **Alias**: Toggle ON
   - **Route traffic to**: 
     - Select: "Alias to Application and Classic Load Balancer"
     - Region: us-east-1
     - Load balancer: task-management-alb
   - **Routing policy**: Simple routing
5. Click **Create records**

**Via AWS CLI:**

```bash
# Create change batch JSON
cat > change-batch.json <<EOF
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "api.fozdigitalz.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$ALB_HOSTED_ZONE",
          "DNSName": "$ALB_DNS",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
EOF

# Create the record
aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch file://change-batch.json

echo "DNS record created for api.fozdigitalz.com"

# Clean up
rm change-batch.json
```

### 4.4 Wait for DNS Propagation

```bash
# Check DNS propagation (may take 1-5 minutes)
echo "Waiting for DNS propagation..."
sleep 60

# Test DNS resolution
nslookup api.fozdigitalz.com

# Or use dig
dig api.fozdigitalz.com
```

---

## Step 5: Update Security Group (Allow HTTPS)

### 5.1 Check Current ALB Security Group Rules

```bash
# Get ALB security group ID
ALB_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=task-mgmt-alb-sg" \
  --region us-east-1 \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

# Check current rules
aws ec2 describe-security-groups \
  --group-ids $ALB_SG_ID \
  --region us-east-1 \
  --query 'SecurityGroups[0].IpPermissions[*].{Port:FromPort,Protocol:IpProtocol,Source:IpRanges[0].CidrIp}' \
  --output table
```

### 5.2 Add HTTPS Rule (if not exists)

```bash
# Add HTTPS (443) inbound rule
aws ec2 authorize-security-group-ingress \
  --group-id $ALB_SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0 \
  --region us-east-1

echo "HTTPS rule added to ALB security group"
```

**Via AWS Console:**

1. Go to **EC2 Console** → **Security Groups**
2. Select **task-mgmt-alb-sg**
3. Go to **Inbound rules** tab
4. Click **Edit inbound rules**
5. Click **Add rule**:
   - **Type**: HTTPS
   - **Protocol**: TCP
   - **Port**: 443
   - **Source**: 0.0.0.0/0
6. Click **Save rules**

---

## Step 6: Test HTTPS Endpoint

### 6.1 Test with Custom Domain

```bash
# Test HTTPS health endpoints
curl https://api.fozdigitalz.com/auth/health

# Expected: {"status":"healthy","service":"auth-service"}

curl https://api.fozdigitalz.com/tasks/health

# Expected: {"status":"healthy","service":"task-service"}
```

### 6.2 Test HTTP Redirect

```bash
# Test HTTP redirect to HTTPS
curl -I http://api.fozdigitalz.com/auth/health

# Expected: 301 Moved Permanently
# Location: https://api.fozdigitalz.com/auth/health
```

### 6.3 Test Complete Flow

```bash
# Register a user via HTTPS
curl -X POST https://api.fozdigitalz.com/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"httpstest","email":"https@test.com","password":"Test123!@#"}'

# Login
TOKEN=$(curl -s -X POST https://api.fozdigitalz.com/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"httpstest","password":"Test123!@#"}' | grep -o '"token":"[^"]*' | cut -d'"' -f4)

echo "Token: $TOKEN"

# Create task
curl -X POST https://api.fozdigitalz.com/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title":"HTTPS Test","description":"Testing secure connection","priority":"high"}'

# Get tasks
curl -X GET https://api.fozdigitalz.com/tasks \
  -H "Authorization: Bearer $TOKEN"
```

---

## Step 7: Update Frontend Configuration

Now that your API has HTTPS and a custom domain, update your frontend:

### 7.1 Update app.js

Edit `frontend/app.js` line 2:

```javascript
// OLD
const API_BASE_URL = 'http://task-management-alb-123456789.us-east-1.elb.amazonaws.com';

// NEW
const API_BASE_URL = 'https://api.fozdigitalz.com';
```

### 7.2 Update CORS Configuration (Production)

For production, update CORS to only allow your frontend domain.

Edit `services/auth-service/src/index.js` and `services/task-service/src/index.js`:

```javascript
// CORS middleware - Production configuration
app.use((req, res, next) => {
  const allowedOrigins = [
    'http://task-management-frontend-1767876018.s3-website-us-east-1.amazonaws.com',
    'https://task-management.fozdigitalz.com', // Your frontend domain
    'https://d1234567890abc.cloudfront.net' // Your CloudFront domain (if using)
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

Then rebuild and redeploy services (v1.0.4).

---

## Verification Checklist

- [ ] ACM certificate exists and is ISSUED
- [ ] HTTPS listener created on ALB (port 443)
- [ ] HTTPS routing rules configured (/auth/*, /tasks/*)
- [ ] HTTP listener redirects to HTTPS (301)
- [ ] ALB security group allows HTTPS (443) from 0.0.0.0/0
- [ ] Route 53 A record created for api.fozdigitalz.com
- [ ] DNS resolves to ALB
- [ ] HTTPS health endpoints work
- [ ] HTTP redirects to HTTPS
- [ ] Complete auth/task flow works via HTTPS
- [ ] Frontend updated with HTTPS API URL

---

## Cost Impact

### Additional Costs
- **HTTPS Listener**: No additional cost (included in ALB pricing)
- **ACM Certificate**: FREE
- **Route 53 Hosted Zone**: $0.50/month (already paying)
- **Route 53 Queries**: $0.40/million queries (~$0.01/month for low traffic)

### Total Additional Cost
**~$0.01/month** (essentially free)

---

## Troubleshooting

### Issue: Certificate Not Found

**Solution**: Ensure certificate is in us-east-1 region and covers *.fozdigitalz.com

### Issue: DNS Not Resolving

**Solution**: 
1. Wait 5-10 minutes for DNS propagation
2. Check Route 53 record is correct
3. Verify hosted zone is active

### Issue: HTTPS Connection Refused

**Solution**:
1. Check ALB security group allows port 443
2. Verify HTTPS listener is active
3. Check certificate is attached to listener

### Issue: Certificate Mismatch

**Solution**: Ensure certificate covers the domain (*.fozdigitalz.com covers api.fozdigitalz.com)

---

## Next Steps

After completing this:
1. Update frontend with HTTPS API URL
2. Configure custom domain for frontend (Task 21)
3. Update CORS to production configuration
4. Test complete end-to-end flow

---

## Resources

- [ALB HTTPS Listeners](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html)
- [ACM Certificates](https://docs.aws.amazon.com/acm/latest/userguide/gs.html)
- [Route 53 Alias Records](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-choosing-alias-non-alias.html)

