output "stepfunctions_execution_role" {
  description = "Step Functions execution role details"
  value = {
    arn  = aws_iam_role.sfn_exec_role.arn
    name = aws_iam_role.sfn_exec_role.name
  }
}


output "s3_bucket_arn" {
  description = "ARN of the S3 bucket used by the pipeline"
  value       = "arn:aws:s3:::${var.s3_bucket_name}"
}

output "glue_job_arns" {
  description = "ARNs of Glue jobs that can be executed"
  value = [
    for job in var.glue_job_names : 
    "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:job/${job}"
  ]
}