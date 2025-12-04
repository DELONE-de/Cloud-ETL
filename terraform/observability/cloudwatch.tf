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

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.project_prefix}-lambda-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = var.lambda_throttle_threshold
  alarm_actions       = [var.alarm_sns_topic_arn]

  dimensions = {
    FunctionName = var.validation_lambda_name
  }
}

resource "aws_cloudwatch_event_rule" "daily_schedule_rule" {
  name                = "Daily-ETL-Scheduler-Rule"
  description         = "Triggers the ETL Step Function daily at 02:00 AM UTC"
  # Cron expression: (minute hour day-of-month month day-of-week year)
  schedule_expression = "cron(0 2 * * ? *)" 
  is_enabled          = true
}

resource "aws_cloudwatch_event_target" "sfn_target" {
  rule      = aws_cloudwatch_event_rule.daily_schedule_rule.name
  target_id = "StepFunctionsTarget"
  arn       = aws_sfn_state_machine.etl_pipeline.id
  
  # The input is optional but allows you to pass JSON data to the state machine execution
  input = jsonencode({
    start_time = "$${time.rfc3339}", # Example of passing dynamic time
    pipeline   = "daily_etl"
  })
}

resource "aws_lambda_permission" "allow_eventbridge_to_sfn" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "states:StartExecution"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_schedule_rule.arn

}


