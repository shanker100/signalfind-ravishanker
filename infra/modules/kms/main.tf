variable "project" { 
  type = string  
  default = "signalfind" 
  }
variable "env"     { type = string }
variable "region"  {
   type = string  
   default = "ap-southeast-2" 
   }

variable "key_alias" { type = string }

resource "aws_kms_key" "this" {
  enable_key_rotation = true
  description         = "${var.project}-${var.env}-${var.key_alias}"
}
resource "aws_kms_alias" "alias" {
  name          = "alias/${var.project}-${var.env}-${var.key_alias}"
  target_key_id = aws_kms_key.this.key_id
}
output "key_arn" { value = aws_kms_key.this.arn }
output "alias"   { value = aws_kms_alias.alias.name }
