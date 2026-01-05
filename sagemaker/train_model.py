import os
import logging
import boto3
import joblib
import numpy as np
import pandas as pd

from typing import Dict, Any
from io import BytesIO
from botocore.exceptions import ClientError

from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline
from sklearn.metrics import accuracy_score

from sklearn.discriminant_analysis import LinearDiscriminantAnalysis
from sklearn.linear_model import LogisticRegression
from sklearn.naive_bayes import GaussianNB
from sklearn.svm import SVC
from sklearn.neighbors import KNeighborsClassifier
from sklearn.tree import DecisionTreeClassifier, ExtraTreeClassifier
from sklearn.ensemble import (
    RandomForestClassifier,
    BaggingClassifier,
    AdaBoostClassifier,
    GradientBoostingClassifier,
)

# --------------------------------------------------
# Logging
# --------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s - %(message)s",
)
logger = logging.getLogger(__name__)

# --------------------------------------------------
# Configuration
# --------------------------------------------------
RANDOM_STATE = 42
TEST_SIZE = 0.3

# S3 locations
DATA_S3_BUCKET = os.getenv("DATA_S3_BUCKET", "your-data-bucket-name")
DATA_S3_KEY = os.getenv("DATA_S3_KEY", "datasets/Crop_recommendation.csv")

MODEL_ARTIFACT = "crop_recommendation_model.joblib"
MODEL_S3_BUCKET = os.getenv("MODEL_S3_BUCKET", "your-model-bucket-name")
MODEL_S3_KEY = f"models/{MODEL_ARTIFACT}"

# --------------------------------------------------
# Crop label mapping
# --------------------------------------------------
CROP_MAPPING: Dict[int, str] = {
    1: "Rice",
    2: "Maize",
    3: "Jute",
    4: "Cotton",
    5: "Coconut",
    6: "Papaya",
    7: "Orange",
    8: "Apple",
    9: "Muskmelon",
    10: "Watermelon",
    11: "Grapes",
    12: "Mango",
    13: "Banana",
    14: "Pomegranate",
    15: "Lentil",
    16: "Blackgram",
    17: "Mungbean",
    18: "Mothbeans",
    19: "Pigeonpeas",
    20: "Kidneybeans",
    21: "Chickpea",
    22: "Coffee",
}



# --------------------------------------------------
# Load dataset from SageMaker input path
# --------------------------------------------------
def load_dataset_from_sagemaker() -> pd.DataFrame:
    """
    Loads dataset from SageMaker input data path.
    Falls back to S3 if running outside SageMaker environment.
    """
    # SageMaker mounts input data here
    sagemaker_data_path = "/opt/ml/input/data/train/"

    if os.path.exists(sagemaker_data_path):
        logger.info(f"Loading dataset from SageMaker input path: {sagemaker_data_path}")
        for file in os.listdir(sagemaker_data_path):
            if file.endswith('.csv'):
                df = pd.read_csv(os.path.join(sagemaker_data_path, file))
                logger.info(f"Dataset loaded from {file}")
                return df
        raise RuntimeError("No CSV files found in SageMaker input data")
    else:
        # Fallback to S3 for local development
        logger.info("SageMaker path not found, falling back to S3")


# --------------------------------------------------
# Feature / label split
# --------------------------------------------------
def load_data(df: pd.DataFrame):
    X = df.iloc[:, :-1]
    y = df.iloc[:, -1]
    return X, y


# --------------------------------------------------
# Model zoo
# --------------------------------------------------
def get_models() -> Dict[str, Any]:
    return {
        "Linear Discriminant Analysis": LinearDiscriminantAnalysis(),
        "Logistic Regression": LogisticRegression(max_iter=1000),
        "Naive Bayes": GaussianNB(),
        "Support Vector Machine": SVC(),
        "K-Nearest Neighbors": KNeighborsClassifier(),
        "Decision Tree": DecisionTreeClassifier(random_state=RANDOM_STATE),
        "Random Forest": RandomForestClassifier(random_state=RANDOM_STATE),
        "Bagging": BaggingClassifier(random_state=RANDOM_STATE),
        "AdaBoost": AdaBoostClassifier(random_state=RANDOM_STATE),
        "Gradient Boosting": GradientBoostingClassifier(random_state=RANDOM_STATE),
        "Extra Trees": ExtraTreeClassifier(random_state=RANDOM_STATE),
    }


# --------------------------------------------------
# Train & evaluate
# --------------------------------------------------
def train_and_evaluate(X, y):
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=TEST_SIZE, random_state=RANDOM_STATE
    )

    results = {}
    trained_models = {}

    for name, model in get_models().items():
        pipeline = Pipeline(
            steps=[
                ("scaler", StandardScaler()),
                ("model", model),
            ]
        )

        pipeline.fit(X_train, y_train)
        preds = pipeline.predict(X_test)
        acc = accuracy_score(y_test, preds)

        results[name] = acc
        trained_models[name] = pipeline

        logger.info(f"{name} Accuracy: {acc:.4f}")

    best_model_name = max(results, key=results.get)
    logger.info(f"Best model selected: {best_model_name}")

    return trained_models[best_model_name], results


# --------------------------------------------------
# Prediction function
# --------------------------------------------------
def predict_crop(
    model,
    N: float,
    P: float,
    K: float,
    temperature: float,
    humidity: float,
    ph: float,
    rainfall: float,
) -> str:
    try:
        features = np.array(
            [[N, P, K, temperature, humidity, ph, rainfall]]
        )
        prediction = model.predict(features)[0]
        return CROP_MAPPING.get(int(prediction), "Unknown Crop")
    except Exception as e:
        logger.exception("Prediction failed")
        raise RuntimeError("Prediction error") from e


def save_model_to_s3(model):
    try:
        joblib.dump(model, MODEL_ARTIFACT)
        s3 = boto3.client("s3")
        s3.upload_file(MODEL_ARTIFACT, MODEL_S3_BUCKET, MODEL_S3_KEY)
        logger.info(f"Model uploaded to s3://{MODEL_S3_BUCKET}/{MODEL_S3_KEY}")
    except Exception as e:
        logger.exception("Failed to save or upload model to S3")
        raise RuntimeError("S3 upload failed") from e


# --------------------------------------------------
# Save model to SageMaker output path
# --------------------------------------------------
def save_model_to_sagemaker(model):
    """
    Save model to SageMaker output path.
    SageMaker automatically uploads from /opt/ml/model/ to S3.
    """
    sagemaker_model_path = "/opt/ml/model/"

    if os.path.exists(sagemaker_model_path):
        # Running in SageMaker - save to model output path
        model_file = os.path.join(sagemaker_model_path, MODEL_ARTIFACT)
        joblib.dump(model, model_file)
        logger.info(f"Model saved to SageMaker output path: {model_file}")
    else:
        # Fallback to S3 for local development
        logger.info("SageMaker path not found, falling back to S3 upload")
        save_model_to_s3(model)


# --------------------------------------------------
# Main execution
# --------------------------------------------------
if __name__ == "__main__":
    # Load dataset from SageMaker input path
    crop_df = load_dataset_from_sagemaker()

    X, y = load_data(crop_df)

    best_model, scores = train_and_evaluate(X, y)

    crop_name = predict_crop(
        best_model,
        N=21,
        P=26,
        K=27,
        temperature=27.003155,
        humidity=47.675254,
        ph=5.699587,
        rainfall=95.851183,
    )

    logger.info(f"Recommended crop: {crop_name}")

    save_model_to_sagemaker(best_model)
