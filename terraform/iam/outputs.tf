output "firehose_role_arn" {
  value = aws_iam_role.firehose_role.arn
}


output "glue_execution_role_arn" {
  value = aws_iam_role.glue_execution_role.arn
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda_role.arn
}

output "sagemaker_execution_role_arn" {
  value = aws_iam_role.sagemaker_execution_role.arn
}

output "sfn_exec_role_arn" {
  value = aws_iam_role.sfn_exec_role.arn
}

output "scheduler_exec_role_arn" {
  value = aws_iam_role.scheduler_exec_role.arn
}

output "glue_crawler_role_arn" {
  value = aws_iam_role.glue_crawler_role.arn
}

output "firehose_attach" {
  value = aws_iam_role_policy_attachment.firehose_attach
}

output "firehose_s3_attach" {
  value = aws_iam_role_policy_attachment.firehose_s3_attach
}

output "firehose_kinesis_attach" {
  value = aws_iam_role_policy_attachment.firehose_kinesis_attach
}

output "firehose_logs_attach" {
  value = aws_iam_role_policy_attachment.firehose_logs_attach
}

