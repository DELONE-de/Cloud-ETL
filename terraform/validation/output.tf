output "glue_database_name" {
  value = aws_glue_catalog_database.cloud_etl_db.name
}

output "glue_table_name" {
  value = aws_glue_catalog_table.example_table.name
}

output "glue_crawler_name" {
  value = aws_glue_crawler.data_lake_raw_crawler.name
}

output "lambda_function_arn" {
  value = aws_lambda_function.data_processing.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.data_processing.function_name
}

output "processed_bucket_name" {
  value = aws_s3_bucket.processed.bucket
}

output "processed_bucket_arn" {
  value = aws_s3_bucket.processed.arn
}