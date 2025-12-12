resource "aws_iam_role" "firehose_role" {
  name = "${var.project_prefix}-${var.environment}-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "firehose.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project     = var.project_prefix
    Environment = var.environment
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_prefix}-lambda-processing-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "glue_crawler_role" {
  name = "GlueCrawlerServiceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "glue.amazonaws.com" # The principal is the Glue service
        },
      },
    ],
  })
}

resource "aws_iam_role" "scheduler_exec_role" {
  name_prefix = "EBScheduler-SFN-Exec-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
      },
    ]
  })
}



resource "aws_iam_role" "sfn_exec_role" {
  name        = "${var.project_name}-sfn-exec-${var.environment}"
  description = "IAM role for Step Functions to orchestrate Glue ETL and SageMaker training jobs"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StepFunctionsAssumeRole"
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:states:${var.aws_region}:${data.aws_caller_identity.current.account_id}:stateMachine:*"
          }
        }
      }
    ]
  })
  
  tags = {
    Name        = "${var.project_name}-sfn-exec-role"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Component   = "StepFunctions"
  }
}



