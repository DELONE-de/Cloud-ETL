# S3 Access Policy
resource "aws_iam_policy" "s3_access_policy" {
  name = "${var.project_prefix}-${var.environment}-s3-access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      Resource = [
        "arn:aws:s3:::${var.project_prefix}-*",
        "arn:aws:s3:::${var.project_prefix}-*/*"
      ]
    }]
  })
}

# Kinesis Access Policy
resource "aws_iam_policy" "kinesis_access_policy" {
  name = "${var.project_prefix}-${var.environment}-kinesis-access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kinesis:DescribeStream",
        "kinesis:GetShardIterator",
        "kinesis:GetRecords",
        "kinesis:ListShards"
      ]
      Resource = "arn:aws:kinesis:*:*:stream/${var.project_prefix}-*"
    }]
  })
}

# CloudWatch Logs Policy
resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name = "${var.project_prefix}-${var.environment}-logs-access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}