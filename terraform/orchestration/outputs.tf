output "step_function_arn" {
  description = "The ARN of the Step Function state machine."
  value       = aws_sfn_state_machine.ml_pipeline.arn
}

output "EventBridge_arn" {
  value = aws_scheduler_schedule.weekly_pipeline_schedule.arn
}

output "glue_jobs_arn" {
  value = aws_glue_job.etl_pipeline.arn
}

output "etl_script_bucket_arn" {
  value = aws_s3_object.etl_script.arn
}

output "training_script_bucket_arn" {
  value = aws_s3_object.training_script.arn
}