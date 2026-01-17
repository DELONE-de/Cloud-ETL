#!/usr/bin/env python3
import boto3
import tarfile
import pickle
import os
from sklearn.ensemble import RandomForestClassifier
import numpy as np

# Create a dummy model
model = RandomForestClassifier(n_estimators=10, random_state=42)
X_dummy = np.random.rand(100, 7)  # 7 features: N, P, K, temperature, humidity, ph, rainfall
y_dummy = np.random.randint(0, 22, 100)  # 22 crop classes
model.fit(X_dummy, y_dummy)

# Save model
os.makedirs('model', exist_ok=True)
with open('model/model.pkl', 'wb') as f:
    pickle.dump(model, f)

# Create tar.gz
with tarfile.open('model.tar.gz', 'w:gz') as tar:
    tar.add('model/model.pkl', arcname='model.pkl')

# Upload to S3
s3 = boto3.client('s3')
bucket_name = 'cloud-etl-model-artifacts'

# Create bucket if it doesn't exist
try:
    s3.create_bucket(Bucket=bucket_name)
    print(f"Created bucket {bucket_name}")
except s3.exceptions.BucketAlreadyExists:
    print(f"Bucket {bucket_name} already exists")
except Exception as e:
    print(f"Error creating bucket: {e}")

# Upload model
s3.upload_file('model.tar.gz', bucket_name, 'models/model.tar.gz')
print("Uploaded model.tar.gz to S3")

# Clean up
os.remove('model.tar.gz')
os.remove('model/model.pkl')
os.rmdir('model')