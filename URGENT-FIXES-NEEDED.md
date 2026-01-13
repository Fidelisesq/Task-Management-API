# Urgent Fixes Needed for Terraform Deployment

## Current Errors

1. ❌ **ALB HTTPS Listener**: Certificate must be specified
2. ❌ **CloudFront**: ViewerCertificate is missing ACMCertificateArn
3. ❌ **PostgreSQL**: Version 15.7 not found (fixed to 16.3)
4. ❌ **Route53**: Record `api.fozdigitalz.com` already exists

## Root Cause Analysis

### Issue 1 & 2: Certificate Not Being Passed
**Problem:** The `acm_certificate_arn` variable is empty when Terraform runs in GitHub Actions.

**Cause:** The GitHub Secret `ACM_CERTIFICATE_ARN` is either:
- Not set in GitHub repository secrets
- Set incorrectly
- Being overridden by an empty value

**Solution:** Verify and set the GitHub Secret

### Issue 3: PostgreSQL Version
**Problem:** AWS RDS doesn't have PostgreSQL version 15.7

**Solution:** Changed to version 16.3 (latest stable)

### Issue 4: Route53 Record Exists
**Problem:** The `api.fozdigitalz.com` A record already exists from manual setup

**Solution:** Delete the existing record before Terraform creates it

---

## IMMEDIATE ACTIONS REQUIRED

### Action 1: Verify GitHub Secrets

Go to: https://github.com/Fidelisesq/Task-Management-API/settings/secrets/actions

**Verify these secrets exist and have correct values:**

| Secret Name | Expected Value | Status |
|------------|----------------|--------|
| `AWS_ACCOUNT_ID` | `211125602758` | ❓ Check |
| `DOMAIN_NAME` | `fozdigitalz.com` | ❓ Check |
| `ACM_CERTIFICATE_ARN` | `arn:aws:acm:us-east-1:211125602758:certificate/697cf89b-9931-435f-a5f0-c8fd98a6ecdc` | ❓ Check |
| `DB_PASSWORD` | `<your-password>` | ❓ Check |
| `JWT_SECRET` | `<your-secret>` | ❓ Check |

**How to check:**
1. Go to repository Settings
2. Click "Secrets and variables" → "Actions"
3. Verify all 5 secrets are listed
4. Click "Update" on each to verify the value

**If any are missing, add them now!**

### Action 2: Delete Existing Route53 Records

Run this command to delete the conflicting Route53 record:

```bash
# Make script executable
chmod +x scripts/cleanup-existing-resources.sh

# Run cleanup
./scripts/cleanup-existing-resources.sh
```

Or manually delete via AWS CLI:

```bash
# Get the existing record
aws route53 list-resource-record-sets \
  --hosted-zone-id Z053615514X9UZZVP030H \
  --query "ResourceRecordSets[?Name=='api.fozdigitalz.com.']" \
  --output json > /tmp/api-record.json

# Delete it (you'll need to format this as a change batch)
# Or delete via AWS Console:
# Route 53 → Hosted zones → fozdigitalz.com → Delete record "api"
```

**Easier option - Delete via AWS Console:**
1. Go to Route 53 console
2. Click on hosted zone `fozdigitalz.com`
3. Find record `api.fozdigitalz.com` (Type A)
4. Select it and click "Delete"
5. Confirm deletion

### Action 3: Update terraform.tfvars (Already Done)

The `terraform.tfvars` file already has the correct certificate ARN:
```terraform
acm_certificate_arn = "arn:aws:acm:us-east-1:211125602758:certificate/697cf89b-9931-435f-a5f0-c8fd98a6ecdc"
```

But GitHub Actions is overriding this with the secret value. **Make sure the GitHub Secret matches!**

---

## Alternative Solution: Use terraform.tfvars Instead of Secrets

If you want to avoid GitHub Secrets for non-sensitive values, update the workflow:

### Option A: Remove Certificate from Workflow (Use terraform.tfvars)

Edit `.github/workflows/terraform-deploy.yml`:

```yaml
- name: Terraform Plan
  id: plan
  run: |
    terraform plan -no-color -input=false -out=tfplan \
      -var="aws_account_id=${{ secrets.AWS_ACCOUNT_ID }}" \
      -var="db_password=${{ secrets.DB_PASSWORD }}" \
      -var="jwt_secret=${{ secrets.JWT_SECRET }}"
  continue-on-error: true
```

Remove these lines:
- `-var="domain_name=${{ secrets.DOMAIN_NAME }}"`
- `-var="acm_certificate_arn=${{ secrets.ACM_CERTIFICATE_ARN }}"`

This will use the values from `terraform.tfvars` instead.

### Option B: Keep Secrets But Verify They're Set

Keep the workflow as-is but ensure all secrets are properly set in GitHub.

---

## Quick Fix Commands

### 1. Delete Route53 Record (Manual)
```bash
# Via AWS Console (Easiest):
# Route 53 → Hosted zones → fozdigitalz.com → Select "api" record → Delete

# Via AWS CLI:
aws route53 list-resource-record-sets \
  --hosted-zone-id Z053615514X9UZZVP030H \
  --query "ResourceRecordSets[?Name=='api.fozdigitalz.com.' && Type=='A']"
```

### 2. Verify Certificate Exists
```bash
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:211125602758:certificate/697cf89b-9931-435f-a5f0-c8fd98a6ecdc \
  --region us-east-1 \
  --query "Certificate.{Status:Status,DomainName:DomainName,SANs:SubjectAlternativeNames}"
```

Expected output:
```json
{
    "Status": "ISSUED",
    "DomainName": "*.fozdigitalz.com",
    "SANs": [
        "*.fozdigitalz.com",
        "fozdigitalz.com"
    ]
}
```

### 3. Check PostgreSQL Versions Available
```bash
aws rds describe-db-engine-versions \
  --engine postgres \
  --query "DBEngineVersions[?starts_with(EngineVersion, '16')].EngineVersion" \
  --output table
```

---

## Recommended Approach

**I recommend Option A** (use terraform.tfvars for non-sensitive values):

1. **Delete the Route53 record** (via AWS Console - easiest)
2. **Update the workflow** to only pass sensitive secrets:
   - Keep: `aws_account_id`, `db_password`, `jwt_secret`
   - Remove: `domain_name`, `acm_certificate_arn`
3. **Commit and push** the workflow changes
4. **Re-run the workflow**

This approach:
- ✅ Simpler - fewer secrets to manage
- ✅ Less error-prone - values are in version control
- ✅ Easier to debug - can see values in terraform.tfvars
- ✅ Still secure - sensitive values (passwords, secrets) remain in GitHub Secrets

---

## Files Changed

### ✅ Already Fixed:
- `terraform/rds.tf` - PostgreSQL version changed to 16.3
- `terraform/main.tf` - Added automatic public subnet discovery
- `terraform/alb.tf` - Uses local variable for subnets
- `terraform/variables.tf` - Public subnets default to empty array

### ⏳ Need to Fix:
- Delete Route53 record `api.fozdigitalz.com`
- Verify/set GitHub Secrets
- OR update workflow to use terraform.tfvars

---

## Next Steps

1. **Choose your approach** (Option A or Option B above)
2. **Delete the Route53 record**
3. **Update workflow if using Option A**
4. **Commit and push changes**
5. **Re-run the workflow**

The deployment should then succeed!
