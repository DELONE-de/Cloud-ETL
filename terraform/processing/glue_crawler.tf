resource "aws_glue_crawler" "data_lake_raw_crawler" {
  name          = "data_lake_raw_s3_crawler"
  # Target database where the tables will be created
  database_name = "example_data_lake_db" # Assumes this database exists from your first request
  role          = aws_iam_role.glue_crawler_role.arn

  # Schedule: Run every day at 00:00 UTC (midnight)
  schedule = "cron(0 0 * * ? *)"

  # The target data source (S3 in this case)
  s3_target {
    # The starting path for the crawler to look for data
    # This path is usually the root of your raw data.
    # !! IMPORTANT: Replace YOUR_RAW_DATA_BUCKET_NAME with your bucket name !!
    path = "s3://YOUR_RAW_DATA_BUCKET_NAME/data_lake/raw/"

    # Optional: Exclude certain files or folders (e.g., temporary files)
    exclusions = [
      "**/_temporary/**",
      "**/.DS_Store"
    ]
  }

  # Define how the crawler handles changes it finds
  schema_change_policy {
    # If the crawler finds a new column, update the table definition.
    update_behavior = "UPDATE_IN_DATABASE"
    # If the crawler finds that a table/partition is no longer present, log it (don't delete it automatically).
    delete_behavior = "LOG"
  }

  # Configuration settings in JSON format
  configuration = jsonencode({
    "Grouping" = {
      # Grouping policy dictates how folders are translated into Glue Tables.
      # For a large data lake, use a high TableLevel for finer control.
      "TableGroupingPolicy" = "CombineCompatibleSchemas"
      "TableLevelConfiguration" = 3 # Treat S3://bucket/data_lake/raw/<table_name>/ as the table level
    }
  })

  tags = {
    Automation = "Crawler"
    DataTier   = "Raw"
  }
}