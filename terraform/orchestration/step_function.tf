# --- DATA SOURCE (to get the Account ID for ARNs) ---

data "aws_caller_identity" "current" {}

# --- 2. Step Function State Machine ---

resource "aws_sfn_state_machine" "etl_training_pipeline" {
  name     = "ETL-ModelTraining-Pipeline"
  role_arn = aws_iam_role.sfn_exec_role.arn
  type     = "STANDARD"

  definition = jsonencode({
    Comment = "Weekly ETL and SageMaker Model Training Pipeline",
    StartAt = "StartGlueETL",
    States = {
      StartGlueETL = {
        Type = "Task",
        Resource = "arn:aws:states:::glue:startJobRun.sync",
        Parameters = {
          JobName = "etl-pipeline"
        },
        Catch = [
          {
            ErrorEquals = ["States.TaskFailed"],
            Next        = "ETL_Failed"
          }
        ],
        Next = "StartSageMakerTraining"
      },
      StartSageMakerTraining = {
        Type = "Task",
        Resource = "arn:aws:states:::sagemaker:createTrainingJob",
        Parameters = {
          # Use a dynamic name based on the Step Function execution ID
          "TrainingJobName.$" = "States.Format('training-job-{}', $$.Execution.Id)",
          RoleArn             = var.sagemaker_exec_role_arn,
          HyperParameters = {
            "max_depth" = "5",
            "eta"       = "0.2"
          },
          AlgorithmSpecification = {
            # **NOTE**: Update this with the correct ECR URI for your region and algorithm version.
            # Example (XGBoost, us-east-1, v1.0-1): 811284229777.dkr.ecr.us-east-1.amazonaws.com/xgboost:1.0-1
            TrainingImage = "811284229777.dkr.ecr.us-east-1.amazonaws.com/xgboost:1.0-1"
            TrainingInputMode = "File"
          },
          InputDataConfig = [
            {
              ChannelName = "train",
              DataSource = {
                S3DataSource = {
                  S3DataType = "S3Prefix",
                  # Path where Glue output data: s3://YOUR_BUCKET_NAME/dataset/
                  "S3Uri" = "s3://${var.s3_bucket_name}/dataset/",
                  S3DataDistributionType = "FullyReplicated"
                }
              },
              ContentType = "text/csv"
            }
          ],
          OutputDataConfig = {
            # S3 location to store the final model artifact
            "S3OutputPath" = "s3://${var.s3_bucket_name}/models/"
          },
          ResourceConfig = {
            InstanceCount = 1,
            # <--- UPDATE InstanceType HERE
            InstanceType = "ml.m5.xlarge", 
            VolumeSizeInGB = 10
          },
          StoppingCondition = {
            MaxRuntimeInSeconds = 3600 # 1 hour
          }
        },
        End = true
      },
      ETL_Failed = {
        Type = "Fail",
        Cause = "The AWS Glue ETL job failed to complete.",
        Error = "ETLJobFailed"
      }
    }
  })
}

# --- OUTPUT (for the EventBridge Scheduler code) ---

output "step_function_arn" {
  description = "The ARN of the Step Function state machine."
  value       = aws_sfn_state_machine.etl_training_pipeline.arn
}