resource "aws_scheduler_schedule" "weekly_pipeline_schedule" {
  name        = var.schedule_name
  description = "Weekly trigger for the ETL/Training Step Function Pipeline."

  # Runs weekly on Sunday (SUN) at 02:00 AM UTC
  schedule_expression = "cron(0 2 ? * SUN *)"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_sfn_state_machine.ml_pipeline.arn

    # The IAM Role the scheduler assumes to call StartExecution
    role_arn = var.scheduler_role

    # The input JSON for the Step Function execution.
    # We pass an empty object here as the Step Function uses its own logic for Glue/SageMaker.
    input = jsonencode({
      "source_trigger": "EventBridgeScheduler",
      "schedule_time_utc": "$aws.scheduler.scheduledTime"
    })

    # Configure retry behavior (optional, but highly recommended)
    retry_policy {
      maximum_retry_attempts     = 3
      maximum_event_age_in_seconds = var.maximum_event_age_in_seconds #3600
    }
  }
}