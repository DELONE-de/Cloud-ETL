resource "aws_scheduler_schedule" "weekly_pipeline_schedule" {
  name        = var.schedule_name
  description = "Weekly trigger for the ETL/Training Step Function Pipeline."

  # Runs weekly on Sunday (SUN) at 02:00 AM UTC
  schedule_expression = "cron(0 2 ? * SUN *)"

  # Note: flexible_time_window is required, setting to OFF for exact timing.
  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = var.step_function_arn

    # The IAM Role the scheduler assumes to call StartExecution
    role_arn = aws_iam_role.scheduler_exec_role.arn

    # The input JSON for the Step Function execution.
    # We pass an empty object here as the Step Function uses its own logic for Glue/SageMaker.
    input = jsonencode({
      "source_trigger": "EventBridgeScheduler",
      "schedule_time_utc": "$aws.scheduler.scheduledTime"
    })

    # Configure retry behavior (optional, but highly recommended)
    retry_policy {
      maximum_retry_attempts     = 3
      maximum_event_age_in_seconds = 3600 # 1 hour
    }
  }
}