terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40"
    }
  }
}
provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
    bucket         = var.state_bucket
    key            = "tfstate/${var.project}/${var.env}.tfstate"
    region         = var.region
    dynamodb_table = var.lock_table
    encrypt        = true
  }
}

variable "state_bucket" { type = string }
variable "lock_table"   { type = string }
variable "domain_name"  {
   type = string 
   default = null 
   }

module "vpc" {
  source = "../../modules/vpc"
  project = var.project
  env     = var.env
  region  = var.region
}

module "kms_data" {
  source = "../../modules/kms"
  project = var.project
  env     = var.env
  key_alias = "data"
}

module "opensearch" {
  source = "../../modules/opensearch"
  project = var.project
  env     = var.env
  domain_name = "search"
  subnet_ids  = module.vpc.private_subnet_ids
  security_group_ids = []
  kms_key_id  = module.kms_data.key_arn
}

module "site" {
  source = "../../modules/s3_cf_site"
  project = var.project
  env     = var.env
  domain_name = var.domain_name
}

# Outputs
output "vpc_id"           { value = module.vpc.vpc_id }
output "site_bucket"      { value = module.site.site_bucket }
output "cdn_domain"       { value = module.site.cdn_domain }
output "os_endpoint"      { value = module.opensearch.endpoint }
output "kms_data_key_arn" { value = module.kms_data.key_arn }
