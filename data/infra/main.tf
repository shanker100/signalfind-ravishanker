terraform {
  required_providers { aws = { source="hashicorp/aws", version=">= 4.0" } }
  required_version = ">=1.1"
}

provider "aws" { region = var.region }

# -------------------
# Buckets
# -------------------
resource "aws_s3_bucket" "raw" {
  bucket = "signalfind-raw-${var.env}-${var.account_id}"
  force_destroy = true
  
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket      = aws_s3_bucket.raw.id
  eventbridge = true
}

resource "aws_s3_bucket" "processed" {
  bucket = "signalfind-processed-${var.env}-${var.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket" "index_batch" {
  bucket = "signalfind-index-batch-${var.env}-${var.account_id}"
  force_destroy = true
}

# -------------------
# DynamoDB Tables
# -------------------
resource "aws_dynamodb_table" "manifests" {
  name = "signalfind-manifests-${var.env}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "job_id"
  attribute { 
    name="job_id"
    type="S" 
    }
}

resource "aws_dynamodb_table" "batches" {
  name = "signalfind-batches-${var.env}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "batch_id"
  attribute { 
    name="batch_id" 
    type="S" 
    }
}

# -------------------
# SQS + DLQ
# -------------------
resource "aws_sqs_queue" "dlq" {
  name = "signalfind-index-dlq-${var.env}"
}

resource "aws_sqs_queue" "index_queue" {
  name = "signalfind-index-queue-${var.env}"
  visibility_timeout_seconds = 900
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount = 5
  })
}


# -------------------
# IAM Roles
# -------------------
data "aws_iam_policy_document" "lambda_assume" {
  statement {
     actions=["sts:AssumeRole"]
  
  principals { 
    type="Service"
  identifiers=["lambda.amazonaws.com"] 
  } 
 }
}

resource "aws_iam_role" "lambda_role" {
  name = "signalfind-lambda-${var.env}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version="2012-10-17",
    Statement=[
      { Effect="Allow", Action=["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"], Resource="arn:aws:logs:*:*:*" },
      { Effect="Allow", Action=["s3:GetObject","s3:PutObject","s3:ListBucket"], Resource=[aws_s3_bucket.raw.arn,"${aws_s3_bucket.raw.arn}/*", aws_s3_bucket.processed.arn,"${aws_s3_bucket.processed.arn}/*", aws_s3_bucket.index_batch.arn,"${aws_s3_bucket.index_batch.arn}/*"] },
      { Effect="Allow", Action=["dynamodb:GetItem","dynamodb:PutItem","dynamodb:UpdateItem","dynamodb:Query"], Resource=[aws_dynamodb_table.manifests.arn, aws_dynamodb_table.batches.arn] }
    ]
  })
}

# -------------------
# Lambda Functions
# -------------------

variable "artifact_bucket" {
  description = "S3 bucket containing Lambda ZIPs and Glue scripts"
  type        = string
}

locals { lambda_env_vars = {
  
    INDEX_ALIAS = var.index_alias
    BATCH_TABLE = aws_dynamodb_table.batches.name
    MANIFEST_TABLE = aws_dynamodb_table.manifests.name
    INDEX_BATCH_BUCKET = aws_s3_bucket.index_batch.bucket
    PROCESSED_BUCKET = aws_s3_bucket.processed.bucket
}}

resource "aws_lambda_function" "starter" {
  
  function_name = "starter-${var.env}"
  s3_bucket     = var.artifact_bucket          # The S3 bucket uploaded by CI/CD
  s3_key        = "lambda/starter.zip"
  role = aws_iam_role.lambda_role.arn
  handler = "starter.handler"
  runtime = "python3.11"
  memory_size = 256
  timeout = 60
  environment { variables = local.lambda_env_vars }
}

resource "aws_lambda_function" "batch_creator" {

  function_name = "batch_creator-${var.env}"
  s3_bucket     = var.artifact_bucket          # The S3 bucket uploaded by CI/CD
  s3_key        = "lambda/batch_creator.zip"
  role = aws_iam_role.lambda_role.arn
  handler = "batch_creator.handler"
  runtime = "python3.11"
  memory_size = 512
  timeout = 300
  environment { variables = local.lambda_env_vars }

}

resource "aws_lambda_function" "indexer" {
  
  function_name = "indexer-${var.env}"
   s3_bucket     = var.artifact_bucket          # The S3 bucket uploaded by CI/CD
  s3_key        = "lambda/indexer.zip"
  role = aws_iam_role.lambda_role.arn
  handler = "indexer.handler"
  runtime = "python3.11"
  memory_size = 1024
  timeout = 900
  environment { variables = local.lambda_env_vars }
}

# -------------------
# SQS -> Indexer
# -------------------
resource "aws_lambda_event_source_mapping" "sqs_mapping" {
  event_source_arn = aws_sqs_queue.index_queue.arn
  function_name = aws_lambda_function.indexer.arn
  batch_size = 5
}

# -------------------
# Step Functions
# -------------------
data "aws_iam_policy_document" "sf_assume" {
  statement { 
    actions=["sts:AssumeRole"]

    principals { 
        type="Service"
        identifiers=["states.amazonaws.com"] 
        } 
        }
}

resource "aws_iam_role" "sf_role" {
     name="signalfind-sf-role-${var.env}"
     assume_role_policy=data.aws_iam_policy_document.sf_assume.json 
     }

resource "aws_iam_role_policy" "sf_policy" {
  role = aws_iam_role.sf_role.id
  policy = jsonencode({
    Version="2012-10-17",
    Statement=[{ Effect="Allow", Action=["lambda:InvokeFunction","glue:StartJobRun","sqs:SendMessage"], Resource="*" }]
  })
}

resource "aws_sfn_state_machine" "pipeline" {
  name = "signalfind-pipeline-${var.env}"
  role_arn = aws_iam_role.sf_role.arn
  definition = file("${path.module}/pipeline.asl.json")
}

# -------------------
# EventBridge Rule → Step Function
# -------------------
resource "aws_cloudwatch_event_rule" "trigger_sf" {
  name = "signalfind-trigger-sf-${var.env}"
  event_pattern = jsonencode({
    source=["aws.s3"],
    "detail-type"=["Object Created"],
    resources=[aws_s3_bucket.raw.arn]
  })
}

resource "aws_cloudwatch_event_target" "sf_target" {
  rule = aws_cloudwatch_event_rule.trigger_sf.name
  target_id = "stepfunction"
  arn = aws_sfn_state_machine.pipeline.arn
}

# -------------------
# Outputs
# -------------------
output "raw_bucket" { value = aws_s3_bucket.raw.bucket }
output "processed_bucket" { value = aws_s3_bucket.processed.bucket }
output "index_batch_bucket" { value = aws_s3_bucket.index_batch.bucket }
output "index_queue_url" { value = aws_sqs_queue.index_queue.id }
output "state_machine_arn" { value = aws_sfn_state_machine.pipeline.arn }
