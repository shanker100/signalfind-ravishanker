variable "project" { 
  type = string  
  default = "signalfind" 
  }
variable "env"     { type = string }
variable "region"  { 
  type = string  
  default = "ap-southeast-2" 
  }

variable "domain_name" { 
  type = string  
  default = null 
  }

variable "enable_waf"  {
   type = bool    
   default = true 
   }

resource "aws_s3_bucket" "site" {
  bucket = "${var.project}-${var.env}-site"
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.project}-${var.env}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}


resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  default_root_object = "index.html"
  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "site"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "site"
    viewer_protocol_policy = "redirect-to-https"
  }
  restrictions { 
    geo_restriction { restriction_type = "none" } 
    }
  viewer_certificate { cloudfront_default_certificate = true }
  price_class = "PriceClass_100"
}

output "site_bucket" { value = aws_s3_bucket.site.id }
output "cdn_domain"  { value = aws_cloudfront_distribution.cdn.domain_name }
  