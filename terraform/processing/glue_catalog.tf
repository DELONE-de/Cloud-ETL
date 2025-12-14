resource "aws_glue_catalog_database" "example_database" {
  name = "example_data_lake_db"

  # Optional: Description for clarity
  description = "Database for storing metadata about our raw data lake tables."

  # Optional: Default location in S3 for tables in this database
  # If tables do not specify a location, they default to this path.
  # !! IMPORTANT: Replace YOUR_S3_BUCKET_NAME with your actual bucket name !!
  # Note the trailing slash is important for S3 prefixes.
  location_uri = "s3://YOUR_S3_BUCKET_NAME/data_lake/databases/example_data_lake_db/"

  # Tags are always a good practice
  tags = {
    Environment = "Dev"
    Project     = "DataCatalogSetup"
  }
}

resource "aws_glue_catalog_table" "example_table" {
  name          = "user_events_raw"
  database_name = aws_glue_catalog_database.example_database.name

  # Storage Descriptor defines the data location, format, and schema
  storage_descriptor {
    # !! IMPORTANT: Replace YOUR_S3_BUCKET_NAME with your actual bucket name !!
    location = "s3://YOUR_S3_BUCKET_NAME/data_lake/raw/user_events/"

    # Input/Output formats define how the data is read and written (e.g., Parquet, CSV, JSON)
    # Using Parquet is recommended for performance and compression.
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    # Serde (Serializer/Deserializer) used to read the data format
    # Parquet uses this specific Serde
    serd_info {
      name = "ParquetSerDe"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    # Column definitions (the schema of your data)
    columns {
      name = "user_id"
      type = "string" # Data type in the data lake (e.g., string, int, bigint, double)
      comment = "Unique identifier for the user."
    }
    columns {
      name = "event_type"
      type = "string"
      comment = "The type of event logged (e.g., 'click', 'view')."
    }
    columns {
      name = "event_timestamp"
      type = "bigint"
      comment = "The time the event occurred (Unix epoch time in ms)."
    }
    columns {
      name = "data_json"
      type = "string"
      comment = "Raw JSON data payload for the event."
    }

    # Parameters can store additional metadata about the table
    parameters = {
      "has_encrypted_data" = "false"
      "projection.enabled" = "true" # Example parameter for Athena performance
    }
  }

  # Partition Keys define how your data is physically segmented in S3
  # These columns MUST NOT be defined in the 'columns' block above.
  partition_keys {
    name = "year"
    type = "string"
    comment = "Partition key: Year of the event."
  }
  partition_keys {
    name = "month"
    type = "string"
    comment = "Partition key: Month of the event."
  }
  partition_keys {
    name = "day"
    type = "string"
    comment = "Partition key: Day of the event."
  }
}