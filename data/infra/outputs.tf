
output "manifest_table" {
  description = "DynamoDB table name for Glue job manifests"
  value       = aws_dynamodb_table.manifests.name
}

output "batches_table" {
  description = "DynamoDB table name for batch metadata tracking"
  value       = aws_dynamodb_table.batches.name
}


output "index_queue_arn" {
  description = "SQS queue ARN for event source mapping"
  value       = aws_sqs_queue.index_queue.arn
}

output "step_function_arn" {
  description = "ARN of the Step Functions pipeline"
  value       = aws_sfn_state_machine.pipeline.arn
}



output "lambda_indexer_arn" {
  description = "ARN of the indexer Lambda function"
  value       = aws_lambda_function.indexer.arn
}


output "lambda_batch_creator_arn" {
  description = "ARN of the batch creator Lambda function"
  value       = aws_lambda_function.batch_creator.arn
}

output "lambda_starter_arn" {
  description = "ARN of the S3 event starter Lambda function"
  value       = aws_lambda_function.starter.arn
}

output "glue_job_name" {
  description = "Name of the Glue ETL job"
  value       = var.glue_job_name
}

output "environment" {
  description = "Current environment name (dev, prod)"
  value       = var.env
}
