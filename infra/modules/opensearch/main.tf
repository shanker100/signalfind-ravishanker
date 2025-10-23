variable "project" {
   type = string  
   default = "signalfind" 
   }
variable "env"     { type = string }
variable "region"  {
   type = string  
   default = "ap-southeast-2" 
   }

variable "domain_name" { type = string }
variable "subnet_ids"  { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "kms_key_id"  { type = string }

data "aws_secretsmanager_secret" "opensearch_master" {
  name = "signalfind/dev/opensearch/master-user"
}

data "aws_secretsmanager_secret_version" "opensearch_master_version" {
  secret_id = data.aws_secretsmanager_secret.opensearch_master.id
}

locals {
  opensearch_creds = jsondecode(data.aws_secretsmanager_secret_version.opensearch_master_version.secret_string)
}

resource "aws_opensearch_domain" "this" {
  domain_name    = "${var.project}-${var.env}-${var.domain_name}"
  engine_version = "OpenSearch_2.13"

  cluster_config {
    instance_type  = "t3.small.search"
    instance_count = 2
    zone_awareness_enabled = true
    zone_awareness_config { availability_zone_count = 2 }
  }

  ebs_options { 
    ebs_enabled = true 
    volume_size = 50 
    volume_type = "gp3" 
    }

  encrypt_at_rest { 
    enabled = true 
    kms_key_id = var.kms_key_id 
    }
  node_to_node_encryption { enabled = true }
  domain_endpoint_options { 
    enforce_https = true 
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07" 
    }

  vpc_options {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  advanced_security_options {
    enabled = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = local.opensearch_creds.username
      master_user_password = local.opensearch_creds.password
    }
  }
/* 
  log_publishing_options {
    log_type = "INDEX_SLOW_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.os.arn
  }

  log_publishing_options {
    log_type = "SEARCH_SLOW_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.os.arn
  } */

  tags = { Project = var.project, Env = var.env }
}

/* resource "aws_cloudwatch_log_group" "os" {
  name              = "/aws/opensearch/${var.project}/${var.env}"
  retention_in_days = 30
} */

output "endpoint" { value = aws_opensearch_domain.this.endpoint }
output "domain_arn" { value = aws_opensearch_domain.this.arn }
