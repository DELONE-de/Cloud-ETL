resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_prefix}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = var.lambda_error_threshold
  alarm_actions       = [aws_sns_topic.alerts.arn]

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


resource "aws_cloudwatch_log_stream" "etl_log_stream" {
  name           = "etl_log_stream"
  log_group_name = aws_cloudwatch_log_group.sfn_logs.name
}

resource "aws_cloudwatch_metric_alarm" "endpoint_errors" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.name_prefix}-endpoint-high-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Invocation5XXErrors"
  namespace           = "AWS/SageMaker"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors SageMaker endpoint 5XX errors"

  dimensions = {
    EndpointName = var.sagemaker_endpoint_name
    VariantName  = "AllTraffic"
  }

  tags = var.tags
}

