# Security Baseline

- **IAM**: per-service roles; deny * to account root; mandatory MFA for humans.
- **KMS**: CMKs with rotation; alias `signalfind-<env>-data`.
- **Secrets**: AWS Secrets Manager; rotation lambdas for any static creds.
- **Network**: Private subnets, VPC endpoints; WAF managed rules + rate limiting.
- **Logging**: CloudTrail (org), ALB/WAF logs to S3, CW logs with 30-day retention.
- **Reviews**: Quarterly access reviews; automated drift detection; OPA/Conftest gates.
