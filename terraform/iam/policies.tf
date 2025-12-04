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

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_prefix}-lambda-processing-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Read raw S3 data
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          var.raw_bucket_arn,
          "${var.raw_bucket_arn}/*"
        ]
      },
      # Write to processed bucket
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject"
        ],
        Resource = "${var.processed_bucket_arn}/*"
      },
      # Secrets Manager
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Resource = var.secret_arn
      },
      # Lambda logging
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })

}

resource "aws_iam_policy" "crawler_access_policy" {
  name        = "GlueCrawlerAccessPolicy"
  description = "Allows the Glue Crawler to read data and update the catalog."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Access to CloudWatch Logs
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:log-group:/aws-glue/*"
      },
      # S3 Access to the raw data location
      # !! IMPORTANT: Replace YOUR_RAW_DATA_BUCKET_NAME with your bucket !!
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Effect   = "Allow",
        Resource = [
          "arn:aws:s3:::YOUR_RAW_DATA_BUCKET_NAME",
          "arn:aws:s3:::YOUR_RAW_DATA_BUCKET_NAME/*"
        ]
      },
      # Glue Catalog Permissions (to create/update tables and databases)
      {
        Action   = "glue:*",
        Effect   = "Allow",
        Resource = "*"
      },
    ]
  })
}



resource "aws_iam_role_policy_attachment" "crawler_role_attachment" {
  role       = aws_iam_role.glue_crawler_role.name
  policy_arn = aws_iam_policy.crawler_access_policy.arn
}

resource "aws_iam_role_policy_attachment" "sfn_exec_policy" {
  role       = aws_iam_role.sfn_exec_role.name
  # This provides full access to Step Functions, Lambda, and other resources.
  # Adjust this ARN to a more restrictive policy based on your actual pipeline needs.
  policy_arn = "arn:aws:iam::aws:policy/AWSStepFunctionsFullAccess" 
}


resource "aws_iam_role_policy_attachment" "sfn_exec_policy" {
  role       = aws_iam_role.sfn_exec_role.name
  # This policy needs to be updated to include permissions for:
  # - glue:StartJobRun, glue:GetJobRun (for the Glue Task)
  # - sagemaker:CreateTrainingJob, sagemaker:DescribeTrainingJob (for the SageMaker Task)
  policy_arn = "arn:aws:iam::aws:policy/AWSStepFunctionsFullAccess" 
}