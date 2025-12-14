import sys
import awswrangler as wr
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.impute import SimpleImputer
from sklearn.pipeline import Pipeline
import joblib
import boto3
import logging

# Setup logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# S3 paths
S3_BUCKET = "your-bucket-name"
S3_PREFIX = "data-pipeline"
RAW_DATA_PATH = f"s3://{S3_BUCKET}/{S3_PREFIX}/raw/insurance.csv"
TRAIN_PATH = f"s3://{S3_BUCKET}/{S3_PREFIX}/processed/train.csv"
VALID_PATH = f"s3://{S3_BUCKET}/{S3_PREFIX}/processed/validation.csv"
TEST_PATH = f"s3://{S3_BUCKET}/{S3_PREFIX}/processed/test.csv"
RAW_OUTPUT_PATH = f"s3://{S3_BUCKET}/{S3_PREFIX}/processed/raw_cleaned.csv"
PREPROCESSOR_PATH = f"s3://{S3_BUCKET}/{S3_PREFIX}/artifacts/preprocessor.pkl"
METRICS_PATH = f"s3://{S3_BUCKET}/{S3_PREFIX}/artifacts/pipeline_metrics.json"

class GlueETLPipeline:
    def __init__(self):
        self.s3_client = boto3.client('s3')

    def load_data(self):
        """Load data from S3"""
        logger.info(f"Loading data from {RAW_DATA_PATH}")
        try:
            df = wr.s3.read_csv(RAW_DATA_PATH)
            logger.info(f"Loaded {len(df)} records with {len(df.columns)} columns")
            logger.info(f"Columns: {list(df.columns)}")
            return df
        except Exception as e:
            logger.error(f"Error loading data: {str(e)}")
            raise

    def clean_data(self, df):
        """Clean and preprocess data"""
        logger.info("Starting data cleaning process")

        # Log initial state
        logger.info(f"Initial shape: {df.shape}")
        logger.info(f"Initial duplicates: {df.duplicated().sum()}")
        logger.info(f"Missing values per column:\n{df.isnull().sum()}")

        # Drop duplicates
        initial_count = len(df)
        df = df.drop_duplicates()
        duplicates_removed = initial_count - len(df)
        logger.info(f"Removed {duplicates_removed} duplicate records")

        # Handle missing values
        for column in df.columns:
            missing_count = df[column].isnull().sum()
            if missing_count > 0:
                logger.info(f"Column '{column}' has {missing_count} missing values")

                if df[column].dtype in ['int64', 'float64']:
                    # For numerical columns, fill with median
                    median_val = df[column].median()
                    df[column].fillna(median_val, inplace=True)
                    logger.info(f"  Filled with median: {median_val}")
                else:
                    # For categorical columns, fill with mode
                    mode_val = df[column].mode()[0] if not df[column].mode().empty else 'Unknown'
                    df[column].fillna(mode_val, inplace=True)
                    logger.info(f"  Filled with mode: {mode_val}")

        # Log final state
        logger.info(f"Final shape after cleaning: {df.shape}")
        logger.info(f"Missing values after cleaning:\n{df.isnull().sum()}")

        return df

    def validate_data(self, df):
        """Validate data quality"""
        logger.info("Validating data quality")

        validation_results = {
            'total_records': len(df),
            'total_columns': len(df.columns),
            'has_duplicates': df.duplicated().sum() == 0,
            'has_missing_values': df.isnull().sum().sum() == 0,
            'column_types': {col: str(df[col].dtype) for col in df.columns}
        }

        # Check for required columns (adjust based on your dataset)
        required_columns = ['age', 'bmi', 'children', 'sex', 'smoker', 'region', 'charges']
        missing_columns = [col for col in required_columns if col not in df.columns]
        validation_results['missing_required_columns'] = missing_columns

        # Check data ranges for numerical columns
        numerical_cols = ['age', 'bmi', 'children', 'charges']
        for col in numerical_cols:
            if col in df.columns:
                validation_results[f'{col}_min'] = float(df[col].min())
                validation_results[f'{col}_max'] = float(df[col].max())
                validation_results[f'{col}_mean'] = float(df[col].mean())

        logger.info(f"Validation results: {validation_results}")

        return validation_results

    def split_data(self, df):
        """Split data into train, validation, and test sets"""
        logger.info("Splitting data into train/validation/test sets")

        # 70% train, 15% validation, 15% test
        train_df, remaining_df = train_test_split(df, train_size=0.7, random_state=42)
        valid_df, test_df = train_test_split(remaining_df, test_size=0.5, random_state=42)

        # Log split information
        logger.info(f"Training set: {len(train_df)} records ({len(train_df)/len(df)*100:.1f}%)")
        logger.info(f"Validation set: {len(valid_df)} records ({len(valid_df)/len(df)*100:.1f}%)")
        logger.info(f"Test set: {len(test_df)} records ({len(test_df)/len(df)*100:.1f}%)")

        return train_df, valid_df, test_df

    def create_preprocessor(self, df):
        """Create preprocessing pipeline based on data schema"""
        logger.info("Creating preprocessing pipeline")

        # Identify column types
        numerical_features = []
        categorical_features = []

        for column in df.columns:
            if column != 'charges':  # Assuming 'charges' is the target
                if df[column].dtype in ['int64', 'float64']:
                    numerical_features.append(column)
                    logger.info(f"  Numerical feature: {column}")
                else:
                    categorical_features.append(column)
                    logger.info(f"  Categorical feature: {column}")

        logger.info(f"Found {len(numerical_features)} numerical features and {len(categorical_features)} categorical features")

        # Create pipelines
        num_pipeline = Pipeline([
            ("imputer", SimpleImputer(strategy="median")),
            ("scaler", StandardScaler(with_mean=False))
        ])

        cat_pipeline = Pipeline([
            ("imputer", SimpleImputer(strategy="most_frequent")),
            ("encoder", OneHotEncoder(handle_unknown='ignore')),
            ("scaler", StandardScaler(with_mean=False))
        ])

        preprocessor = ColumnTransformer([
            ("num_pipeline", num_pipeline, numerical_features),
            ("cat_pipeline", cat_pipeline, categorical_features)
        ])

        logger.info("Preprocessing pipeline created successfully")

        return preprocessor

    def preprocess_data(self, train_df, valid_df, test_df):
        """Apply preprocessing to all datasets"""
        logger.info("Preprocessing data")

        # Create preprocessor
        preprocessor = self.create_preprocessor(train_df)

        # Prepare features (assuming 'charges' is the target column)
        target_column = 'charges'

        if target_column in train_df.columns:
            X_train = train_df.drop(columns=[target_column])
            y_train = train_df[target_column]
            X_valid = valid_df.drop(columns=[target_column])
            y_valid = valid_df[target_column]
            X_test = test_df.drop(columns=[target_column])
            y_test = test_df[target_column]

            # Fit preprocessor on training data
            logger.info("Fitting preprocessor on training data")
            X_train_processed = preprocessor.fit_transform(X_train)
            X_valid_processed = preprocessor.transform(X_valid)
            X_test_processed = preprocessor.transform(X_test)

            # Convert processed data back to DataFrames with column names
            feature_names = preprocessor.get_feature_names_out()
            X_train_df = pd.DataFrame(X_train_processed, columns=feature_names)
            X_valid_df = pd.DataFrame(X_valid_processed, columns=feature_names)
            X_test_df = pd.DataFrame(X_test_processed, columns=feature_names)

            # Add target column back
            X_train_df[target_column] = y_train.values
            X_valid_df[target_column] = y_valid.values
            X_test_df[target_column] = y_test.values

            logger.info(f"Processed training data shape: {X_train_df.shape}")
            logger.info(f"Processed validation data shape: {X_valid_df.shape}")
            logger.info(f"Processed test data shape: {X_test_df.shape}")

            return X_train_df, X_valid_df, X_test_df, preprocessor

        else:
            logger.warning(f"Target column '{target_column}' not found. Processing all columns.")
            # Process all columns if target not specified
            X_train_processed = preprocessor.fit_transform(train_df)
            X_valid_processed = preprocessor.transform(valid_df)
            X_test_processed = preprocessor.transform(test_df)

            feature_names = preprocessor.get_feature_names_out()
            X_train_df = pd.DataFrame(X_train_processed, columns=feature_names)
            X_valid_df = pd.DataFrame(X_valid_processed, columns=feature_names)
            X_test_df = pd.DataFrame(X_test_processed, columns=feature_names)

            return X_train_df, X_valid_df, X_test_df, preprocessor

    def save_to_s3(self, obj, s3_path, is_dataframe=False):
        """Save object or DataFrame to S3"""
        try:
            if is_dataframe:
                # Save DataFrame to CSV in S3
                wr.s3.to_csv(obj, s3_path, index=False)
                logger.info(f"Saved DataFrame to {s3_path}")
            else:
                # Save Python object to S3
                local_path = "/tmp/temp_object.pkl"
                joblib.dump(obj, local_path)

                # Parse S3 path
                path_parts = s3_path.replace("s3://", "").split("/")
                bucket = path_parts[0]
                key = "/".join(path_parts[1:])

                # Upload to S3
                self.s3_client.upload_file(local_path, bucket, key)
                logger.info(f"Saved object to {s3_path}")

        except Exception as e:
            logger.error(f"Error saving to S3: {str(e)}")
            raise

    def save_metrics(self, validation_results, splits_info):
        """Save pipeline metrics to S3"""
        import json

        metrics = {
            'data_validation': validation_results,
            'data_splits': splits_info,
            'pipeline_status': 'completed',
            'timestamp': pd.Timestamp.now().isoformat()
        }

        # Save locally first
        local_metrics_path = "/tmp/pipeline_metrics.json"
        with open(local_metrics_path, 'w') as f:
            json.dump(metrics, f, indent=2)

        # Upload to S3
        path_parts = METRICS_PATH.replace("s3://", "").split("/")
        bucket = path_parts[0]
        key = "/".join(path_parts[1:])

        self.s3_client.upload_file(local_metrics_path, bucket, key)
        logger.info(f"Saved metrics to {METRICS_PATH}")

        return metrics

    def run_pipeline(self):
        """Main pipeline execution"""
        logger.info("Starting ETL Pipeline")

        try:
            # Step 1: Load data
            logger.info("=== Step 1: Loading Data ===")
            df = self.load_data()

            # Step 2: Clean data
            logger.info("=== Step 2: Cleaning Data ===")
            df_clean = self.clean_data(df)

            # Save cleaned raw data
            self.save_to_s3(df_clean, RAW_OUTPUT_PATH, is_dataframe=True)

            # Step 3: Validate data
            logger.info("=== Step 3: Validating Data ===")
            validation_results = self.validate_data(df_clean)

            # Step 4: Split data
            logger.info("=== Step 4: Splitting Data ===")
            train_df, valid_df, test_df = self.split_data(df_clean)

            splits_info = {
                'train_records': len(train_df),
                'validation_records': len(valid_df),
                'test_records': len(test_df),
                'split_ratio': '70/15/15'
            }

            # Save raw splits
            self.save_to_s3(train_df, TRAIN_PATH, is_dataframe=True)
            self.save_to_s3(valid_df, VALID_PATH, is_dataframe=True)
            self.save_to_s3(test_df, TEST_PATH, is_dataframe=True)

            # Step 5: Preprocess data
            logger.info("=== Step 5: Preprocessing Data ===")
            train_processed, valid_processed, test_processed, preprocessor = self.preprocess_data(
                train_df, valid_df, test_df
            )

            # Save processed datasets
            self.save_to_s3(train_processed, TRAIN_PATH.replace('.csv', '_processed.csv'), is_dataframe=True)
            self.save_to_s3(valid_processed, VALID_PATH.replace('.csv', '_processed.csv'), is_dataframe=True)
            self.save_to_s3(test_processed, TEST_PATH.replace('.csv', '_processed.csv'), is_dataframe=True)

            # Step 6: Save preprocessor
            logger.info("=== Step 6: Saving Artifacts ===")
            self.save_to_s3(preprocessor, PREPROCESSOR_PATH)

            # Step 7: Save metrics
            logger.info("=== Step 7: Saving Metrics ===")
            metrics = self.save_metrics(validation_results, splits_info)

            # Final summary
            logger.info("=== Pipeline Execution Summary ===")
            logger.info(f"• Original data: {len(df)} records")
            logger.info(f"• Cleaned data: {len(df_clean)} records")
            logger.info(f"• Training set: {len(train_df)} records")
            logger.info(f"• Validation set: {len(valid_df)} records")
            logger.info(f"• Test set: {len(test_df)} records")
            logger.info(f"• Preprocessor saved to: {PREPROCESSOR_PATH}")
            logger.info(f"• Metrics saved to: {METRICS_PATH}")

            return metrics

        except Exception as e:
            logger.error(f"Pipeline failed: {str(e)}")
            raise

def main():
    """Main entry point for Glue job"""
    # Initialize pipeline
    pipeline = GlueETLPipeline()

    # Run pipeline
    metrics = pipeline.run_pipeline()

    # Print final summary
    print("=" * 50)
    print("ETL PIPELINE COMPLETED SUCCESSFULLY")
    print("=" * 50)
    print(f"Total Records Processed: {metrics['data_validation']['total_records']}")
    print(f"Data Splits: {metrics['data_splits']['split_ratio']}")
    print(f"  - Training: {metrics['data_splits']['train_records']} records")
    print(f"  - Validation: {metrics['data_splits']['validation_records']} records")
    print(f"  - Test: {metrics['data_splits']['test_records']} records")
    print(f"Data Quality Check: {'PASS' if metrics['data_validation']['has_duplicates'] else 'FAIL'}")
    print(f"Missing Values: {'None' if metrics['data_validation']['has_missing_values'] else 'Found'}")
    print(f"Artifacts Saved to S3: Yes")
    print(f"Metrics Saved to: {METRICS_PATH}")
    print("=" * 50)

    return metrics

if __name__ == "__main__":
    main()