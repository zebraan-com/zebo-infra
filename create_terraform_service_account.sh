#!/bin/bash

# Set project ID and service account name
PROJECT_ID="zebraan-gcp-zebo"
SA_NAME="terraform-ci"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud iam service-accounts create "${SA_NAME}" \
  --project "${PROJECT_ID}" \
  --display-name "Terraform CI"

# Grant required permissions to the service account
for ROLE in \
  roles/container.admin \
  roles/artifactregistry.admin \
  roles/secretmanager.admin \
  roles/serviceusage.serviceUsageAdmin \
  roles/compute.networkAdmin \
  roles/iam.serviceAccountAdmin \
  roles/resourcemanager.projectIamAdmin
do
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="${ROLE}"
done

# Grant required permissions to the service account for the terraform state bucket
BUCKET="zebo-terraform-state"

gcloud storage buckets add-iam-policy-binding "gs://${BUCKET}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.objectAdmin" \
  --project "${PROJECT_ID}"

# Create a service account key and save it to a file

gcloud iam service-accounts keys create key.json \
  --iam-account "${SA_EMAIL}" \
  --project "${PROJECT_ID}"