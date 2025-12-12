resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_prefix}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = var.lambda_error_threshold
  alarm_actions       = [var.alarm_sns_topic_arn]

  dimensions = {
    FunctionName = var.validation_lambda_name
  }
}


resource "aws_cloudwatch_log_group" "sfn_logs" {
  name              = "/aws/states/${var.project_name}-pipeline-${var.environment}"
  retention_in_days = 30
  
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
