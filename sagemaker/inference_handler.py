# inference.py - SageMaker Inference Endpoint Code
import os
import json
import joblib
import numpy as np
import pandas as pd
import sys
from io import StringIO
import logging
from typing import Dict, Any, Union, List

# Setup logging for SageMaker
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Define constants for model files
MODEL_FILENAME = "model.joblib"
PREPROCESSOR_FILENAME = "preprocessor.joblib"

class CustomException(Exception):
    """Custom exception class for better error handling"""
    def _init_(self, message: str, error_details: sys = None):
        super()._init_(message)
        self.message = message
        self.error_details = error_details

    def _str_(self) -> str:
        return self.message

class InputData:
    """Class to validate and prepare input data for prediction"""

    def _init_(self,
                 age: Union[int, str],
                 children: Union[int, str],
                 bmi: Union[float, str],
                 sex: str,
                 smoker: str,
                 region: str):

        # Validate and convert inputs
        self.age = self._validate_age(age)
        self.children = self._validate_children(children)
        self.bmi = self._validate_bmi(bmi)
        self.sex = self._validate_sex(sex)
        self.smoker = self._validate_smoker(smoker)
        self.region = self._validate_region(region)

        logger.info(f"Input data validated - Age: {self.age}, Children: {self.children}, "
                   f"BMI: {self.bmi:.2f}, Sex: {self.sex}, Smoker: {self.smoker}, Region: {self.region}")

    def _validate_age(self, age: Union[int, str]) -> int:
        """Validate age input"""
        try:
            age_int = int(float(age))  # Handle both int and float strings
            if age_int < 0:
                raise ValueError("Age cannot be negative")
            if age_int > 120:
                logger.warning(f"Age {age_int} is unusually high")
            return age_int
        except (ValueError, TypeError) as e:
            raise CustomException(f"Invalid age value: {age}. Must be a positive integer. Error: {str(e)}")

    def _validate_children(self, children: Union[int, str]) -> int:
        """Validate children input"""
        try:
            children_int = int(float(children))  # Handle both int and float strings
            if children_int < 0:
                logger.warning(f"Children count {children_int} is negative")
            if children_int > 20:
                logger.warning(f"Children count {children_int} is unusually high")
            return children_int
        except (ValueError, TypeError) as e:
            raise CustomException(f"Invalid children value: {children}. Must be an integer. Error: {str(e)}")

    def _validate_bmi(self, bmi: Union[float, str]) -> float:
        """Validate BMI input"""
        try:
            bmi_float = float(bmi)
            if bmi_float <= 0:
                raise ValueError("BMI must be positive")
            if bmi_float > 100:
                logger.warning(f"BMI {bmi_float:.2f} is unusually high")
            return round(bmi_float, 2)
        except (ValueError, TypeError) as e:
            raise CustomException(f"Invalid BMI value: {bmi}. Must be a positive number. Error: {str(e)}")

    def _validate_sex(self, sex: str) -> str:
        """Validate sex input and standardize"""
        sex_lower = str(sex).lower().strip()

        # Map common variations to standard values
        sex_mapping = {
            'male': 'male',
            'm': 'male',
            'man': 'male',
            'boy': 'male',
            'female': 'female',
            'f': 'female',
            'woman': 'female',
            'girl': 'female'
        }

        if sex_lower in sex_mapping:
            return sex_mapping[sex_lower]
        else:
            logger.warning(f"Unexpected sex value: {sex}. Expected 'male' or 'female'")
            return sex_lower  # Return as-is, will be handled by preprocessor

    def _validate_smoker(self, smoker: str) -> str:
        """Validate smoker input and standardize"""
        smoker_lower = str(smoker).lower().strip()

        # Map common variations to standard values
        smoker_mapping = {
            'yes': 'yes',
            'y': 'yes',
            'true': 'yes',
            't': 'yes',
            '1': 'yes',
            'no': 'no',
            'n': 'no',
            'false': 'no',
            'f': 'no',
            '0': 'no'
        }

        if smoker_lower in smoker_mapping:
            return smoker_mapping[smoker_lower]
        else:
            logger.warning(f"Unexpected smoker value: {smoker}. Expected 'yes' or 'no'")
            return smoker_lower  # Return as-is

    def _validate_region(self, region: str) -> str:
        """Validate region input"""
        region_lower = str(region).lower().strip()
        valid_regions = ['northeast', 'northwest', 'southeast', 'southwest']

        # Check if region is valid
        if region_lower in valid_regions:
            return region_lower
        else:
            logger.warning(f"Unexpected region: {region}. Expected one of {valid_regions}")
            return region_lower  # Return as-is, will be handled by preprocessor

    def get_data_as_dataframe(self) -> pd.DataFrame:
        """Convert validated input data to DataFrame"""
        try:
            input_dict = {
                "age": [self.age],
                "children": [self.children],
                "bmi": [self.bmi],
                "sex": [self.sex],
                "smoker": [self.smoker],
                "region": [self.region]
            }

            # Create DataFrame
            df = pd.DataFrame(input_dict)

            # Ensure correct data types
            dtype_mapping = {
                'age': 'int64',
                'children': 'int64',
                'bmi': 'float64',
                'sex': 'object',
                'smoker': 'object',
                'region': 'object'
            }

            for col, dtype in dtype_mapping.items():
                df[col] = df[col].astype(dtype)

            logger.info(f"Created DataFrame with shape: {df.shape}")
            logger.debug(f"DataFrame:\n{df.to_dict()}")

            return df

        except Exception as e:
            logger.error(f"Error creating DataFrame: {str(e)}")
            raise CustomException(f"Failed to create DataFrame: {str(e)}")

class PredictPipeline:
    """Main prediction pipeline that loads model and makes predictions"""

    def _init_(self, model_dir: str = "/opt/ml/model"):
        self.model_dir = model_dir
        self.model = None
        self.preprocessor = None
        self.loaded = False

    def load_artifacts(self) -> None:
        """Load model and preprocessor from the model directory"""
        try:
            if self.loaded:
                logger.info("Model already loaded, skipping reload")
                return

            logger.info(f"Loading model artifacts from directory: {self.model_dir}")

            # Check for model files with different extensions
            possible_model_files = [
                os.path.join(self.model_dir, "model.joblib"),
                os.path.join(self.model_dir, "model.pkl"),
                os.path.join(self.model_dir, "model.sav"),
                os.path.join(self.model_dir, MODEL_FILENAME)
            ]

            model_loaded = False
            for model_path in possible_model_files:
                if os.path.exists(model_path):
                    self.model = joblib.load(model_path)
                    logger.info(f"Model loaded successfully from: {model_path}")
                    model_loaded = True
                    break

            if not model_loaded:
                raise FileNotFoundError(f"No model file found in {self.model_dir}")

            # Check for preprocessor files
            possible_preprocessor_files = [
                os.path.join(self.model_dir, "preprocessor.joblib"),
                os.path.join(self.model_dir, "preprocessor.pkl"),
                os.path.join(self.model_dir, "preprocessor.sav"),
                os.path.join(self.model_dir, PREPROCESSOR_FILENAME)
            ]

            preprocessor_loaded = False
            for preprocessor_path in possible_preprocessor_files:
                if os.path.exists(preprocessor_path):
                    self.preprocessor = joblib.load(preprocessor_path)
                    logger.info(f"Preprocessor loaded successfully from: {preprocessor_path}")
                    preprocessor_loaded = True
                    break

            if not preprocessor_loaded:
                logger.warning("No preprocessor file found. Using raw features for prediction.")

            self.loaded = True
            logger.info("All model artifacts loaded successfully")

        except Exception as e:
            logger.error(f"Error loading model artifacts: {str(e)}")
            raise CustomException(f"Failed to load model artifacts: {str(e)}")

    def predict(self, features: pd.DataFrame) -> np.ndarray:
        """Make predictions on input features"""
        try:
            if not self.loaded:
                self.load_artifacts()

            logger.info(f"Making predictions on input features with shape: {features.shape}")
            logger.debug(f"Input features:\n{features}")

            # Apply preprocessing if preprocessor exists
            if self.preprocessor is not None:
                logger.info("Applying preprocessing to input features")
                try:
                    data_scaled = self.preprocessor.transform(features)
                    logger.info(f"Features scaled to shape: {data_scaled.shape}")
                except Exception as e:
                    logger.error(f"Error during preprocessing: {str(e)}")
                    raise CustomException(f"Preprocessing failed: {str(e)}")
            else:
                logger.info("No preprocessor found, using raw features")
                data_scaled = features.values

            # Make predictions
            logger.info("Making predictions with loaded model")
            try:
                preds = self.model.predict(data_scaled)
                logger.info(f"Predictions generated with shape: {preds.shape}")
                logger.info(f"Sample prediction: {preds[0] if len(preds) > 0 else 'No predictions'}")
                return preds
            except Exception as e:
                logger.error(f"Error during model prediction: {str(e)}")
                raise CustomException(f"Model prediction failed: {str(e)}")

        except Exception as e:
            logger.error(f"Error in predict method: {str(e)}")
            raise CustomException(f"Prediction pipeline failed: {str(e)}")

# ============================================================================
# SageMaker Required Functions
# ============================================================================

def model_fn(model_dir: str) -> PredictPipeline:
    """
    Load the model when the endpoint starts.
    This function is REQUIRED by SageMaker.

    Args:
        model_dir: Path to the directory containing model artifacts

    Returns:
        PredictPipeline: Initialized prediction pipeline
    """
    logger.info(f"SageMaker model_fn called with model_dir: {model_dir}")

    try:
        # Initialize the prediction pipeline
        pipeline = PredictPipeline(model_dir)

        # Load the model artifacts
        pipeline.load_artifacts()

        logger.info("SageMaker model_fn completed successfully")
        return pipeline

    except Exception as e:
        logger.error(f"Error in SageMaker model_fn: {str(e)}")
        raise CustomException(f"Failed to load model in model_fn: {str(e)}")

def input_fn(request_body: bytes, request_content_type: str) -> pd.DataFrame:
    """
    Parse the input data from the request.
    This function is REQUIRED by SageMaker.

    Args:
        request_body: The body of the request
        request_content_type: The content type of the request

    Returns:
        pd.DataFrame: Parsed input data as DataFrame
    """
    logger.info(f"SageMaker input_fn called with content_type: {request_content_type}")
    logger.debug(f"Request body length: {len(request_body)} bytes")

    try:
        if request_content_type == 'text/csv':
            logger.info("Processing CSV input")

            # Parse CSV string
            csv_string = request_body.decode('utf-8')
            logger.debug(f"CSV string: {csv_string}")

            # Try to parse with header first, then without
            try:
                df = pd.read_csv(StringIO(csv_string))
                logger.info("CSV parsed with header detection")
            except:
                # If fails, try without header
                df = pd.read_csv(StringIO(csv_string), header=None)

                # Assign column names based on expected columns
                if df.shape[1] == 6:
                    df.columns = ['age', 'children', 'bmi', 'sex', 'smoker', 'region']
                    logger.info("Assigned column names to CSV input")
                else:
                    logger.warning(f"Unexpected number of columns in CSV: {df.shape[1]}")

            logger.info(f"CSV parsed successfully, shape: {df.shape}")
            return df

        elif request_content_type == 'application/json':
            logger.info("Processing JSON input")

            # Parse JSON
            json_data = json.loads(request_body.decode('utf-8'))
            logger.debug(f"JSON data: {json_data}")

            # Handle different JSON formats
            if isinstance(json_data, dict):
                # Check for Flask-like form data format
                if all(key in json_data for key in ['age', 'children', 'bmi', 'sex', 'smoker', 'region']):
                    logger.info("Processing Flask form-like JSON format")
                    df = pd.DataFrame([json_data])

                # Check for instances format (batch prediction)
                elif 'instances' in json_data:
                    logger.info("Processing instances format (batch prediction)")
                    instances = json_data['instances']
                    df = pd.DataFrame(instances)

                # Check for data format
                elif 'data' in json_data:
                    logger.info("Processing data format")
                    df = pd.DataFrame(json_data['data'])

                # Check for features format
                elif 'features' in json_data:
                    logger.info("Processing features format")
                    df = pd.DataFrame([json_data['features']])

                else:
                    logger.warning("Unknown JSON dictionary format, trying to convert directly")
                    df = pd.DataFrame([json_data])

            elif isinstance(json_data, list):
                logger.info("Processing list format")
                # List of dictionaries
                if all(isinstance(item, dict) for item in json_data):
                    df = pd.DataFrame(json_data)
                # List of lists
                elif all(isinstance(item, list) for item in json_data):
                    df = pd.DataFrame(json_data, columns=['age', 'children', 'bmi', 'sex', 'smoker', 'region'])
                else:
                    raise ValueError("Unsupported list format in JSON")

            else:
                error_msg = f"Unsupported JSON structure: {type(json_data)}"
                logger.error(error_msg)
                raise ValueError(error_msg)

            # Validate required columns
            required_columns = ['age', 'children', 'bmi', 'sex', 'smoker', 'region']
            missing_columns = [col for col in required_columns if col not in df.columns]

            if missing_columns:
                error_msg = f"Missing required columns: {missing_columns}"
                logger.error(error_msg)
                raise ValueError(error_msg)

            logger.info(f"JSON parsed successfully, shape: {df.shape}")
            return df

        elif request_content_type == 'application/x-www-form-urlencoded':
            logger.info("Processing form-urlencoded input (Flask-like)")

            # Parse form data (simulating Flask request.form)
            from urllib.parse import parse_qs
            form_data = parse_qs(request_body.decode('utf-8'))

            # Extract values (parse_qs returns lists)
            input_dict = {}
            for key in ['age', 'children', 'bmi', 'sex', 'smoker', 'region']:
                if key in form_data:
                    input_dict[key] = form_data[key][0] if form_data[key] else ''
                else:
                    input_dict[key] = ''

            logger.debug(f"Form data parsed: {input_dict}")

            # Create InputData object for validation
            try:
                input_data = InputData(
                    age=input_dict['age'],
                    children=input_dict['children'],
                    bmi=input_dict['bmi'],
                    sex=input_dict['sex'],
                    smoker=input_dict['smoker'],
                    region=input_dict['region']
                )

                df = input_data.get_data_as_dataframe()
                logger.info(f"Form data parsed successfully, shape: {df.shape}")
                return df

            except Exception as e:
                logger.error(f"Error validating form data: {str(e)}")
                raise

        else:
            error_msg = f"Unsupported content type: {request_content_type}"
            logger.error(error_msg)
            raise ValueError(error_msg)

    except Exception as e:
        logger.error(f"Error in SageMaker input_fn: {str(e)}")
        raise CustomException(f"Failed to parse input in input_fn: {str(e)}")

def predict_fn(input_data: pd.DataFrame, model: PredictPipeline) -> np.ndarray:
    """
    Make predictions using the loaded model.
    This function is REQUIRED by SageMaker.

    Args:
        input_data: Parsed input data as DataFrame
        model: Loaded PredictPipeline object

    Returns:
        np.ndarray: Array of predictions
    """
    logger.info("SageMaker predict_fn called")
    logger.info(f"Input data shape: {input_data.shape}")

    try:
        # Make predictions using the pipeline
        predictions = model.predict(input_data)

        logger.info(f"Predictions generated successfully, shape: {predictions.shape}")
        return predictions

    except Exception as e:
        logger.error(f"Error in SageMaker predict_fn: {str(e)}")
        raise CustomException(f"Failed to make predictions in predict_fn: {str(e)}")

def output_fn(prediction: np.ndarray, accept: str) -> tuple:
    """
    Format the predictions for the response.
    This function is REQUIRED by SageMaker.

    Args:
        prediction: Array of predictions
        accept: The accept header from the request

    Returns:
        tuple: (response_body, content_type)
    """
    logger.info(f"SageMaker output_fn called with accept type: {accept}")
    logger.info(f"Prediction shape: {prediction.shape}")

    try:
        # Convert numpy array to list for easier JSON serialization
        if isinstance(prediction, np.ndarray):
            prediction_list = prediction.tolist()
        else:
            prediction_list = prediction

        # Handle single prediction vs batch
        is_single_prediction = len(prediction_list) == 1

        if accept == 'text/csv':
            logger.info("Returning CSV format")

            # Convert to CSV string
            if is_single_prediction:
                output = str(prediction_list[0])
            else:
                output = '\n'.join(str(p) for p in prediction_list)

            return output, 'text/csv'

        elif accept == 'application/json':
            logger.info("Returning JSON format")

            # Prepare JSON response
            if is_single_prediction:
                response = {
                    "prediction": prediction_list[0],
                    "status": "success",
                    "message": "Prediction completed successfully",
                    "timestamp": pd.Timestamp.now().isoformat()
                }
            else:
                response = {
                    "predictions": prediction_list,
                    "count": len(prediction_list),
                    "status": "success",
                    "message": f"Batch prediction completed for {len(prediction_list)} samples",
                    "timestamp": pd.Timestamp.now().isoformat()
                }

            return json.dumps(response, indent=2), 'application/json'

        elif accept == 'text/html':
            logger.info("Returning HTML format (for web interface)")

            # Create HTML response similar to Flask template
            if is_single_prediction:
                prediction_value = prediction_list[0]
                html_response = f"""
                <!DOCTYPE html>
                <html>
                <head>
                    <title>Insurance Cost Prediction</title>
                    <style>
                        body {{ font-family: Arial, sans-serif; margin: 40px; }}
                        .result {{ background-color: #f0f0f0; padding: 20px; border-radius: 5px; margin-top: 20px; }}
                        .prediction {{ font-size: 24px; color: #2c3e50; font-weight: bold; }}
                        .label {{ color: #7f8c8d; }}
                    </style>
                </head>
                <body>
                    <h1>Insurance Cost Prediction Result</h1>
                    <div class="result">
                        <div class="label">Predicted Insurance Cost:</div>
                        <div class="prediction">${prediction_value:,.2f}</div>
                    </div>
                    <p><a href="/">Make another prediction</a></p>
                </body>
                </html>
                """
            else:
                predictions_html = "<ul>" + "".join(f"<li>${p:,.2f}</li>" for p in prediction_list) + "</ul>"
                html_response = f"""
                <!DOCTYPE html>
                <html>
                <head>
                    <title>Batch Prediction Results</title>
                    <style>
                        body {{ font-family: Arial, sans-serif; margin: 40px; }}
                        .result {{ background-color: #f0f0f0; padding: 20px; border-radius: 5px; margin-top: 20px; }}
                    </style>
                </head>
                <body>
                    <h1>Batch Prediction Results</h1>
                    <div class="result">
                        <h3>Predictions ({len(prediction_list)} samples):</h3>
                        {predictions_html}
                    </div>
                    <p><a href="/">Make another prediction</a></p>
                </body>
                </html>
                """

            return html_response, 'text/html'

        else:
            logger.warning(f"Unsupported accept type: {accept}, defaulting to JSON")

            # Default to JSON response
            response = {
                "predictions": prediction_list,
                "status": "success",
                "warning": f"Accept type '{accept}' not fully supported, returned JSON",
                "accept_header_received": accept,
                "timestamp": pd.Timestamp.now().isoformat()
            }

            return json.dumps(response, indent=2), 'application/json'

    except Exception as e:
        logger.error(f"Error in SageMaker output_fn: {str(e)}")

        # Return error response
        error_response = {
            "error": str(e),
            "status": "error",
            "message": "Failed to format output",
            "timestamp": pd.Timestamp.now().isoformat()
        }

        return json.dumps(error_response, indent=2), 'application/json'

