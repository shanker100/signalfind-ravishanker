# DR Plan (RTO ≤ 2h, RPO ≤ 15m)

- **Data**: OpenSearch snapshots to S3 every 15 minutes (UltraWarm for cost), S3 versioning+CRR to secondary region.
- **Infra**: Terraform pipeline targets **ap-southeast-2** and **ap-southeast-1** (warm standby).
- **Runbook**:
  1. Declare incident; freeze deploys.
  2. Promote standby OpenSearch from latest snapshot.
  3. Recreate ECS service (new image from ECR) via `tf apply` in secondary.
  4. Flip DNS to secondary; warm caches.
