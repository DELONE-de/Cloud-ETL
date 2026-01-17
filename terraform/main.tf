data "aws_caller_identity" "current" {}

module "ingestion" {
    source = "./ingestion"

    account_id = data.aws_caller_identity.current.account_id
    project_name = var.project_name
    project_prefix = var.project_prefix
    environment = var.environment
    kinesis_shard_count = var.kinesis_shard_count
    kinesis_retention_hours = var.kinesis_retention_hours
    firehose_buffer_interval_seconds = var.firehose_buffer_interval_seconds
    firehose_buffer_size_mb = var.firehose_buffer_size_mb
    s3_bucket_acl = var.s3_bucket_acl
    s3_lifecycle_transition_days = var.s3_lifecycle_transition_days
    log_group_name = module.observability.aws_cloudwatch_log_group_sfn_logs_name
    log_stream_name = "S3Delivery"
    firehose_role_arn = module.iam.firehose_role_arn
    firehose_attach = module.iam.firehose_attach
    firehose_s3_attach = module.iam.firehose_s3_attach
    firehose_kinesis_attach = module.iam.firehose_kinesis_attach
    firehose_logs_attach = module.iam.firehose_logs_attach
}

module "validation" {
    source = "./validation"
    project_prefix = var.project_prefix
    account_id = data.aws_caller_identity.current.account_id
    environment = var.environment
    aws_catalog_description  = var.aws_catalog_description
    catalog_table_name = "${var.project_prefix}-catalog-table"
    glue_crawler_name = "${var.project_prefix}-crawler"
    catalog_db_name = "${var.project_prefix}-catalog-db"
    project = var.project_name
    raw_bucket_arn = module.ingestion.s3_bucket_arn
    raw_bucket = module.ingestion.s3_raw_bucket
    processed_bucket = module.validation.processed_bucket_name
    lambda_package = var.lambda_package
    glue_crawler_role_arn = module.iam.glue_crawler_role_arn
    lambda_role_arn = module.iam.lambda_role_arn
    handler = var.handler
    runtime = var.runtime
    timeout = var.timeout
    memory_size = var.memory_size
}


module "iam" {
    source = "./iam"
    project_prefix = var.project_prefix
    environment = var.environment
}

module "observability" {
    source = "./observability"
    validation_lambda_name = "${var.project_prefix}-validation-lambda"
    project_prefix = var.project_prefix
    project_name = var.project_name
    environment = var.environment
    name_prefix = var.project_prefix
}

module "orchestration" {
    source = "./orchestration"
    environment = var.environment
    glue_job_names = var.glue_job_name
    project_name = var.project_name
    s3_bucket_name = "${var.project_prefix}-etl-bucket"
    scheduler_role = module.iam.scheduler_exec_role_arn
    maximum_event_age_in_seconds = 3
    glue_execution_role_arn = module.iam.glue_execution_role_arn
    sfn_exec_role_arn = module.iam.sfn_exec_role_arn
    sfn_logs_arn = module.observability.aws_cloudwatch_log_group_sfn_logs_name
    model_artifacts_bucket = "${var.project_prefix}-model-artifacts"
    training_image = var.training_image
    project_prefix = var.project_prefix
}





