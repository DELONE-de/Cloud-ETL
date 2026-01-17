resource "aws_sns_topic" "alerts" {
  name = "${var.project_prefix}-${var.environment}-alerts"
  
  tags = {
    Project     = var.project_prefix
    Environment = var.environment
  }
}