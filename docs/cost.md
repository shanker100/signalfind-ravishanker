# Cost Estimate (Rough, AUD/month in ap-southeast-2)

- OpenSearch (2x t3.small.search, 50GB gp3): $250–$350
- ECS Fargate (2 tasks, 0.25 vCPU/0.5GB, 50% util): $40–$60
- ALB + data transfer (low traffic): $30–$60
- CloudFront + S3 (site + logs): $10–$30
- CloudWatch + logs: $20–$40
- WAF (1 ACL + 1 managed rule set): $30–$60
- S3 (Raw, processed, artifact storage (~300GB)) : $9-$12
- Glue (1 job × 10 min/day (2 DPU)) : $25
- Step Functions (10K exec/month) : $4-$6
- Lambdas × 3 (100K invocations) : $2-$4
- DynamoDB (2 tables) (Light read/write load): $3-$4
- SQS (100K messages) :$1

**Total** small prod: **~$350–$600**. Dev can be < $100 with downsized configs.

I have specified the maximum estimated costs for each service, and if this is a long term engagement , we can consider applicable discounts. All amounts were calculated using the AWS Pricing Calculator. I haven’t included the Terraform backend database cost or the GitHub Actions pricing, as both would be negligible. 