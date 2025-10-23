variable "project" {
   type = string  
   default = "signalfind" 
   }
variable "env"     { type = string }
variable "region"  {
   type = string  
   default = "ap-southeast-2" 
   }

# Example: create metric alarms; in reality you'd parameterize thresholds and topics
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project}-${var.env}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
}
