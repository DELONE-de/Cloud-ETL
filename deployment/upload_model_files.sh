#!/bin/bash

# Create dummy model file
mkdir -p /tmp/model
echo "dummy model content" > /tmp/model/model.pkl
cd /tmp
tar -czf model.tar.gz model/

# Upload to S3
aws s3 cp model.tar.gz s3://cloud-etl-model-artifacts/models/model.tar.gz

# Create dummy inference code
mkdir -p /tmp/code
cat > /tmp/code/inference.py << 'EOF'
import pickle
import json

def model_fn(model_dir):
    """Load model from the model_dir"""
    with open(f"{model_dir}/model.pkl", "rb") as f:
        model = pickle.load(f)
    return model

def input_fn(request_body, request_content_type):
    """Parse input data"""
    if request_content_type == 'application/json':
        return json.loads(request_body)
    else:
        raise ValueError(f"Unsupported content type: {request_content_type}")

def predict_fn(input_data, model):
    """Make prediction"""
    # Dummy prediction
    return {"prediction": "rice", "confidence": 0.85}

def output_fn(prediction, content_type):
    """Format prediction output"""
    if content_type == 'application/json':
        return json.dumps(prediction)
    else:
        raise ValueError(f"Unsupported content type: {content_type}")
EOF

cd /tmp
tar -czf code.tar.gz code/

# Upload to S3
aws s3 cp code.tar.gz s3://cloud-etl-model-artifacts/code/code.tar.gz

# Cleanup
rm -rf /tmp/model /tmp/code /tmp/model.tar.gz /tmp/code.tar.gz

echo "Model files uploaded successfully"