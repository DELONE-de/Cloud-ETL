# AWS Glue ETL Job: Crop Recommendation Data Preprocessing
# Glue Version: 4.0+
# Language: PySpark
# Purpose: Convert local pandas-based ML preprocessing into a scalable Glue ETL pipeline

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql import functions as F
from pyspark.sql.types import (
    IntegerType, DoubleType
)
from pyspark.ml import Pipeline
from pyspark.ml.feature import VectorAssembler, MinMaxScaler

# --------------------------------------------------------------------------------
# Job parameters
# --------------------------------------------------------------------------------
args = getResolvedOptions(
    sys.argv,
    ["JOB_NAME", "SOURCE_S3_PATH", "TARGET_S3_PATH"]
)

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

# --------------------------------------------------------------------------------
# Read CSV data from S3 (no pandas)
# --------------------------------------------------------------------------------
df = spark.read.format("csv") \
    .option("header", "true") \
    .option("inferSchema", "true") \
    .load(args["SOURCE_S3_PATH"])

# --------------------------------------------------------------------------------
# Data validation & cleaning
# --------------------------------------------------------------------------------

# Drop rows with null values
df = df.dropna()

# Remove duplicate rows
df = df.dropDuplicates()

# Enforce correct data types explicitly
numeric_columns = [
    "N", "P", "K", "temperature", "humidity", "ph", "rainfall"
]

for col in numeric_columns:
    df = df.withColumn(col, F.col(col).cast(DoubleType()))

df = df.withColumn("label", F.col("label").cast("string"))

# --------------------------------------------------------------------------------
# Feature engineering: label encoding using fixed dictionary
# --------------------------------------------------------------------------------
label_mapping = {
    "rice": 1, "maize": 2, "jute": 3, "cotton": 4, "coconut": 5,
    "papaya": 6, "orange": 7, "apple": 8, "muskmelon": 9,
    "watermelon": 10, "grapes": 11, "mango": 12, "banana": 13,
    "pomegranate": 14, "lentil": 15, "blackgram": 16,
    "mungbean": 17, "mothbeans": 18, "pigeonpeas": 19,
    "kidneybeans": 20, "chickpea": 21, "coffee": 22
}

mapping_expr = F.create_map(
    *[F.lit(x) for kv in label_mapping.items() for x in kv]
)

df = df.withColumn("label_num", mapping_expr[F.col("label")])

# Drop original string label
df = df.drop("label")

# --------------------------------------------------------------------------------
# Assemble features (no train/test split in Glue)
# --------------------------------------------------------------------------------
feature_columns = [
    "N", "P", "K", "temperature", "humidity", "ph", "rainfall"
]

assembler = VectorAssembler(
    inputCols=feature_columns,
    outputCol="features"
)

# --------------------------------------------------------------------------------
# Feature scaling using Spark ML (MinMaxScaler)
# --------------------------------------------------------------------------------
scaler = MinMaxScaler(
    inputCol="features",
    outputCol="scaled_features"
)

pipeline = Pipeline(stages=[assembler, scaler])

pipeline_model = pipeline.fit(df)
scaled_df = pipeline_model.transform(df)

# --------------------------------------------------------------------------------
# Final dataset selection
# --------------------------------------------------------------------------------
final_df = scaled_df.select(
    "scaled_features",
    F.col("label_num").cast(IntegerType()).alias("label")
)

# --------------------------------------------------------------------------------
# Write transformed dataset to S3 in Parquet format
# --------------------------------------------------------------------------------
final_df.write.mode("overwrite") \
    .format("parquet") \
    .save(args["TARGET_S3_PATH"])

# --------------------------------------------------------------------------------
# Commit Glue job
# --------------------------------------------------------------------------------
job.commit()
