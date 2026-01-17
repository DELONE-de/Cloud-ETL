# --- DATA SOURCE (to get the Account ID for ARNs) ---

data "aws_caller_identity" "current" {}

# Terraform for Step Functions State Machine
resource "aws_sfn_state_machine" "ml_pipeline" {
  name     = "${var.project_name}-pipeline-${var.environment}"
  role_arn = var.sfn_exec_role_arn
  type     = "STANDARD"

  definition = templatefile("${path.module}/../../configs/definition.asl.json", {
    glue_job_name         = aws_glue_job.etl_pipeline.name
    sagemaker_role_arn    = var.sagemaker_exec_role_arn
    project_prefix         = var.project_prefix
    s3_bucket_name        = var.s3_bucket_name
    training_image        = var.training_image
    instance_type         = "ml.m5.xlarge"
    region                = var.region
    aws_account_id        = data.aws_caller_identity.current.account_id
    s3_code_bucket_name   = aws_s3_object.training_code.bucket
  })

  logging_configuration {
    log_destination        = "arn:aws:logs:us-east-1:364876732363:log-group:${var.sfn_logs_arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
