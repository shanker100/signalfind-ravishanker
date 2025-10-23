# Threat Model (STRIDE-lite)

- **Spoofing**: Enforce TLS everywhere; SigV4 to OpenSearch; IAM auth for API (Cognito/JWT add-on).
- **Tampering**: KMS on S3/OpenSearch; versioning; signed deploys; WORM logs.
- **Repudiation**: CloudTrail+ALB+WAF logs; trace IDs; audit dashboards.
- **Information Disclosure**: WAF rules, FGAC in OpenSearch, row/field level RBAC, token scopes.
- **DoS**: WAF rate limits, Shield Std, autoscaling; circuit breakers in API.
- **Elevation**: Least-privilege IAM; short session TTL; no long-lived keys; code scanning.
