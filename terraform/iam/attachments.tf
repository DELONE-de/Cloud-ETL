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


resource "aws_iam_role_policy_attachment" "sfn_core_policy" {
  role       = aws_iam_role.sfn_exec_role.name
  policy_arn = aws_iam_policy.sfn_core_pipeline_policy.arn
}

resource "aws_iam_role_policy_attachment" "sfn_s3_access" {
  role       = aws_iam_role.sfn_exec_role.name
  policy_arn = aws_iam_policy.sfn_s3_access_policy.arn
}

resource "aws_iam_role_policy_attachment" "sfn_cloudwatch_logs" {
  role       = aws_iam_role.sfn_exec_role.name
  policy_arn = aws_iam_policy.sfn_cloudwatch_logs_policy.arn
}

# Optional: AWS Managed Policies for additional permissions
resource "aws_iam_role_policy_attachment" "sfn_cloudwatch_readonly" {
  role       = aws_iam_role.sfn_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

# 2c. Attach S3 Policy to Role
resource "aws_iam_role_policy_attachment" "s3_access_attach" {
  role       = aws_iam_role.sagemaker_packager_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}