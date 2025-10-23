#!/usr/bin/env bash
set -euo pipefail
ENV="${1:-dev}"
REGION="${AWS_REGION:-ap-southeast-2}"
REPO="sf-backend-${ENV}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
aws ecr describe-repositories --repository-names "${REPO}" --region "${REGION}" >/dev/null 2>&1 || \
  aws ecr create-repository --repository-name "${REPO}" --image-scanning-configuration scanOnPush=true --region "${REGION}"
aws ecr get-login-password --region "${REGION}" | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
docker tag "${ENV}-sf-backend:latest" "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO}:latest"
docker push "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO}:latest"
echo "Pushed: ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO}:latest"
