#!/bin/bash
set -euo pipefail

# Set project ID and service account name
PROJECT_ID="zebraan-gcp-zebo-dev"
SA_NAME="terraform-ci"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
BILLING_ACCOUNT_ID="0145CB-EF3F35-97AF52"
REGION="asia-south1"
# Unique bucket name for terraform state for every new project
BUCKET="${PROJECT_ID}-terraform-state" 

# Check if project exists, create if it doesn't
if ! gcloud projects describe "${PROJECT_ID}" >/dev/null 2>&1; then
    echo "Project ${PROJECT_ID} not found, creating..."
    gcloud projects create "${PROJECT_ID}" --name="Zebo AI Wealth Manager"
    
    # Enable billing (uncomment and set your billing account ID)
    gcloud beta billing projects link "${PROJECT_ID}" \
      --billing-account="${BILLING_ACCOUNT_ID}"
    
    # Enable required services
    gcloud services enable \
        container.googleapis.com \
        artifactregistry.googleapis.com \
        secretmanager.googleapis.com \
        iam.googleapis.com \
        cloudresourcemanager.googleapis.com \
        --project "${PROJECT_ID}"
    
    echo "Project ${PROJECT_ID} created and services enabled."
else
    echo "Project ${PROJECT_ID} already exists, continuing..."
fi

# Create service account if it doesn't exist
if ! gcloud iam service-accounts describe "${SA_EMAIL}" --project "${PROJECT_ID}" >/dev/null 2>&1; then
    echo "Creating service account ${SA_NAME}..."
    gcloud iam service-accounts create "${SA_NAME}" \
        --project "${PROJECT_ID}" \
        --display-name "Terraform CI"
    
    # Add a small delay to ensure service account is fully created
    echo "Waiting for service account to be fully created..."
    sleep 10
    
    # Verify service account exists
    if ! gcloud iam service-accounts describe "${SA_EMAIL}" --project "${PROJECT_ID}" >/dev/null 2>&1; then
        echo "ERROR: Failed to verify service account creation. Please try again."
        exit 1
    fi
    echo "Service account ${SA_EMAIL} created successfully."
else
    echo "Service account ${SA_EMAIL} already exists, continuing..."
fi

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

# Create GCS bucket for Terraform state if it doesn't exist

if ! gsutil ls -b gs://${BUCKET} >/dev/null 2>&1; then
    echo "Creating GCS bucket for Terraform state..."
    gsutil mb -p "${PROJECT_ID}" -l "${REGION:-asia-south1}" "gs://${BUCKET}"
    gsutil versioning set on "gs://${BUCKET}"
    echo "GCS bucket gs://${BUCKET} created with versioning enabled."
else
    echo "GCS bucket gs://${BUCKET} already exists, continuing..."
fi

# Set IAM permissions for the bucket
echo "Setting IAM permissions for the GCS bucket..."
gsutil iam ch serviceAccount:${SA_EMAIL}:objectAdmin "gs://${BUCKET}" || true

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