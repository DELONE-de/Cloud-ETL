import json
import csv
import boto3
import logging
from io import StringIO
from botocore.exceptions import ClientError

# Initialize Logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")

# Configuration
DESTINATION_BUCKET = "validated"

# Strict schema definition
REQUIRED_SCHEMA = {
    "N": {"type": int, "min": 0},
    "P": {"type": int, "min": 0},
    "K": {"type": int, "min": 0},
    "temperature": {"type": float, "min": -10, "max": 60},
    "humidity": {"type": float, "min": 0, "max": 100},
    "ph": {"type": float, "min": 0, "max": 14},
    "rainfall": {"type": float, "min": 0},
    "label": {"type": str, "non_empty": True},
}

def lambda_handler(event, context):
    """
    AWS Lambda function to validate a CSV dataset in S3.
    If valid, copies the file to the 'validated' bucket.
    """

    # 1. Extract bucket and object key from S3 event
    try:
        record = event["Records"][0]
        source_bucket = record["s3"]["bucket"]["name"]
        object_key = record["s3"]["object"]["key"]
        logger.info(f"Processing file: {object_key} from bucket: {source_bucket}")
    except (KeyError, IndexError):
        logger.error("Invalid S3 event structure")
        return _response("fail", "Invalid S3 event structure", 0, [])

    # 2. Fetch CSV file from S3
    try:
        obj = s3.get_object(Bucket=source_bucket, Key=object_key)
        csv_content = obj["Body"].read().decode("utf-8")
    except ClientError as e:
        logger.error(f"Error fetching file from S3: {e}")
        return _response("fail", f"Failed to read CSV: {str(e)}", 0, [])

    # 3. Parse CSV
    try:
        reader = csv.DictReader(StringIO(csv_content))
    except Exception as e:
         logger.error(f"CSV Parsing Failed: {e}")
         return _response("fail", "CSV Parsing Error", 0, [])

    # 4. Schema Validation (Fail Fast Logic)
    if reader.fieldnames is None:
        logger.error("Validation Failed: CSV file has no header row")
        return _response("fail", "CSV file has no header row", 0, [])

    missing_columns = [col for col in REQUIRED_SCHEMA.keys() if col not in reader.fieldnames]

    if missing_columns:
        error_msg = f"Missing required columns: {missing_columns}"
        logger.error(error_msg)
        return _response("fail", error_msg, 0, [{"column": c, "error": "Missing column"} for c in missing_columns])

    # 5. Row-Level Validation
    errors = []
    total_rows = 0

    for row_number, row in enumerate(reader, start=2):  # start=2 accounts for header
        total_rows += 1

        for column, rules in REQUIRED_SCHEMA.items():
            value = row.get(column)

            # Check: Missing or null
            if value is None or value.strip() == "":
                errors.append({"row": row_number, "column": column, "error": "Missing or null value"})
                continue

            # Check: Type conversion
            try:
                if rules["type"] == int:
                    parsed_value = int(value)
                elif rules["type"] == float:
                    parsed_value = float(value)
                else:
                    parsed_value = str(value)
            except ValueError:
                errors.append({"row": row_number, "column": column, "error": f"Invalid {rules['type'].__name__} value"})
                continue

            # Check: Range validation
            if rules["type"] in (int, float):
                if "min" in rules and parsed_value < rules["min"]:
                    errors.append({"row": row_number, "column": column, "error": f"Value below min ({rules['min']})"})
                if "max" in rules and parsed_value > rules["max"]:
                    errors.append({"row": row_number, "column": column, "error": f"Value above max ({rules['max']})"})

            # Check: String validation
            if rules["type"] == str and rules.get("non_empty") and not parsed_value.strip():
                errors.append({"row": row_number, "column": column, "error": "String cannot be empty"})

    # 6. Decision Logic
    if errors:
        # LOGGING REQUIREMENT: Log detailed errors to CloudWatch
        logger.error(f"Validation FAILED for {object_key}. Total Errors: {len(errors)}")
        for err in errors:
            logger.error(json.dumps(err))

        return _response("fail", "CSV validation failed", total_rows, errors)

    # 7. SAVE REQUIREMENT: Copy to validated bucket
    try:
        logger.info(f"Validation successful. Copying {object_key} to {DESTINATION_BUCKET}...")

        s3.copy_object(
            CopySource={'Bucket': source_bucket, 'Key': object_key},
            Bucket=DESTINATION_BUCKET,
            Key=object_key
        )
        logger.info(f"Successfully saved {object_key} to {DESTINATION_BUCKET}")

    except ClientError as e:
        logger.error(f"Failed to copy object to validated bucket: {e}")
        return _response("fail", f"S3 Copy Failed: {str(e)}", total_rows, [])

    return _response("pass", "File validated and saved successfully", total_rows, [])


def _response(status, message, total_rows, errors):
    """
    Helper function to generate a structured JSON response.
    """
    return {
        "statusCode": 200 if status == "pass" else 400,
        "body": json.dumps({
            "validation_status": status,
            "message": message,
            "total_rows_processed": total_rows,
            "errors": errors
        })
    }