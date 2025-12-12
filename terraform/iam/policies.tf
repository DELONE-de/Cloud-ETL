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



resource "aws_iam_policy" "scheduler_sfn_policy" {
  name_prefix = "EBScheduler-SFN-Invoke-"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "states:StartExecution"
        Resource = [
          # Allows the scheduler to start the specified Step Function
          var.step_function_arn,
        ]
      },
    ]
  })
}



resource "aws_iam_policy" "sfn_core_pipeline_policy" {
  name        = "${var.project_name}-sfn-core-policy-${var.environment}"
  description = "Core permissions for Step Functions to orchestrate ETL and ML pipeline"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Glue Job Permissions (sync execution)
      {
        Sid       = "GlueJobExecutionSync"
        Effect    = "Allow"
        Action    = [
          "glue:StartJobRun",
          "glue:GetJobRun",     # Required for .sync pattern
          "glue:GetJobRuns",
          "glue:GetJob",
          "glue:GetJobs",
          "glue:BatchStopJobRun"
        ]
        Resource = [
          # Specific Glue jobs
          "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:job/*"
        ]
        Condition = {
          StringEqualsIfExists = {
            "glue:jobName" = var.glue_job_names
          }
        }
      },
      
      # SageMaker Training Job Permissions
      {
        Sid       = "SageMakerTrainingJobManagement"
        Effect    = "Allow"
        Action    = [
          "sagemaker:CreateTrainingJob",
          "sagemaker:DescribeTrainingJob",  # Required for .sync pattern
          "sagemaker:StopTrainingJob",
          "sagemaker:ListTrainingJobs",
          "sagemaker:AddTags",
          "sagemaker:listTags"
        ]
        Resource = [
          "arn:aws:sagemaker:${var.aws_region}:${data.aws_caller_identity.current.account_id}:training-job/*"
        ]
        Condition = {
          StringLike = {
            "sagemaker:TrainingJobName" = [
              for prefix in var.allowed_sagemaker_training_prefixes : "${prefix}*"
            ]
          }
        }
      },
      
      # IAM PassRole for SageMaker Execution Role
      {
        Sid       = "PassRoleToSageMaker"
        Effect    = "Allow"
        Action    = "iam:PassRole"
        Resource  = var.sagemaker_exec_role_arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "sagemaker.amazonaws.com"
          }
        }
      },
      
      # Step Functions Execution Management
      {
        Sid       = "StepFunctionsSelfManagement"
        Effect    = "Allow"
        Action    = [
          "states:StartExecution",
          "states:DescribeExecution",
          "states:StopExecution",
          "states:GetExecutionHistory"
        ]
        Resource = "arn:aws:states:${var.aws_region}:${data.aws_caller_identity.current.account_id}:execution:*"
      }
    ]
      })
  
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# --- 3. S3 Data Access Policy ---

resource "aws_iam_policy" "sfn_s3_access_policy" {
  name        = "${var.project_name}-sfn-s3-access-${var.environment}"
  description = "S3 permissions for Step Functions pipeline data access"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Read/Write access to specific S3 bucket
      {
        Sid       = "S3DataBucketAccess"
        Effect    = "Allow"
        Action    = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion",
          "s3:PutObjectAcl"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      },
      {
        Sid       = "S3DataBucketList"
        Effect    = "Allow"
        Action    = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}"
        ]
      }
    ]
  })
   tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}


resource "aws_iam_policy" "sfn_cloudwatch_logs_policy" {
  name        = "${var.project_name}-sfn-logs-policy-${var.environment}"
  description = "CloudWatch Logs permissions for Step Functions execution"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "CloudWatchLogsWrite"
        Effect    = "Allow"
        Action    = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/states/${var.project_name}-:log-stream:",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/vendedlogs/states/${var.project_name}-:log-stream:"
        ]
      },
      {
        Sid       = "CloudWatchLogsRead"
        Effect    = "Allow"
        Action    = [
          "logs:DescribeLogGroups",
          "logs:GetLogEvents"
        ]
        Resource = "*"  # These are non-resource-specific actions
      }
    ]
  })
  
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}



