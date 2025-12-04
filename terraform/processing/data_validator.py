import json
import boto3
import logging
import pandas as pd
import io
import os
from datetime import datetime
from typing import Dict, List, Tuple, Optional
import numpy as np

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3 = boto3.client("s3")
secrets = boto3.client("secretsmanager")

# Environment variables
PROCESSED_BUCKET = os.environ.get("PROCESSED_S3_BUCKET")
SECRET_ARN = os.environ.get("SECRET_ARN")
ERROR_BUCKET = os.environ.get("ERROR_BUCKET", "")  # Optional error bucket

# Expected schema
EXPECTED_FIELDS = ["age", "sex", "bmi", "children", "smoker", "region", "charges"]

class DataProcessor:
    """Main data processing class with validation and transformation logic"""
    
    def __init__(self, secret_config: Optional[Dict] = None):
        self.secret_config = secret_config or {}
        self.processed_count = 0
        self.error_count = 0
        self.validation_rules = self._load_validation_rules()
        
    def _load_validation_rules(self) -> Dict:
        """Load validation rules from config or defaults"""
        return {
            "age": {"min": 18, "max": 100, "type": "int"},
            "bmi": {"min": 10.0, "max": 80.0, "type": "float"},
            "children": {"min": 0, "max": 10, "type": "int"},
            "sex": {"allowed": ["male", "female"]},
            "smoker": {"allowed": ["yes", "no"]},
            "region": {"allowed": ["northeast", "northwest", "southeast", "southwest"]}
        }
    
    def validate_field(self, field_name: str, value: str) -> Tuple[bool, Optional[str]]:
        """Validate a single field based on rules"""
        if field_name not in self.validation_rules:
            return True, None  # No validation rules for this field
            
        rules = self.validation_rules[field_name]
        
        try:
            if rules.get("type") == "int":
                int_val = int(value)
                if "min" in rules and int_val < rules["min"]:
                    return False, f"{field_name}_below_min"
                if "max" in rules and int_val > rules["max"]:
                    return False, f"{field_name}_above_max"
                    
            elif rules.get("type") == "float":
                float_val = float(value)
                if "min" in rules and float_val < rules["min"]:
                    return False, f"{field_name}_below_min"
                if "max" in rules and float_val > rules["max"]:
                    return False, f"{field_name}_above_max"
                    
            elif "allowed" in rules:
                if str(value).lower() not in rules["allowed"]:
                    return False, f"{field_name}_invalid_value"
                    
        except (ValueError, TypeError):
            return False, f"{field_name}_invalid_type"
            
        return True, None
    
    def transform_record(self, record: Dict) -> Dict:
        """Apply business transformations to a valid record"""
        transformed = record.copy()
        
        # Ensure correct data types
        transformed["age"] = int(float(record["age"]))
        transformed["bmi"] = round(float(record["bmi"]), 2)
        transformed["children"] = int(float(record["children"]))
        transformed["charges"] = round(float(record["charges"]), 2)
        
        # Standardize string fields
        transformed["sex"] = record["sex"].lower().strip()
        transformed["smoker"] = record["smoker"].lower().strip()
        transformed["region"] = record["region"].lower().strip()
        
        # Add derived features
        bmi = float(record["bmi"])
        if bmi >= 30:
            transformed["bmi_category"] = "obese"
        elif bmi >= 25:
            transformed["bmi_category"] = "overweight"
        else:
            transformed["bmi_category"] = "normal"
        
        # Add metadata
        transformed["processed_at"] = datetime.utcnow().isoformat() + "Z"
        transformed["processing_id"] = f"proc_{int(datetime.utcnow().timestamp())}"
        
        return transformed
    
    def process_record(self, record: Dict) -> Tuple[bool, Optional[Dict], Optional[str]]:
        """Validate and transform a single record"""
        # Check required fields
        missing_fields = [f for f in EXPECTED_FIELDS if f not in record]
        if missing_fields:
            return False, None, f"missing_fields:{','.join(missing_fields)}"
        
        # Validate each field
        errors = []
        for field in EXPECTED_FIELDS:
            if field in record and record[field] is not None:
                is_valid, error = self.validate_field(field, str(record[field]))
                if not is_valid:
                    errors.append(error)
        
        if errors:
            return False, None, f"validation_errors:{','.join(errors)}"
        
        # Transform if valid
        transformed = self.transform_record(record)
        return True, transformed, None
    
    def process_dataframe(self, df: pd.DataFrame) -> Tuple[pd.DataFrame, pd.DataFrame]:
        """Process an entire dataframe, separating valid and invalid records"""
        valid_records = []
        error_records = []
        
        for idx, row in df.iterrows():
            record = row.to_dict()
            is_valid, transformed, error = self.process_record(record)
            
            if is_valid:
                valid_records.append(transformed)
            else:
                error_record = record.copy()
                error_record["_error"] = error
                error_record["_row"] = int(idx)
                error_records.append(error_record)
        
        valid_df = pd.DataFrame(valid_records) if valid_records else pd.DataFrame()
        error_df = pd.DataFrame(error_records) if error_records else pd.DataFrame()
        
        self.processed_count = len(valid_records)
        self.error_count = len(error_records)
        
        return valid_df, error_df

def get_secret() -> Optional[Dict]:
    """Fetch secrets from AWS Secrets Manager"""
    if not SECRET_ARN:
        logger.info("No SECRET_ARN configured, using defaults")
        return None
    
    try:
        response = secrets.get_secret_value(SecretId=SECRET_ARN)
        secret_string = response.get("SecretString", "{}")
        return json.loads(secret_string)
    except Exception as e:
        logger.error(f"Failed to fetch secret: {str(e)}")
        return None

def read_file_from_s3(bucket: str, key: str) -> pd.DataFrame:
    """Read different file formats from S3"""
    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        file_content = response["Body"].read()
        
        # Determine file type by extension
        if key.lower().endswith('.csv'):
            df = pd.read_csv(io.BytesIO(file_content))
        elif key.lower().endswith('.json'):
            df = pd.read_json(io.BytesIO(file_content))
        elif key.lower().endswith('.parquet'):
            df = pd.read_parquet(io.BytesIO(file_content))
        else:
            # Try CSV by default
            df = pd.read_csv(io.BytesIO(file_content))
            
        logger.info(f"Successfully read {len(df)} records from {key}")
        return df
        
    except Exception as e:
        logger.error(f"Failed to read file {key} from S3: {str(e)}")
        raise

def write_to_s3(df: pd.DataFrame, bucket: str, key: str, file_format: str = 'parquet'):
    """Write dataframe to S3 in specified format"""
    try:
        buffer = io.BytesIO()
        
        if file_format.lower() == 'parquet':
            df.to_parquet(buffer, index=False)
            content_type = 'application/parquet'
        elif file_format.lower() == 'json':
            df.to_json(buffer, orient='records', lines=True)
            content_type = 'application/json'
        elif file_format.lower() == 'csv':
            df.to_csv(buffer, index=False)
            content_type = 'text/csv'
        else:
            raise ValueError(f"Unsupported file format: {file_format}")
        
        buffer.seek(0)
        s3.put_object(
            Bucket=bucket,
            Key=key,
            Body=buffer,
            ContentType=content_type
        )
        logger.info(f"Successfully wrote {len(df)} records to s3://{bucket}/{key}")
        
    except Exception as e:
        logger.error(f"Failed to write to S3: {str(e)}")
        raise

def generate_output_paths(input_key: str) -> Dict[str, str]:
    """Generate output paths based on input file and processing date"""
    # Extract filename without extension
    filename = os.path.basename(input_key)
    name_without_ext = os.path.splitext(filename)[0]
    
    # Current date for partitioning
    current_date = datetime.utcnow()
    date_path = current_date.strftime("%Y/%m/%d")
    timestamp = current_date.strftime("%Y%m%d_%H%M%S")
    
    # Generate paths
    paths = {
        "processed": f"processed/{date_path}/{name_without_ext}_{timestamp}.parquet",
        "errors": f"errors/{date_path}/{name_without_ext}_{timestamp}_errors.parquet",
        "archive": f"archive/{date_path}/{name_without_ext}_{timestamp}.parquet"
    }
    
    return paths

def process_s3_event(event: Dict, context) -> Dict:
    """Main Lambda handler for S3 events"""
    # Initialize counters
    stats = {
        "total_records": 0,
        "processed_records": 0,
        "error_records": 0,
        "input_files": 0,
        "output_files": []
    }
    
    # Get secret configuration
    secret_config = get_secret()
    processor = DataProcessor(secret_config)
    
    # Process each S3 record in the event
    for s3_record in event.get("Records", []):
        try:
            # Extract S3 bucket and key
            bucket = s3_record["s3"]["bucket"]["name"]
            key = s3_record["s3"]["object"]["key"]
            
            logger.info(f"Processing file: s3://{bucket}/{key}")
            stats["input_files"] += 1
            
            # Read the input file
            input_df = read_file_from_s3(bucket, key)
            stats["total_records"] += len(input_df)
            
            # Process the data
            valid_df, error_df = processor.process_dataframe(input_df)
            
            # Generate output paths
            paths = generate_output_paths(key)
            
            # Write processed data
            if not valid_df.empty:
                write_to_s3(
                    valid_df, 
                    PROCESSED_BUCKET, 
                    paths["processed"],
                    file_format="parquet"
                )
                stats["processed_records"] += len(valid_df)
                stats["output_files"].append(f"s3://{PROCESSED_BUCKET}/{paths['processed']}")
            
            # Write error data (if any and error bucket configured)
            if not error_df.empty and ERROR_BUCKET:
                write_to_s3(
                    error_df,
                    ERROR_BUCKET,
                    paths["errors"],
                    file_format="parquet"
                )
                stats["error_records"] += len(error_df)
                stats["output_files"].append(f"s3://{ERROR_BUCKET}/{paths['errors']}")
            
            # Archive original file (optional)
            if secret_config.get("archive_original", False):
                write_to_s3(
                    input_df,
                    PROCESSED_BUCKET,
                    paths["archive"],
                    file_format="parquet"
                )
            
            logger.info(f"Completed processing {key}: {len(valid_df)} valid, {len(error_df)} errors")
            
        except Exception as e:
            logger.error(f"Failed to process S3 record: {str(e)}")
            # Optionally, you could move the failed file to a quarantine location
    
    # Return processing statistics
    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Processing completed",
            "statistics": stats,
            "timestamp": datetime.utcnow().isoformat() + "Z"
        })
    }

def lambda_handler(event, context):
    """AWS Lambda entry point"""
    try:
        # Log the incoming event (sanitized)
        logger.info(f"Received event with {len(event.get('Records', []))} records")
        
        # Process the S3 event
        result = process_s3_event(event, context)
        
        logger.info(f"Processing completed: {json.dumps(result['body'])}")
        return result
        
    except Exception as e:
        logger.error(f"Lambda execution failed: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": str(e),
                "timestamp": datetime.utcnow().isoformat() + "Z"
            })
        }

# Optional: For local testing
if __name__ == "__main__":
    # Simulate an S3 event for testing
    test_event = {
        "Records": [{
            "s3": {
                "bucket": {"name": "test-raw-bucket"},
                "object": {"key": "insurance_data.csv"}
            }
        }]
    }
    
    # Mock environment variables
    os.environ["PROCESSED_S3_BUCKET"] = "test-processed-bucket"
    os.environ["ERROR_BUCKET"] = "test-error-bucket"
    
    result = lambda_handler(test_event, None)
    print(json.dumps(result, indent=2))