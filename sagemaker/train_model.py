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
    def __init__(self, message: str, error_details: sys = None):
        # FIX: Changed _init_ to __init__
        super().__init__(message)
        self.message = message
        self.error_details = error_details

    def __str__(self) -> str:
        # FIX: Changed _str_ to __str__
        return self.message

class InputData:
    """Class to validate and prepare input data for prediction"""

    def __init__(self,
                 age: Union[int, str],
                 children: Union[int, str],
                 bmi: Union[float, str],
                 sex: str,
                 smoker: str,
                 region: str):
        # FIX: Changed _init_ to __init__
        
        # Validate and convert inputs
        self.age = self._validate_age(age)
        self.children = self._validate_children(children)
        self.bmi = self._validate_bmi(bmi)
        self.sex = self._validate_sex(sex)
        self.smoker = self._validate_smoker(smoker)
        self.region = self._validate_region(region)

        logger.info(f"Input data validated")

    # ... (Validation methods remain same as they were logically sound)
    def _validate_age(self, age: Union[int, str]) -> int:
        try:
            age_int = int(float(age))
            if age_int < 0: raise ValueError("Age cannot be negative")
            return age_int
        except (ValueError, TypeError) as e:
            raise CustomException(f"Invalid age: {age}")

    def _validate_children(self, children: Union[int, str]) -> int:
        try:
            return int(float(children))
        except: return 0

    def _validate_bmi(self, bmi: Union[float, str]) -> float:
        try:
            return round(float(bmi), 2)
        except: return 25.0

    def _validate_sex(self, sex: str) -> str:
        return str(sex).lower().strip()

    def _validate_smoker(self, smoker: str) -> str:
        return str(smoker).lower().strip()

    def _validate_region(self, region: str) -> str:
        return str(region).lower().strip()

    def get_data_as_dataframe(self) -> pd.DataFrame:
        input_dict = {
            "age": [self.age], "children": [self.children], "bmi": [self.bmi],
            "sex": [self.sex], "smoker": [self.smoker], "region": [self.region]
        }
        return pd.DataFrame(input_dict)

class PredictPipeline:
    """Main prediction pipeline that loads model and makes predictions"""

    def __init__(self, model_dir: str = "/opt/ml/model"):
        # FIX: Changed _init_ to __init__
        self.model_dir = model_dir
        self.model = None
        self.preprocessor = None
        self.loaded = False

    def load_artifacts(self) -> None:
        try:
            if self.loaded: return

            # Look for model
            model_path = os.path.join(self.model_dir, MODEL_FILENAME)
            if not os.path.exists(model_path):
                # Fallback check
                model_path = os.path.join(self.model_dir, "model.joblib")
            
            self.model = joblib.load(model_path)
            
            # Look for preprocessor
            pre_path = os.path.join(self.model_dir, PREPROCESSOR_FILENAME)
            if os.path.exists(pre_path):
                self.preprocessor = joblib.load(pre_path)
            
            self.loaded = True
            logger.info("Artifacts loaded successfully")
        except Exception as e:
            raise CustomException(f"Load failed: {str(e)}")

    def predict(self, features: pd.DataFrame) -> np.ndarray:
        if not self.loaded:
            self.load_artifacts()

        if self.preprocessor is not None:
            data_transformed = self.preprocessor.transform(features)
        else:
            data_transformed = features
            
        return self.model.predict(data_transformed)

# ============================================================================
# SageMaker Required Functions
# ============================================================================

def model_fn(model_dir):
    pipeline = PredictPipeline(model_dir)
    pipeline.load_artifacts()
    return pipeline

def input_fn(request_body, request_content_type):
    if request_content_type == 'application/json':
        data = json.loads(request_body)
        # Handle SageMaker's standard 'instances' format or direct dict
        if isinstance(data, dict) and 'instances' in data:
            return pd.DataFrame(data['instances'])
        return pd.DataFrame([data] if isinstance(data, dict) else data)
    
    elif request_content_type == 'text/csv':
        return pd.read_csv(StringIO(request_body.decode('utf-8')))
    
    raise ValueError(f"Unsupported content type: {request_content_type}")

def predict_fn(input_data, model):
    return model.predict(input_data)

def output_fn(prediction, accept):
    if accept == 'application/json':
        return json.dumps({"predictions": prediction.tolist()}), accept
    elif accept == 'text/csv':
        return ",".join([str(x) for x in prediction]), accept
    return json.dumps(prediction.tolist()), 'application/json'
