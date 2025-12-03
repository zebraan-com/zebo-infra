#!/bin/bash
set -euo pipefail

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

# Allow the CI SA to use the default Compute Engine service account (required by GKE when using default SA)
PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')
DEFAULT_COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

gcloud iam service-accounts add-iam-policy-binding "${DEFAULT_COMPUTE_SA}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.serviceAccountUser" \
  --project "${PROJECT_ID}"

echo "Granted roles/iam.serviceAccountUser on ${DEFAULT_COMPUTE_SA} to ${SA_EMAIL}"

# Create a service account key and save it to a file

gcloud iam service-accounts keys create key.json \
  --iam-account "${SA_EMAIL}" \
  --project "${PROJECT_ID}"

echo "Created service account key at key.json (remember to add it to GitHub Actions secret GCP_CREDENTIALS and then delete the local file)"