#!/bin/bash

# Script to clean up existing resources that conflict with Terraform

set -e

echo "=========================================="
echo "Cleanup Existing Resources"
echo "=========================================="
echo ""

HOSTED_ZONE_ID="Z053615514X9UZZVP030H"
DOMAIN="fozdigitalz.com"

# Function to delete Route53 record
delete_route53_record() {
    local record_name=$1
    local record_type=$2
    
    echo "Checking if Route53 record exists: $record_name"
    
    # Get the record
    RECORD=$(aws route53 list-resource-record-sets \
        --hosted-zone-id "$HOSTED_ZONE_ID" \
        --query "ResourceRecordSets[?Name=='${record_name}.' && Type=='${record_type}']" \
        --output json)
    
    if [ "$RECORD" != "[]" ]; then
        echo "⚠️  Record exists: $record_name"
        echo "Deleting record..."
        
        # Create change batch
        CHANGE_BATCH=$(cat <<EOF
{
  "Changes": [{
    "Action": "DELETE",
    "ResourceRecordSet": $(echo "$RECORD" | jq '.[0]')
  }]
}
EOF
)
        
        aws route53 change-resource-record-sets \
            --hosted-zone-id "$HOSTED_ZONE_ID" \
            --change-batch "$CHANGE_BATCH"
        
        echo "✅ Record deleted: $record_name"
    else
        echo "✅ Record does not exist: $record_name"
    fi
    echo ""
}

# Delete api.fozdigitalz.com A record
delete_route53_record "api.${DOMAIN}" "A"

# Delete task-management.fozdigitalz.com A record  
delete_route53_record "task-management.${DOMAIN}" "A"

echo "=========================================="
echo "✅ Cleanup Complete!"
echo "=========================================="
echo ""
echo "You can now run Terraform apply"
echo ""
