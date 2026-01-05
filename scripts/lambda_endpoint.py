# lambda_function.py
import json
import boto3
import os

sagemaker_runtime = boto3.client("sagemaker-runtime")

ENDPOINT_NAME = os.environ["SAGEMAKER_ENDPOINT_NAME"]

REQUIRED_FIELDS = [
    "N", "P", "K",
    "temperature", "humidity",
    "ph", "rainfall"
]


def lambda_handler(event, context):
    try:
        body = json.loads(event["body"])

        # Validate payload
        for field in REQUIRED_FIELDS:
            if field not in body:
                return {
                    "statusCode": 400,
                    "body": json.dumps({"error": f"Missing field: {field}"})
                }

        response = sagemaker_runtime.invoke_endpoint(
            EndpointName=ENDPOINT_NAME,
            ContentType="application/json",
            Accept="application/json",
            Body=json.dumps(body),
        )

        result = json.loads(response["Body"].read())

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(result),
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
