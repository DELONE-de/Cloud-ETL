
# 1. Glue Job Resources
resource "aws_glue_job" "etl_pipeline" {
  name     = var.glue_job_names[0]
  role_arn = aws_iam_role.glue_execution_role.arn

  command {
    script_location = "s3://${var.s3_bucket_name}/scripts/etl_script.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"          = "python"
    "--TempDir"               = "s3://${var.s3_bucket_name}/temp/"
    "--job-bookmark-option"   = "job-bookmark-enable"
    "--enable-continuous-log-filter" = "true"
  }

  glue_version = "4.0"

  worker_type       = "G.1X"
  number_of_workers = 2
}