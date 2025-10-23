#!/usr/bin/env bash
set -euo pipefail
ENV="${1:-dev}"
REGION="${AWS_REGION:-ap-southeast-2}"
CLUSTER="signalfind-${ENV}-cluster"
SERVICE="signalfind-${ENV}-api"
aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" --force-new-deployment --region "$REGION" >/dev/null
echo "Triggered new deployment for $SERVICE in $CLUSTER"
