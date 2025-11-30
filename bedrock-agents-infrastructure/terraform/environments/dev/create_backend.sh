#!/usr/bin/env bash
set -euo pipefail

# Configurable parameters
REGION="eu-west-2" # Change if needed
BUCKET="servicenow-ai-terraform-state-dev"
KMS_ALIAS="alias/terraform-state-key-dev"

# 1. Ensure KMS key exists (create only if alias not present)
if ! aws kms list-aliases --query 'Aliases[?AliasName==`'"$KMS_ALIAS"'`]' --output text | grep -q "$KMS_ALIAS"; then
  echo "Creating KMS key and alias $KMS_ALIAS"
  KEY_ID=$(aws kms create-key --description "Terraform state dev key" --query 'KeyMetadata.KeyId' --output text)
  aws kms create-alias --alias-name "$KMS_ALIAS" --target-key-id "$KEY_ID"
else
  echo "KMS alias $KMS_ALIAS already exists"
fi

# 2. Create S3 bucket (LocationConstraint required if region != us-east-1)
if [[ "$REGION" == "us-east-1" ]]; then
  aws s3api create-bucket --bucket "$BUCKET"
else
  aws s3api create-bucket --bucket "$BUCKET" \
    --create-bucket-configuration LocationConstraint="$REGION"
fi

# 3. Block all public access
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration '{
  "BlockPublicAcls": true,
  "IgnorePublicAcls": true,
  "BlockPublicPolicy": true,
  "RestrictPublicBuckets": true
}'

# 4. Enable versioning
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled

# 5. Default bucket encryption (SSE-KMS with alias)
aws s3api put-bucket-encryption --bucket "$BUCKET" --server-side-encryption-configuration "{
  \"Rules\": [
    {
      \"ApplyServerSideEncryptionByDefault\": {
        \"SSEAlgorithm\": \"aws:kms\",
        \"KMSMasterKeyID\": \"${KMS_ALIAS}\"
      }
    }
  ]
}"

# 6. (Optional) Verify configuration
aws s3api get-bucket-encryption --bucket "$BUCKET" || true
aws s3api get-bucket-versioning --bucket "$BUCKET"
aws s3api get-public-access-block --bucket "$BUCKET" || true

echo "Bucket $BUCKET ready with KMS encryption, versioning, and public access blocked."
