resource "aws_glue_crawler" "data_lake_raw_crawler" {
  name          = var.glue_crawler_name
  database_name = var.catalog_db_name
  role          = var.glue_crawler_role_arn


  schedule = "cron(0 0 * * ? *)"

  s3_target {

    path = "s3://${var.project_prefix}-processed-zone/Crop_recommedation.csv"

  }


  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  configuration = jsonencode({
    "Grouping" = {
      "TableGroupingPolicy" = "CombineCompatibleSchemas"
      "TableLevelConfiguration" = 3
    }
  })

  tags = {
    Automation = "Crawler"
    DataTier   = "Raw"
  }
}