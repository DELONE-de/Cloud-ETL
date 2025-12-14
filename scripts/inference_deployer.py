import boto3
import os
import tarfile
import logging
from datetime import datetime

# --- Configuration ---
# NOTE: Replace these placeholder values with your actual S3 bucket and paths
SOURCE_BUCKET_NAME = 'your-source-and-destination-bucket'
SOURCE_PREFIX = 'sagemaker/source_files'
DESTINATION_PREFIX = 'sagemaker/model_artifacts'
OUTPUT_ARCHIVE_NAME = 'sagemaker_model_artifact.tar.gz'

# List of files to download and package.
# The keys (Model.joblib, inference.py, requirements.txt) are the final filenames 
# when they are placed inside the Lambda's /tmp directory.
FILES_TO_PACKAGE = {
    'model.joblib': f'{SOURCE_PREFIX}/trained_model.joblib',
    'inference.py': f'{SOURCE_PREFIX}/inference_script.py',
    'requirements.txt': f'{SOURCE_PREFIX}/requirements.txt'
}

# Lambda's local temporary directory
TEMP_DIR = '/tmp'

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')

def handler(event, context):
    """
    Downloads three S3 files, packages them into a .tar.gz archive, and uploads 
    the final artifact back to S3 for SageMaker deployment.
    """
    logger.info(f"Starting artifact creation for bucket: {SOURCE_BUCKET_NAME}")
    
    # 1. Download all required files from S3 to /tmp
    downloaded_files = []
    try:
        for local_name, s3_key in FILES_TO_PACKAGE.items():
            local_path = os.path.join(TEMP_DIR, local_name)
            
            logger.info(f"Downloading s3://{SOURCE_BUCKET_NAME}/{s3_key} to {local_path}")
            s3.download_file(
                Bucket=SOURCE_BUCKET_NAME,
                Key=s3_key,
                Filename=local_path
            )
            downloaded_files.append(local_path)
        logger.info("All source files successfully downloaded.")
    except Exception as e:
        logger.error(f"Error during S3 download: {e}")
        return {"statusCode": 500, "body": f"S3 Download Error: {e}"}

    # 2. Create the .tar.gz archive in /tmp
    tar_output_path = os.path.join(TEMP_DIR, OUTPUT_ARCHIVE_NAME)
    
    try:
        # Create the compressed file in write mode with gzip compression ('w:gz')
        with tarfile.open(tar_output_path, 'w:gz') as tar:
            for local_path in downloaded_files:
                local_filename = os.path.basename(local_path)
                
                # CRITICAL for SageMaker: Add file, but ensure it's at the root 
                # of the archive by setting the arcname to just the filename.
                tar.add(local_path, arcname=local_filename)
                logger.info(f"Added {local_filename} to archive.")
        
        logger.info(f"Successfully created tar.gz file at {tar_output_path}")

    except Exception as e:
        logger.error(f"Error creating tar.gz: {e}")
        return {"statusCode": 500, "body": f"Tar Creation Error: {e}"}

    # 3. Upload the final .tar.gz file back to S3
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    s3_destination_key = f"{DESTINATION_PREFIX}/{timestamp}-{OUTPUT_ARCHIVE_NAME}"

    try:
        logger.info(f"Uploading final artifact to s3://{SOURCE_BUCKET_NAME}/{s3_destination_key}")
        s3.upload_file(
            Filename=tar_output_path,
            Bucket=SOURCE_BUCKET_NAME,
            Key=s3_destination_key
        )
        
        final_s3_uri = f"s3://{SOURCE_BUCKET_NAME}/{s3_destination_key}"
        logger.info(f"✅ SUCCESS: Artifact uploaded to {final_s3_uri}")

    except Exception as e:
        logger.error(f"Error during S3 upload: {e}")
        return {"statusCode": 500, "body": f"S3 Upload Error: {e}"}
        
    finally:
        # 4. Cleanup /tmp directory (Best Practice)
        for local_path in downloaded_files:
            os.remove(local_path)
        os.remove(tar_output_path)
        logger.info("Local /tmp files cleaned up.")

    return {
        'statusCode': 200,
        'body': 'SageMaker artifact creation and upload complete.',
        's3_uri': final_s3_uri
    }