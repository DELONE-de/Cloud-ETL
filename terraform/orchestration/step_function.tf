resource "aws_sfn_state_machine" "etl_pipeline" {
  name     = "DailyETLPipeline"
  role_arn = aws_iam_role.sfn_exec_role.arn
  
  # The definition comes from the JSON file
  definition = file("state_machine_definition.json")
  
  tags = {
    Name = "DailyETL"
  }
}

