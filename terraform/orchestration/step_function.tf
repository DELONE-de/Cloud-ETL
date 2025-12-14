# --- DATA SOURCE (to get the Account ID for ARNs) ---

data "aws_caller_identity" "current" {}

# Terraform for Step Functions State Machine
resource "aws_sfn_state_machine" "ml_pipeline" {
  name     = "${var.project_name}-pipeline-${var.environment}"
  role_arn = aws_iam_role.sfn_exec_role.arn
  type     = "STANDARD"

  definition = templatefile("${path.module}/stepfunctions/definition.asl.json", {
    glue_job_name         = aws_glue_job.etl_pipeline.name
    sagemaker_role_arn    = var.sagemaker_exec_role_arn
    s3_bucket_name        = var.s3_bucket_name
    training_image        = "your-training-image-uri"
    instance_type         = "ml.m5.xlarge"
    region                = var.aws_region
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn_logs.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

output "step_function_arn" {
  description = "The ARN of the Step Function state machine."
  value       = aws_sfn_state_machine.etl_training_pipeline.arn
}