#!/bin/bash
set -euo pipefail

# This script sets up Kubernetes resources after Terraform has created the cluster

# Function to display error messages and exit
function error_exit {
    echo "[ERROR] $1" >&2
    exit 1
}

# Function to check if a command exists
function command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if gcloud is installed
if ! command_exists gcloud; then
    error_exit "Google Cloud SDK (gcloud) is not installed."
fi

# Check if kubectl is installed
if ! command_exists kubectl; then
    error_exit "kubectl is not installed."
fi

# Get the project ID from the first argument or try to get it from gcloud config
PROJECT_ID=${1:-}
if [[ -z "$PROJECT_ID" ]]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null || true)
    if [[ -z "$PROJECT_ID" ]]; then
        error_exit "Project ID not provided and could not be determined from gcloud config."
    fi
fi

# Get the region from the second argument or use a default
REGION=${2:-asia-south1}
SA_EMAIL="terraform-ci@${PROJECT_ID}.iam.gserviceaccount.com"

# Ensure we're authenticated with gcloud
echo "Checking gcloud authentication..."
if ! gcloud auth list --filter=status:ACTIVE --format='value(account)' | grep -q .; then
    error_exit "Not authenticated with gcloud. Please run 'gcloud auth login' and set the project with 'gcloud config set project PROJECT_ID'"
fi

# Configure kubectl to use the new cluster
echo "Configuring kubectl for project: ${PROJECT_ID}, region: ${REGION}"
if ! gcloud container clusters get-credentials "${PROJECT_ID}-gke" \
  --region "${REGION}" \
  --project "${PROJECT_ID}" 2>/dev/null; then
    error_exitor "Failed to get cluster credentials. Make sure the cluster exists and you have access to it."
fi

# Check if the cluster is running
CLUSTER_STATUS=$(gcloud container clusters describe "${PROJECT_ID}-gke" \
  --region "${REGION}" \
  --project "${PROJECT_ID}" \
  --format='value(status)' 2>/dev/null || echo "UNKNOWN")

if [[ "$CLUSTER_STATUS" != "RUNNING" ]]; then
    error_exit "Cluster is not in RUNNING state. Current status: ${CLUSTER_STATUS}"
fi

# Create or update Kubernetes secret for Artifact Registry
echo "Creating/updating Kubernetes secret for Artifact Registry..."
if ! kubectl create secret docker-registry artifact-registry-secret \
  --docker-server=asia-south1-docker.pkg.dev \
  --docker-email="${SA_EMAIL}" \
  --docker-username=_json_key \
  --docker-password="$(gcloud auth print-access-token)" \
  --dry-run=client -o yaml | kubectl apply -f -; then
    error_exit "Failed to create/update Kubernetes secret"
fi

echo "✅ Successfully created/updated Kubernetes secret 'artifact-registry-secret'"

# Wait for the default service account to be created
MAX_RETRIES=10
RETRY_COUNT=0
while ! kubectl get serviceaccount default &>/dev/null && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    RETRY_COUNT=$((RETRY_COUNT+1))
    echo "Waiting for default service account to be available (attempt $RETRY_COUNT/$MAX_RETRIES)..."
    sleep 5
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "⚠️  Warning: Default service account not available after $MAX_RETRIES attempts"
else
    echo "✅ Default service account is available"
fi

# Apply Kubernetes manifests
echo "Applying Kubernetes manifests from kubernetes/overlays/dev..."
if [ ! -d "kubernetes/overlays/dev" ]; then
    error_exit "Kubernetes manifests directory not found at kubernetes/overlays/dev"
fi

if ! kubectl apply -k kubernetes/overlays/dev; then
    error_exit "Failed to apply Kubernetes manifests"
fi

echo "✅ Kubernetes setup completed successfully!"

# Display cluster information
echo -e "\n--- Cluster Information ---"
kubectl cluster-info

echo -e "\n--- Deployments ---"
kubectl get deployments --all-namespaces

echo -e "\n--- Pods ---"
kubectl get pods --all-namespaces

echo -e "\n--- Services ---"
kubectl get services --all-namespaces
