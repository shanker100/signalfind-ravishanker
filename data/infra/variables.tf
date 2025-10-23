############################
# Core environment settings
############################

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "env" {
  description = "Deployment environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "account_id" {
  description = "AWS account ID to make global resources unique"
  type        = string
}

############################
# OpenSearch configuration
############################

variable "index_alias" {
  description = "Alias name for the OpenSearch index"
  type        = string
  default     = "leads"
}

############################
# Glue job configuration
############################

variable "glue_job_name" {
  description = "Name of the Glue ETL job that transforms raw data"
  type        = string
  default     = "signalfind-transform-job"
}

variable "glue_script_path" {
  description = "S3 path to the Glue ETL script (e.g., s3://bucket/scripts/transform_job.py)"
  type        = string
  default     = "scripts/glue/transform_job.py"
}

############################
# Step Functions
############################

variable "state_machine_name" {
  description = "Name of the Step Functions state machine"
  type        = string
  default     = "signalfind-pipeline"
}

############################
# Lambda configuration
############################

variable "lambda_timeout" {
  description = "Default timeout for Lambda functions (in seconds)"
  type        = number
  default     = 300
}

variable "lambda_memory_size" {
  description = "Default memory size for Lambda functions (in MB)"
  type        = number
  default     = 512
}

############################
# SQS & batch processing
############################

variable "batch_size" {
  description = "Number of records per index batch"
  type        = number
  default     = 5
}

############################
# Tags and metadata
############################

variable "tags" {
  description = "Default tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "SignalFind"
    Environment = "dev"
    Owner       = "DataPlatformTeam"
  }
}
