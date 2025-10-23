#!/usr/bin/env bash
set -euo pipefail
ENV="${1:-dev}"
REGION="${AWS_REGION:-ap-southeast-2}"
BUCKET="$(aws cloudformation list-exports --query "Exports[?Name=='site-bucket-${ENV}'].Value" --output text 2>/dev/null || true)"
if [ -z "$BUCKET" ]; then
  echo "Provide the bucket or adapt this script to read TF output."
  exit 1
fi
aws s3 sync . "s3://${BUCKET}" --delete --region "${REGION}"
echo "Deployed to s3://${BUCKET}"
