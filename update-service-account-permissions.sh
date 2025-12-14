#!/bin/bash

# Set variables
PROJECT_ID="zebraan-gcp-zebo"
SERVICE_ACCOUNT="terraform-ci@${PROJECT_ID}.iam.gserviceaccount.com"
BUCKET_NAME="zebo-terraform-state"

# Add storage.admin role for the state bucket
gsutil iam ch \
  serviceAccount:${SERVICE_ACCOUNT}:roles/storage.admin \
  gs://${BUCKET_NAME}

# Add storage.objectAdmin role for the state bucket
gsutil iam ch \
  serviceAccount:${SERVICE_ACCOUNT}:roles/storage.objectAdmin \
  gs://${BUCKET_NAME}

echo "Updated IAM permissions for service account ${SERVICE_ACCOUNT} on bucket ${BUCKET_NAME}"
