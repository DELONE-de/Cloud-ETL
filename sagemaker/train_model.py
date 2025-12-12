import os
import sys
import json
import joblib
import boto3
import pandas as pd
import numpy as np
from datetime import datetime
from typing import Dict, Any, Tuple
import logging

from sklearn.ensemble import RandomForestRegressor, AdaBoostRegressor, GradientBoostingRegressor
from sklearn.linear_model import LinearRegression
from sklearn.neighbors import KNeighborsRegressor
from sklearn.tree import DecisionTreeRegressor
from sklearn.metrics import r2_score, mean_absolute_error, mean_squared_error
from sklearn.model_selection import GridSearchCV
import xgboost as xgb
from catboost import CatBoostRegressor

# Setup logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS configuration
S3_BUCKET = os.getenv('S3_BUCKET', 'your-model-bucket')
S3_PREFIX = os.getenv('S3_PREFIX', 'model-registry')
SAGEMAKER_EXECUTION_ROLE = os.getenv('SAGEMAKER_EXECUTION_ROLE', 'arn:aws:iam::account:role/sagemaker-role')
REGION = os.getenv('AWS_REGION', 'us-east-1')
THRESHOLD_R2 = float(os.getenv('THRESHOLD_R2', '0.8'))

# S3 paths
MODEL_PATH = f"s3://{S3_BUCKET}/{S3_PREFIX}/models/"
METRICS_PATH = f"s3://{S3_BUCKET}/{S3_PREFIX}/metrics/"
PREPROCESSOR_PATH = os.getenv('PREPROCESSOR_PATH', f"s3://{S3_BUCKET}/{S3_PREFIX}/artifacts/preprocessor.pkl")

class SageMakerTrainer:
    def __init__(self):
        self.s3_client = boto3.client('s3', region_name=REGION)
        self.sagemaker_client = boto3.client('sagemaker', region_name=REGION)
        self.timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        self.model_package_group_name = "InsuranceModelGroup"
        
    def load_data_from_s3(self, train_path: str, valid_path: str) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
        """Load train and validation data from S3"""
        logger.info(f"Loading training data from: {train_path}")
        logger.info(f"Loading validation data from: {valid_path}")
        
        try:
            # Load data using pandas
            train_df = pd.read_csv(train_path)
            valid_df = pd.read_csv(valid_path)
            
            logger.info(f"Training data shape: {train_df.shape}")
            logger.info(f"Validation data shape: {valid_df.shape}")
            
            # Convert to numpy arrays
            X_train = train_df.iloc[:, :-1].values
            y_train = train_df.iloc[:, -1].values
            X_valid = valid_df.iloc[:, :-1].values
            y_valid = valid_df.iloc[:, -1].values
            
            logger.info(f"X_train shape: {X_train.shape}, y_train shape: {y_train.shape}")
            logger.info(f"X_valid shape: {X_valid.shape}, y_valid shape: {y_valid.shape}")
            
            return X_train, y_train, X_valid, y_valid
            
        except Exception as e:
            logger.error(f"Error loading data from S3: {str(e)}")
            raise
    
    def load_preprocessor(self) -> Any:
        """Load preprocessor from S3"""
        logger.info(f"Loading preprocessor from: {PREPROCESSOR_PATH}")
        
        try:
            # Download preprocessor from S3
            path_parts = PREPROCESSOR_PATH.replace("s3://", "").split("/")
            bucket = path_parts[0]
            key = "/".join(path_parts[1:])
            
            # Download to local
            local_path = "/tmp/preprocessor.pkl"
            self.s3_client.download_file(bucket, key, local_path)
            
            # Load preprocessor
            preprocessor = joblib.load(local_path)
            logger.info("Preprocessor loaded successfully")
            
            return preprocessor
            
        except Exception as e:
            logger.error(f"Error loading preprocessor: {str(e)}")
            raise
    
    def evaluate_model(self, X_train: np.ndarray, y_train: np.ndarray, 
                      X_valid: np.ndarray, y_valid: np.ndarray, 
                      models: Dict, params: Dict) -> Dict:
        """Evaluate multiple models using GridSearchCV"""
        logger.info(f"Evaluating {len(models)} models")
        
        report = {}
        best_models = {}
        
        for model_name, model in models.items():
            logger.info(f"Training {model_name}")
            
            try:
                # Get parameters for current model
                param_grid = params.get(model_name, {})
                
                if param_grid:
                    # Perform GridSearchCV
                    logger.info(f"Performing GridSearchCV for {model_name}")
                    grid_search = GridSearchCV(
                        model,
                        param_grid,
                        cv=3,
                        scoring='r2',
                        n_jobs=-1,
                        verbose=0
                    )
                    grid_search.fit(X_train, y_train)
                    
                    # Get best estimator
                    best_estimator = grid_search.best_estimator_
                    best_params = grid_search.best_params_
                    
                    logger.info(f"Best parameters for {model_name}: {best_params}")
                else:
                    # Train without hyperparameter tuning
                    best_estimator = model
                    best_estimator.fit(X_train, y_train)
                    best_params = {}
                
                # Make predictions
                y_train_pred = best_estimator.predict(X_train)
                y_valid_pred = best_estimator.predict(X_valid)
                
                # Calculate metrics
                train_r2 = r2_score(y_train, y_train_pred)
                valid_r2 = r2_score(y_valid, y_valid_pred)
                train_mae = mean_absolute_error(y_train, y_train_pred)
                valid_mae = mean_absolute_error(y_valid, y_valid_pred)
                train_rmse = np.sqrt(mean_squared_error(y_train, y_train_pred))
                valid_rmse = np.sqrt(mean_squared_error(y_valid, y_valid_pred))
                
                # Store results
                report[model_name] = {
                    'validation_r2': float(valid_r2),
                    'training_r2': float(train_r2),
                    'validation_mae': float(valid_mae),
                    'validation_rmse': float(valid_rmse),
                    'best_params': best_params
                }
                
                # Store best model
                best_models[model_name] = best_estimator
                
                logger.info(f"{model_name} - Validation R2: {valid_r2:.4f}, Training R2: {train_r2:.4f}")
                
            except Exception as e:
                logger.error(f"Error training {model_name}: {str(e)}")
                report[model_name] = {
                    'validation_r2': -1.0,
                    'training_r2': -1.0,
                    'validation_mae': float('inf'),
                    'validation_rmse': float('inf'),
                    'error': str(e)
                }
        
        return report, best_models
    
    def select_best_model(self, report: Dict, best_models: Dict) -> Tuple[Any, str, float, Dict]:
        """Select the best model based on validation R2 score"""
        logger.info("Selecting best model")
        
        best_model_name = None
        best_score = -float('inf')
        best_model = None
        best_model_metrics = {}
        
        for model_name, metrics in report.items():
            if metrics['validation_r2'] > best_score:
                best_score = metrics['validation_r2']
                best_model_name = model_name
                best_model = best_models[model_name]
                best_model_metrics = metrics
        
        logger.info(f"Best model: {best_model_name} with R2: {best_score:.4f}")
        
        return best_model, best_model_name, best_score, best_model_metrics
    
    def check_threshold(self, score: float) -> bool:
        """Check if model meets the threshold requirement"""
        meets_threshold = score >= THRESHOLD_R2
        logger.info(f"Model R2 score: {score:.4f}, Threshold: {THRESHOLD_R2}, Meets threshold: {meets_threshold}")
        return meets_threshold
    
    def save_model_to_s3(self, model: Any, model_name: str) -> str:
        """Save model as joblib file to S3"""
        logger.info(f"Saving model {model_name} to S3")
        
        try:
            # Save model locally first
            local_model_path = f"/tmp/{model_name.replace(' ', '_').lower()}_{self.timestamp}.joblib"
            joblib.dump(model, local_model_path)
            
            # Upload to S3
            s3_model_key = f"{S3_PREFIX}/models/{model_name.replace(' ', '_').lower()}_{self.timestamp}.joblib"
            s3_model_path = f"s3://{S3_BUCKET}/{s3_model_key}"
            
            self.s3_client.upload_file(local_model_path, S3_BUCKET, s3_model_key)
            
            logger.info(f"Model saved to S3: {s3_model_path}")
            
            return s3_model_path
            
        except Exception as e:
            logger.error(f"Error saving model to S3: {str(e)}")
            raise
    
    def save_metrics_to_s3(self, metrics: Dict, model_name: str) -> str:
        """Save training metrics to S3 as JSON"""
        logger.info(f"Saving metrics for {model_name}")
        
        try:
            # Add metadata
            metrics_with_metadata = {
                'model_name': model_name,
                'training_timestamp': self.timestamp,
                'threshold_r2': THRESHOLD_R2,
                'metrics': metrics,
                'environment': {
                    'region': REGION,
                    's3_bucket': S3_BUCKET,
                    's3_prefix': S3_PREFIX
                }
            }
            
            # Save metrics locally
            local_metrics_path = f"/tmp/metrics_{model_name.replace(' ', '_').lower()}_{self.timestamp}.json"
            with open(local_metrics_path, 'w') as f:
                json.dump(metrics_with_metadata, f, indent=2)
            
            # Upload to S3
            s3_metrics_key = f"{S3_PREFIX}/metrics/{model_name.replace(' ', '_').lower()}_{self.timestamp}.json"
            s3_metrics_path = f"s3://{S3_BUCKET}/{s3_metrics_key}"
            
            self.s3_client.upload_file(local_metrics_path, S3_BUCKET, s3_metrics_key)
            
            logger.info(f"Metrics saved to S3: {s3_metrics_path}")
            
            return s3_metrics_path
            
        except Exception as e:
            logger.error(f"Error saving metrics to S3: {str(e)}")
            raise
    
    def register_model_in_sagemaker(self, model_path: str, model_name: str, metrics: Dict) -> str:
        """Register model in SageMaker Model Registry"""
        logger.info(f"Registering model {model_name} in SageMaker Model Registry")
        
        try:
            # Check if model package group exists, create if not
            try:
                self.sagemaker_client.describe_model_package_group(
                    ModelPackageGroupName=self.model_package_group_name
                )
                logger.info(f"Model package group {self.model_package_group_name} already exists")
            except self.sagemaker_client.exceptions.ResourceNotFound:
                logger.info(f"Creating model package group {self.model_package_group_name}")
                self.sagemaker_client.create_model_package_group(
                    ModelPackageGroupName=self.model_package_group_name,
                    ModelPackageGroupDescription="Insurance prediction model group"
                )
            
            # Create inference specification
            inference_specification = {
                'Containers': [
                    {
                        'Image': '246618743249.dkr.ecr.us-west-2.amazonaws.com/sagemaker-scikit-learn:0.23-1-cpu-py3',
                        'ModelDataUrl': model_path,
                        'Environment': {
                            'SAGEMAKER_PROGRAM': 'inference.py',
                            'SAGEMAKER_SUBMIT_DIRECTORY': model_path,
                            'SAGEMAKER_CONTAINER_LOG_LEVEL': '20',
                            'SAGEMAKER_REGION': REGION
                        }
                    }
                ],
                'SupportedContentTypes': ['text/csv'],
                'SupportedResponseMIMETypes': ['text/csv']
            }
            
            # Create model package
            model_package_response = self.sagemaker_client.create_model_package(
                ModelPackageName=f"{self.model_package_group_name}-{self.timestamp}",
                ModelPackageGroupName=self.model_package_group_name,
                ModelPackageDescription=f"Insurance prediction model trained on {self.timestamp}",
                InferenceSpecification=inference_specification,
                ModelMetrics={
                    'ModelQuality': {
                        'Statistics': {
                            'ContentType': 'application/json',
                            'S3Uri': metrics['s3_path'].replace('.json', '_statistics.json')
                        }
                    }
                },
                ModelApprovalStatus='PendingManualApproval'  # Requires manual approval
            )
            
            model_package_arn = model_package_response['ModelPackageArn']
            logger.info(f"Model registered in SageMaker Model Registry: {model_package_arn}")
            
            return model_package_arn
            
        except Exception as e:
            logger.error(f"Error registering model in SageMaker: {str(e)}")
            raise
    
    def get_models_and_params(self) -> Tuple[Dict, Dict]:
        """Define models and their hyperparameters"""
        models = {
            "Random Forest": RandomForestRegressor(random_state=42),
            "Decision Tree": DecisionTreeRegressor(random_state=42),
            "Gradient Boosting": GradientBoostingRegressor(random_state=42),
            "Linear Regression": LinearRegression(),
            "XGBRegressor": xgb.XGBRegressor(random_state=42, verbosity=0),
            "CatBoosting Regressor": CatBoostRegressor(random_state=42, verbose=0),
            "AdaBoost Regressor": AdaBoostRegressor(random_state=42),
            "KNeighbors Regressor": KNeighborsRegressor()
        }
        
        params = {
            "Decision Tree": {
                'criterion': ['squared_error', 'friedman_mse', 'absolute_error'],
                'max_depth': [None, 10, 20, 30],
                'min_samples_split': [2, 5, 10]
            },
            "Random Forest": {
                'n_estimators': [50, 100, 200],
                'max_depth': [None, 10, 20],
                'min_samples_split': [2, 5]
            },
            "Gradient Boosting": {
                'learning_rate': [0.01, 0.1, 0.2],
                'n_estimators': [100, 200],
                'max_depth': [3, 5]
            },
            "Linear Regression": {},
            "XGBRegressor": {
                'learning_rate': [0.01, 0.1, 0.2],
                'n_estimators': [100, 200],
                'max_depth': [3, 5, 7]
            },
            "CatBoosting Regressor": {
                'depth': [4, 6, 8],
                'learning_rate': [0.01, 0.05, 0.1],
                'iterations': [100, 200]
            },
            "AdaBoost Regressor": {
                'learning_rate': [0.01, 0.1, 0.5],
                'n_estimators': [50, 100]
            },
            "KNeighbors Regressor": {
                'n_neighbors': [3, 5, 7, 9],
                'weights': ['uniform', 'distance']
            }
        }
        
        return models, params
    
    def run_training(self, train_data_path: str, valid_data_path: str) -> Dict:
        """Main training pipeline"""
        logger.info("Starting SageMaker training pipeline")
        
        try:
            # Step 1: Load data
            logger.info("=== Step 1: Loading Data ===")
            X_train, y_train, X_valid, y_valid = self.load_data_from_s3(train_data_path, valid_data_path)
            
            # Step 2: Define models
            logger.info("=== Step 2: Defining Models ===")
            models, params = self.get_models_and_params()
            
            # Step 3: Train and evaluate models
            logger.info("=== Step 3: Training and Evaluating Models ===")
            report, best_models = self.evaluate_model(X_train, y_train, X_valid, y_valid, models, params)
            
            # Step 4: Select best model
            logger.info("=== Step 4: Selecting Best Model ===")
            best_model, best_model_name, best_score, best_metrics = self.select_best_model(report, best_models)
            
            # Step 5: Check threshold
            logger.info("=== Step 5: Checking Threshold ===")
            if not self.check_threshold(best_score):
                logger.warning(f"Model R2 score {best_score:.4f} does not meet threshold {THRESHOLD_R2}")
                return {
                    'status': 'failed',
                    'reason': f'Model R2 score {best_score:.4f} below threshold {THRESHOLD_R2}',
                    'best_model_name': best_model_name,
                    'best_score': best_score,
                    'threshold': THRESHOLD_R2
                }
            
            # Step 6: Save model to S3
            logger.info("=== Step 6: Saving Model to S3 ===")
            s3_model_path = self.save_model_to_s3(best_model, best_model_name)
            
            # Step 7: Save metrics to S3
            logger.info("=== Step 7: Saving Metrics to S3 ===")
            metrics_data = {
                'model_report': report,
                'best_model_metrics': best_metrics,
                'model_s3_path': s3_model_path
            }
            s3_metrics_path = self.save_metrics_to_s3(metrics_data, best_model_name)
            
            # Step 8: Register model in SageMaker
            logger.info("=== Step 8: Registering Model in SageMaker ===")
            try:
                model_package_arn = self.register_model_in_sagemaker(
                    s3_model_path,
                    best_model_name,
                    {'s3_path': s3_metrics_path}
                )
                registration_success = True
            except Exception as e:
                logger.error(f"Failed to register model in SageMaker: {str(e)}")
                model_package_arn = None
                registration_success = False
            
            # Prepare final results
            results = {
                'status': 'success',
                'best_model_name': best_model_name,
                'best_score': float(best_score),
                'threshold_met': True,
                'model_s3_path': s3_model_path,
                'metrics_s3_path': s3_metrics_path,
                'model_registered_in_sagemaker': registration_success,
                'model_package_arn': model_package_arn,
                'training_timestamp': self.timestamp,
                'all_model_scores': report
            }
            
            logger.info("=== Training Pipeline Completed Successfully ===")
            logger.info(f"Results: {json.dumps(results, indent=2)}")
            
            return results
            
        except Exception as e:
            logger.error(f"Training pipeline failed: {str(e)}")
            raise

def main():
    """Main entry point for SageMaker training job"""
    
    # Get data paths from environment variables
    train_data_path = os.getenv('TRAIN_DATA_PATH', f"s3://{S3_BUCKET}/{S3_PREFIX}/processed/train_processed.csv")
    valid_data_path = os.getenv('VALID_DATA_PATH', f"s3://{S3_BUCKET}/{S3_PREFIX}/processed/validation_processed.csv")
    
    logger.info("=" * 60)
    logger.info("SageMaker Model Training Pipeline")
    logger.info("=" * 60)
    logger.info(f"Train data: {train_data_path}")
    logger.info(f"Validation data: {valid_data_path}")
    logger.info(f"Threshold R2: {THRESHOLD_R2}")
    logger.info(f"S3 Bucket: {S3_BUCKET}")
    logger.info(f"S3 Prefix: {S3_PREFIX}")
    logger.info("=" * 60)
    
    # Initialize trainer
    trainer = SageMakerTrainer()
    
    # Run training
    results = trainer.run_training(train_data_path, valid_data_path)
    
    # Print summary
    print("\n" + "=" * 60)
    print("TRAINING JOB SUMMARY")
    print("=" * 60)
    print(f"Status: {results.get('status', 'unknown').upper()}")
    print(f"Best Model: {results.get('best_model_name', 'N/A')}")
    print(f"Best R2 Score: {results.get('best_score', 0):.4f}")
    print(f"Threshold Met: {results.get('threshold_met', False)}")
    print(f"Model S3 Path: {results.get('model_s3_path', 'N/A')}")
    print(f"Metrics S3 Path: {results.get('metrics_s3_path', 'N/A')}")
    print(f"SageMaker Registration: {results.get('model_registered_in_sagemaker', False)}")
    print("=" * 60)
    
    # Save results to local file for SageMaker
    with open('/opt/ml/output/data/results.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    return results

if __name__ == "__main__":
    main()