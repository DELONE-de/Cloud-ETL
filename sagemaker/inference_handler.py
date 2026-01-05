# inference.py
import json
import joblib
import numpy as np
import os
import logging

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# Crop label mapping (must match training)
CROP_MAPPING = {
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
# Load model (called once when container starts)
# --------------------------------------------------
def model_fn(model_dir):
    model_path = os.path.join(model_dir, "crop_recommendation_model.joblib")
    logger.info(f"Loading model from {model_path}")
    return joblib.load(model_path)


# --------------------------------------------------
# Deserialize input
# --------------------------------------------------
def input_fn(request_body, content_type):
    if content_type != "application/json":
        raise ValueError("Unsupported content type")

    payload = json.loads(request_body)

    features = [
        payload["N"],
        payload["P"],
        payload["K"],
        payload["temperature"],
        payload["humidity"],
        payload["ph"],
        payload["rainfall"],
    ]

    return np.array([features], dtype=float)


# --------------------------------------------------
# Prediction
# --------------------------------------------------
def predict_fn(input_data, model):
    prediction = model.predict(input_data)[0]
    crop_name = CROP_MAPPING.get(int(prediction), "Unknown Crop")

    return {
        "predicted_label": int(prediction),
        "crop": crop_name,
    }


# --------------------------------------------------
# Serialize output
# --------------------------------------------------
def output_fn(prediction, accept):
    if accept != "application/json":
        raise ValueError("Unsupported accept type")

    return json.dumps(prediction), accept
