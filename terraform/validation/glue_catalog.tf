resource "aws_glue_catalog_database" "cloud_etl_db" {
  name = var.catalog_db_name


  description = var.aws_catalog_description   #"Database for storing metadata about our raw data lake tables."

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_glue_catalog_table" "example_table" {
  name          = var.catalog_table_name
  database_name = aws_glue_catalog_database.cloud_etl_db.name

  storage_descriptor {
    location = "s3://${var.project_prefix}-processed-zone/Crop_recommedation.csv"

    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name = "ParquetSerDe"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    # Column definitions (the schema of your data)
    columns {
      name = "N"
      type = "integer"
      comment = "Nitrogen level of the soil sample."
    }
    columns {
      name = "P"
      type = "integer"
      comment = "Phosporus level of the soil sample."
    }
    columns {
      name = "K"
      type = "integer"
      comment = "Potassium level of the soil sample. "
    }
    columns {
      name = "Temperature"
      type = "float"
      comment = "Temprature of the soil"
    }
    columns {
      name = "Humidity"
      type = "float"
      comment = "Humidity of the soil"
    }
    columns {
      name = "ph"
      type = "float"
      comment = "the soil ph"
    }
    columns {
      name = "rainfall"
      type = "float"
      comment = "the amount of rainfall thesoil recievce"
    }
    columns {
      name =" label"
      type = "string"
      comment = "the crop label for the machine learning model"
    }

    parameters = {
      "has_encrypted_data" = "false"
      "projection.enabled" = "true"
    }
  }

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