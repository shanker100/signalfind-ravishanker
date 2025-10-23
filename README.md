# SignalFind – AWS Case Study (Reference Implementation)

This repo is a compact, end‑to‑end **reference implementation** for the “SignalFind” platform described in the case study.
It focuses on **IaC-only** AWS provisioning (Terraform), a minimal **backend API** (FastAPI on ECS Fargate), a **static frontend** on S3+CloudFront,
an **ingest → transform → enrich → index** data path, sensible **security/observability defaults**, and **CI/CD** examples.

> **Region:** `ap-southeast-2` (Sydney) by default.  
> **RTO/RPO Targets:** RTO ≤ 2h, RPO ≤ 15m (see DR+backups plan in `runbooks/`).  
> **Availability Target:** 99.9% for user APIs/search (multi‑AZ, autoscaling).  
> **Latency Target:** P95 ≤ 300ms typical queries on ~15M docs (OpenSearch sizing guidance + cache).

---

## Repo Layout

```
/infra/                 # Terraform (modules + envs)
  ├─ modules/
  │   ├─ vpc/           # VPC, subnets, NAT, endpoints
  │   ├─ kms/           # CMKs + rotation
  │   ├─ opensearch/    # Amazon OpenSearch domain
  │   ├─ ecs/           # ECS cluster, task, service (Fargate)
  │   ├─ s3_cf_site/    # S3+CloudFront static hosting + WAF
  │   ├─ observability/ # CW metrics/alarms, Log groups, X-Ray
  │   └─ security/      # WAF, SecurityHub, GuardDuty, IAM baselines
  └─ envs/
      ├─ dev/
      └─ prod/

/app/
  ├─ backend/           # FastAPI + OpenSearch client + Dockerfile
  └─ frontend/          # Static site + deploy script

/data/
  ├─ requirements.txt
  ├─ mock_generator.py  # Faker-based people/companies -> JSONL
  ├─ glue_job.py        # Example “curation” job (PySpark-like stub)
  └─ data # Fetch -> Clean -> Enrich -> Index
      ├─infra/
      │  ├─ dev.tfvars
      │  ├─ main.tf
      │  ├─ outputs.tf
      │  ├─ variables.tf
      │  └─ pipeline.asl.json
      ├─ glue/
          └─ transform_job.py
      └─ lambda/
          ├─ batch_creator.py
          ├─ indexer.py
          ├─ starter.py
          └─ requirements.txt
/search/
  ├─ index-template.json
  ├─ analyzer.json
  └─ synonyms.txt

/pipelines/
  ├─ ci-cd-infra.yml       # TF fmt/validate/plan/apply (manual approve gate)
  ├─ ci-cd-app.yml         # App build/test/scan/push/deploy
  └─ ci-cd-data.yml        # Data pipeline 

/runbooks/
  ├─ dr.md              # DR/RTO-RPO strategy and runbook
  ├─ security.md        # Access reviews, rotation, least-privilege
  └─ ops.md             # On-call, alerts, dashboards

/docs/
  ├─ architecture.md
  ├─ architecture.mmd   # Mermaid source (render to PNG/PDF in your editor)
  ├─ threat-model.md
  └─ cost.md

README.md               # You are here
Makefile                # Common local commands
```

---

## Bootstrap (Terraform Remote State & Secrets)

> **One-time per account.** You can create the state bucket and lock table via a separate bootstrap step.
This repo expects an **S3 backend + DynamoDB lock table** (names are configurable via `TF_VAR_*`).

1. Create S3 bucket and DynamoDB table (names below are defaults; adjust as needed):
   ```bash
   aws s3 mb s3://sf-tf-state-<your-unique-suffix> --region ap-southeast-2
   aws dynamodb create-table \
     --table-name sf-tf-locks \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST
   ```

2. Create a **Secrets Manager** secret for container image pull, if using a private registry (optional).

3. Export per‑env vars:
   ```bash
   # Example (dev)
   export AWS_REGION=ap-southeast-2
   export TF_VAR_env=dev
   export TF_VAR_domain_name=signalfind.example.com     # if using a custom domain
   export TF_VAR_state_bucket=sf-tf-state-<your-unique-suffix>
   export TF_VAR_lock_table=sf-tf-locks
   ```

---

## Build & Deploy (Local)

```bash
# Lint/format/validate
make tf-fmt tf-validate

# Plan/apply dev
make tf-plan ENV=dev
make tf-apply ENV=dev

# Build + push backend image (uses ECR created by Terraform)
make app-build app-push ENV=dev

# Update ECS service to new image
make app-deploy ENV=dev

# Frontend: build (static) and deploy to S3+CloudFront
make fe-deploy ENV=dev

# Data: generate mock JSONL, then (optionally) trigger index job
make data-gen
make data-index ENV=dev
```

> **Note:** The OpenSearch endpoint and index name are output by Terraform. See `infra/envs/<env>/outputs.tf`. we need to add this endpoint as env var in indexer.py

---

## Demo Flow (Ingest → Transform → Index → Query)

1. create demo csv file (it will create mock_data.csv)
   '''bash
   python data/mock_generator.py --count 500 --output mock_data.csv
   '''
2. Upload to S3 raw bucket (S3 + Lambda (starter.py)): **Ingest**
   - Triggered by file upload; starts Step Function execution.
   
3. AWS Glue (transform_job.py): **Transform**
   - TCleans and normalizes data (PySpark). Writes manifest.
  
4. Lambda (batch_creator.py): **Batch Creation**
   - Splits transformed data into NDJSON batches, stores in S3, records in DynamoDB.
   
5. Lambda (indexer.py): **Indexing**
   - Reads from SQS, performs bulk indexing to OpenSearch using _bulk API.

6. Step Functions (pipeline.asl.json): **State Orchestration**
   - Controls ETL flow: Glue → Batch Creator → Indexer. 

7. S3 + DynamoDB: **Storage**
   - Persistent data, manifest tracking, and batch metadata.

8. OpenSearch + Index Template: **Search Layer**
   - Stores indexed documents with custom analyzers and synonyms.


---

## Security Notes (High Level)

- All data buckets and OpenSearch are **KMS-encrypted**; keys rotate annually.
- **Private subnets** for ECS tasks and OpenSearch with **VPC endpoints** for S3/SM/Logs.
- **WAF** in front of CloudFront and API (ALB/WAF association), **AWS Shield Standard**, **rate limiting**.
- **Least‑privilege IAM** with task roles scoped to specific buckets/index actions.
- **Secrets Manager** for credentials; short‑lived creds where possible (IRSA style via task role).
- **CloudWatch + X-Ray** traces, alarms on p95 latency, 5xx, and queue backlogs.
- **GuardDuty/SecurityHub** enabled; periodic **access reviews** runbook in `runbooks/security.md`.

---

## Cost (Back‑of‑Envelope)

See `docs/cost.md` for itemized estimates and knobs (OpenSearch sizing dominates). Defaults bias for dev/small prod.
You can constrain via index sharding, UltraWarm, and autoscaling.

---

## Notes


- The Terraform is modular; we can swap the backend (Lambda → ECS) without changing the surrounding infra.
