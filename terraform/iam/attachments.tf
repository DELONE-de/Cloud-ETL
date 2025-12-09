# -----------------------------------------------------------
# POLICY ATTACHMENTS
# -----------------------------------------------------------

resource "aws_iam_role_policy_attachment" "producer_attach" {
  role       = aws_iam_role.producer_role.name
  policy_arn = aws_iam_policy.producer_policy.arn
}

resource "aws_iam_role_policy_attachment" "firehose_attach" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_policy.arn
}


resource "aws_iam_role_policy_attachment" "scheduler_sfn_attach" {
  role       = aws_iam_role.scheduler_exec_role.name
  policy_arn = aws_iam_policy.scheduler_sfn_policy.arn
}