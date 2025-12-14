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
    EndpointName = aws_sagemaker_endpoint.main.name
    VariantName  = "AllTraffic"
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${aws_api_gateway_rest_api.insurance_api.name}"
  retention_in_days = 30

  tags = var.tags
}