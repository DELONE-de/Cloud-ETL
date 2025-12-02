resource "aws_iam_policy" "producer_policy" {
  name        = "${var.project_prefix}-${var.environment}-producer-policy"
  description = "Allow producers to put records into the Kinesis data stream"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowPutToKinesis"
      Effect = "Allow"
      Action = [
        "kinesis:PutRecord",
        "kinesis:PutRecords"
      ]
      Resource = aws_kinesis_stream.ingest_stream.arn
    }]
  })
}


data "aws_iam_policy_document" "firehose_policy" {
  statement {
    sid    = "KinesisRead"
    effect = "Allow"
    actions = [
      "kinesis:DescribeStream",
      "kinesis:GetShardIterator",
      "kinesis:GetRecords",
      "kinesis:ListShards"
    ]
    resources = [aws_kinesis_stream.ingest_stream.arn]
  }

  statement {
    sid    = "S3Write"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      aws_s3_bucket.raw.arn,
      "${aws_s3_bucket.raw.arn}/*"
    ]
  }

  statement {
    sid    = "KMS"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]
    resources = [aws_kms_key.ingest.arn]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = ["arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"]
  }
}

data "aws_iam_policy_document" "s3_restrict_policy" {
  statement {
    sid    = "AllowFirehosePutObject"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.firehose_role.arn]
    }

    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]

    resources = [
      "${aws_s3_bucket.raw.arn}/*"
    ]
  }

  # optional: allow ListBucket/GetBucketLocation for Firehose role
  statement {
    sid    = "AllowListBucket"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.firehose_role.arn]
    }

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]

    resources = [
      aws_s3_bucket.raw.arn
    ]
  }
}

resource "aws_s3_bucket_policy" "raw_policy" {
  bucket = aws_s3_bucket.raw.id
  policy = data.aws_iam_policy_document.s3_restrict_policy.json
}