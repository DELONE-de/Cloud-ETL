# Cloud ETL Pipeline with ML Training

A comprehensive cloud-native ETL pipeline that processes data and trains machine learning models using AWS services, orchestrated with Terraform and Step Functions.

## Architecture Overview

This project implements a complete data pipeline that:
- Ingests streaming data via Kinesis
- Processes and validates data using AWS Glue
- Trains ML models with SageMaker
- Deploys models for real-time inference
- Monitors pipeline health and costs

## Project Structure

```
Cloud-ETL/
├── .github/workflows/          # CI/CD pipelines
├── configs/                    # Step Functions definitions
├── deployment/                 # Model deployment infrastructure
├── docs/                      # Documentation and diagrams
├── glue/                      # ETL scripts
├── sagemaker/                 # ML training and inference code
├── scripts/                   # Utility scripts
└── terraform/                 # Infrastructure as Code
    ├── iam/                   # IAM roles and policies
    ├── ingestion/             # Data ingestion (Kinesis, S3)
    ├── observability/         # Monitoring and alerting
    ├── orchestration/         # Step Functions workflow
    └── validation/            # Data validation and cataloging
```

## Key Components

### 1. Data Ingestion (`terraform/ingestion/`)
- **Kinesis Data Streams**: Real-time data ingestion
- **Kinesis Data Firehose**: Batch delivery to S3
- **S3 Raw Bucket**: Landing zone for raw data

### 2. Data Processing (`glue/`, `terraform/validation/`)
- **AWS Glue Jobs**: ETL transformations and feature engineering
- **Glue Crawler**: Automatic schema discovery
- **Data Catalog**: Metadata management
- **Lambda Validation**: Data quality checks

### 3. ML Pipeline (`sagemaker/`, `configs/`)
- **Training Script**: Crop recommendation model using scikit-learn
- **Step Functions**: Orchestrates ETL → Training → Deployment
- **SageMaker Training**: Scalable model training
- **Model Registry**: Versioned model artifacts

### 4. Model Deployment (`deployment/`)
- **SageMaker Endpoints**: Real-time inference
- **API Gateway**: REST API for predictions
- **Lambda Functions**: Serverless inference handlers

### 5. Monitoring (`terraform/observability/`)
- **CloudWatch**: Logs and metrics
- **SNS Alerts**: Pipeline notifications
- **Cost Anomaly Detection**: Budget monitoring
- **AWS Budgets**: Cost control

## Quick Start

### Prerequisites
- AWS CLI configured
- Terraform >= 1.0
- Python 3.10+

### Deployment

1. **Initialize Terraform**
```bash
cd terraform
terraform init
```

2. **Configure Variables**
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

3. **Deploy Infrastructure**
```bash
terraform plan
terraform apply
```

4. **Package Training Code**
```bash
cd sagemaker
tar -czf code.tar.gz train_model.py
aws s3 cp code.tar.gz s3://your-bucket/code/
```

### Usage

1. **Start Data Ingestion**
```bash
# Send data to Kinesis stream
aws kinesis put-record \
  --stream-name your-stream \
  --data file://sample-data.json \
  --partition-key "partition-1"
```

2. **Trigger ML Pipeline**
```bash
# Execute Step Functions workflow
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:region:account:stateMachine:pipeline \
  --input '{"input_bucket": "s3://your-bucket/raw/"}'
```

3. **Make Predictions**
```bash
# Call inference endpoint
curl -X POST https://api-gateway-url/predict \
  -H "Content-Type: application/json" \
  -d '{"N": 21, "P": 26, "K": 27, "temperature": 27.0, "humidity": 47.7, "ph": 5.7, "rainfall": 95.8}'
```

## Configuration

### Environment Variables
- `DATA_S3_BUCKET`: Source data bucket
- `MODEL_S3_BUCKET`: Model artifacts bucket
- `AWS_REGION`: Deployment region

### Terraform Variables
Key variables in `terraform/variables.tf`:
- `project_prefix`: Resource naming prefix
- `environment`: Deployment environment (dev/staging/prod)
- `aws_region`: AWS region
- `kinesis_shard_count`: Kinesis stream capacity

## ML Model Details

### Crop Recommendation Model
- **Algorithm**: Multi-algorithm comparison (Random Forest, SVM, etc.)
- **Features**: N, P, K, temperature, humidity, pH, rainfall
- **Output**: Recommended crop type (22 categories)
- **Training**: Automated hyperparameter tuning
- **Deployment**: Real-time SageMaker endpoint

### Model Performance
The pipeline automatically selects the best-performing algorithm based on accuracy metrics during training.

## Monitoring and Alerts

### CloudWatch Dashboards
- Pipeline execution metrics
- Data quality indicators
- Model performance tracking
- Cost optimization insights

### Automated Alerts
- Pipeline failures
- Data quality issues
- Cost anomalies
- Resource utilization

## Security

### IAM Roles
- Principle of least privilege
- Service-specific roles
- Cross-service permissions

### Data Encryption
- S3 server-side encryption
- Kinesis encryption at rest
- SageMaker encrypted training

## Cost Optimization

### Resource Management
- Automatic scaling based on demand
- Spot instances for training
- Lifecycle policies for S3 storage
- Budget alerts and limits

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## Troubleshooting

### Common Issues

**Terraform State Lock**
```bash
terraform force-unlock LOCK_ID
```

**SageMaker Training Failures**
- Check CloudWatch logs: `/aws/sagemaker/TrainingJobs`
- Verify IAM permissions
- Ensure training data format

**Step Functions Errors**
- Review execution history in AWS Console
- Check individual task logs
- Validate JSON input format

