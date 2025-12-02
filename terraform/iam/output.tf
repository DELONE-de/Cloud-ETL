output "producer_role_arn" {
  value = aws_iam_role.producer_role.arn
}

output "firehose_role_arn" {
  value = aws_iam_role.firehose_role.arn
}

output "producer_policy_arn" {
  value = aws_iam_policy.producer_policy.arn
}

output "firehose_policy_arn" {
  value = aws_iam_policy.firehose_policy.arn
}