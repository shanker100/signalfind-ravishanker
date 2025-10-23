# Architecture & Rationale

- **Frontend**: S3 + CloudFront (+WAF). Cheap, globally fast, TLS by default.
- **API Backend**: FastAPI on ECS Fargate behind ALB. Stateless; easy blue/green.
- **Search**: Amazon OpenSearch (VPC). Encrypted, multi-AZ, slow-log to CloudWatch.
- **Data**: S3 raw→curated; Step Functions orchestrates Fetch→Clean→Enrich→Index via Lambdas.
- **Security**: KMS, least-privilege IAM, WAF, GuardDuty/SecurityHub, private networking with VPC endpoints.
- **Observability**: CloudWatch metrics/logs/alarms, X-Ray traces; SLOs on latency/error rate.

See `architecture.png` for the detailed diagram (draw.io).
