# zebo-infra
This repository contains the infrastructure for zebo AI Assistant.

## zebo Terraform

This repo provisions Google Cloud infrastructure for Zebo:
- Project APIs (enables required services)
- IAM service accounts (as needed by modules)
- Artifact Registry (Docker repository)
- GKE cluster and node pool
- Secret Manager secrets

The Terraform code is organized per environment under `terraform/environments/`.

## Repository structure

```
terraform/
  environments/
    dev/
      main.tf
      variables.tf
      (optionally *.tfvars)
    prod/
      main.tf
      variables.tf
  modules/
    project/
    artifact_registry/
    gke/
    secret_manager/
```

## Prerequisites

- A GCP project with billing enabled (default `project_id` is `zebraan-gcp-zebo-dev`)
- IAM permissions to provision infra (Project Owner or equivalent)
- Terraform >= 1.5.0
- gcloud CLI and kubectl installed

Authenticate once with gcloud and set your default project/region:

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project <YOUR_PROJECT_ID>
```

## Choose your environment

There are two environments available out-of-the-box:
- `terraform/environments/dev/`
- `terraform/environments/prod/`

All commands below assume `dev`. Replace paths with `prod` to deploy production.

## Configure variables

You can keep using the defaults in `terraform/environments/dev/variables.tf` or override them via a `*.tfvars` file. Create `dev.tfvars` alongside `main.tf` with values for your project:

```hcl
project_id         = "zebraan-gcp-zebo-dev"         # your GCP project
region             = "asia-south1"
zone               = "asia-south1-a"

# Artifact Registry
registry_id        = "zebo-registry"

# GKE
cluster_name       = "zebo-gke-cluster"
network_name       = "default"              # set to an existing VPC name if not using default
subnetwork_name    = "default"              # set to an existing subnet name
ip_range_pods      = "10.0.0.0/16"
ip_range_services  = "10.96.0.0/20"
node_machine_type  = "e2-medium"
min_nodes          = 1
max_nodes          = 3

# Secret Manager (key-value map)
secrets = {
  # example: "zerodha_api" = "REPLACE_ME"
}
```

Notes:
- If you are using the default VPC/subnet, ensure the GKE module is configured accordingly. The module defines a custom network/subnet by default; you may set `network_name = "default"` and `subnetwork_name = "default"` and avoid creating custom resources.

## Initialize and apply

From the environment directory:

```bash
cd terraform/environments/dev
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

On success, Terraform will output handy commands/values such as:
- `gke_cluster_name`
- `gcloud_get_credentials` (a ready-to-run gcloud command)
- `artifact_registry_repo` (e.g., `asia-south1-docker.pkg.dev/<project>/<registry>`)

## Connect kubectl to the cluster

Use the output `gcloud_get_credentials` or run manually:

```bash
gcloud container clusters get-credentials <cluster_name> \
  --region <region> \
  --project <project_id>

gcloud container clusters get-credentials dev-gke-cluster --region asia-south1

# View current context
kubectl config current-context

# View all contexts
kubectl config get-contexts

# List nodes in the cluster
kubectl get nodes
```

## Build and push images to Artifact Registry

Authenticate Docker to Artifact Registry and push your images:

```bash
gcloud auth configure-docker <region>-docker.pkg.dev

REPO="$(terraform output -raw artifact_registry_repo)"
IMAGE_NAME="app"   # change as needed
TAG="v0.1.0"

docker build -t ${IMAGE_NAME}:${TAG} .
docker tag ${IMAGE_NAME}:${TAG} ${REPO}/${IMAGE_NAME}:${TAG}
docker push ${REPO}/${IMAGE_NAME}:${TAG}
```

## Manage secrets (Secret Manager)

Secrets are created from the `secrets` map variable. Update your `*.tfvars` and re-apply:

```hcl
secrets = {
  "zerodha_api"     = "..."
  "postgres_pwd"    = "..."
}
```

```bash
terraform apply -var-file=dev.tfvars
```

To rotate a secret, change its value and apply again; Terraform will create a new secret version.

## Destroy

To tear down the environment:

```bash
terraform destroy -var-file=dev.tfvars
```

## Common gotchas

- VPC/Subnet: If using the default network, ensure the GKE module does not attempt to recreate networks/subnets that already exist. Set `network_name = "default"` and `subnetwork_name = "default"`.
- IP ranges: Secondary ranges `pods` and `services` must not overlap existing ranges in your subnet.
- Permissions: Ensure your principal has rights to manage GKE, Artifact Registry, and Secret Manager.

- Deploy application manifests/Helm charts to the GKE cluster.
- Configure Workload Identity if your workload needs to access GCP APIs.

## CI/CD with GitHub Actions (Apply and Destroy)

This repo includes two workflows under `.github/workflows/` for managing the `dev` environment with Terraform:

- `terraform-dev.yaml` — Validate, Plan, and Apply on push to `main`
- `terraform-destroy-dev.yaml` — Manual destroy via workflow_dispatch

### Required repository secrets

Set these in GitHub → `Settings` → `Secrets and variables` → `Actions` → `Secrets`:

- `GCP_CREDENTIALS`: JSON key for a GCP Service Account that can manage the resources and access the Terraform state bucket.
- `GCP_PROJECT_ID`: The GCP project ID (e.g., `zebraan-gcp-zebo-dev`).
- `ZEO_DB_PASSWORD`, `ZEO_OPENAI_KEY`, `ZEO_MF_UTIL_KEY`: Secret Manager values (can be empty; SecretVersion creation is skipped for empty values).

To create the CI service account and key locally, you can use:

```
./create_terraform_service_account.sh
```

This script:

- Creates `terraform-ci@<project>.iam.gserviceaccount.com`.
- Grants required project roles (GKE, Artifact Registry, Secret Manager, IAM, Service Usage, Compute Network, Project IAM Admin).
- Grants `roles/storage.objectAdmin` on the GCS bucket used for Terraform state.
- Grants `roles/iam.serviceAccountUser` on the default Compute Engine service account (required by GKE when using the default node SA).
- Generates `key.json` (gitignored) which should be copied into the `GCP_CREDENTIALS` GitHub secret (then delete the local file).

### Recommended repository variables

Set these in GitHub → `Settings` → `Secrets and variables` → `Actions` → `Variables`:

- `GCP_REGION` (e.g., `asia-south1`)
- `ARTIFACT_REGISTRY_ID` (e.g., `zebo-registry`)
- `NODE_MACHINE_TYPE` (e.g., `e2-small`)
- `MIN_NODES` (e.g., `0`)
- `MAX_NODES` (e.g., `1`)
- `GKE_DELETION_PROTECTION` (default `true`; set to `false` only for destroy runs)

### How the workflows work

- `terraform-dev.yaml` (Apply):
  - On push to `main`, checks out code, authenticates to GCP with `GCP_CREDENTIALS`, writes a `dev.ci.tfvars` using your repo secrets/vars, then runs `terraform init`, `fmt -check`, `validate`, `plan`, and `apply`.

- `terraform-destroy-dev.yaml` (Destroy):
  - Trigger manually via GitHub Actions → "Terraform Destroy Dev" → "Run workflow".
  - Prompts for a confirmation string `destroy`.
  - Writes `dev.ci.tfvars` with `gke_deletion_protection = false`, then runs `terraform plan -destroy` and `terraform destroy`.

### Notes

- The Terraform backend is configured in `terraform/environments/dev/provider.tf` to use a GCS bucket (`zebo-terraform-state`). Ensure the CI SA has access to this bucket.
- If you prefer not to use a JSON key in GitHub, you can migrate the workflows to Google Workload Identity Federation. The `google-github-actions/auth` action supports this; open an issue and we can provide a WIF setup guide.

## Argo CD Setup

### Prerequisites

1. A running GKE cluster (created via Terraform)
2. `kubectl` configured to connect to your cluster
3. `argocd` CLI installed ([installation guide](https://argo-cd.readthedocs.io/en/stable/cli_installation/))

### Installation

1. Make the installation script executable and run it:
   ```bash
   chmod +x install-argocd.sh
   ./install-argocd.sh
   ```
   This will:
   - Create the Argo CD namespace
   - Install Argo CD using Kustomize
   - Wait for Argo CD to be ready
   - Display the initial admin password
   - Apply the root application that manages all other applications

2. Access the Argo CD UI:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```
   Then open https://localhost:8080 in your browser
   - Username: `admin`
   - Password: (from the installation output)

### GitHub OIDC Setup (Optional but Recommended)

1. Create a GitHub OAuth App:
   - Go to GitHub Settings > Developer settings > OAuth Apps > New OAuth App
   - Homepage URL: `https://argocd.your-domain.com` (or `https://localhost:8080` for local testing)
   - Authorization callback URL: `https://argocd.your-domain.com/auth/callback`

2. Update `argocd/config/oidc-config.yaml` with your GitHub OAuth App credentials:
   ```yaml
   oidc.config: |
     name: GitHub
     issuer: https://github.com
     clientID: $github-client-id  # From GitHub OAuth App
     clientSecret: $github-client-secret  # From GitHub OAuth App
     requestedScopes: ["read:org", "user:email"]
   ```

3. Apply the OIDC configuration:
   ```bash
   kubectl apply -f argocd/config/oidc-config.yaml
   kubectl rollout restart deployment argocd-server -n argocd
   ```

### Repository Structure

```
argocd/
  applications/       # ApplicationSet definitions
  config/            # RBAC and OIDC configurations
  install/           # Argo CD installation manifests
  root-application.yaml  # Root application that manages all other applications

kubernetes/
  base/              # Base kustomization and common resources
  overlays/
    dev/             # Development environment configuration
    prod/            # Production environment configuration
```

### Managing Applications

Applications are defined in `argocd/applications/` and automatically synced by Argo CD. The ApplicationSet will automatically discover and manage applications based on the directory structure in `kubernetes/overlays/`.

### GitHub Actions Integration

The repository includes GitHub Actions workflows for:

1. **Deploy to Dev** (`.github/workflows/deploy-dev.yaml`):
   - Triggered on push to main branch
   - Builds and deploys the application to the dev environment

2. **Update Image Tag** (`.github/workflows/update-image-tag.yaml`):
   - Triggered when Dockerfile or deployment manifests change
   - Updates the image tag in the Kubernetes manifests
   - Creates a PR with the changes

### Required GitHub Secrets

Add these secrets to your GitHub repository (Settings > Secrets > Actions):

- `GCP_CREDENTIALS`: JSON key for a GCP Service Account with necessary permissions
- `GCP_PROJECT_ID`: Your GCP project ID
- `GITHUB_TOKEN`: For creating pull requests (default `GITHUB_TOKEN` is usually sufficient)

### Troubleshooting

1. **Argo CD Sync Issues**:
   ```bash
   # Check application status
   argocd app get <app-name>
   
   # View sync status
   argocd app sync <app-name>
   
   # View logs
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
   ```

2. **Access Denied Errors**:
   - Ensure the GCP service account has the necessary IAM permissions
   - Check the Argo CD RBAC configuration in `argocd/config/rbac-config.yaml`

3. **Image Pull Errors**:
   - Ensure the GKE cluster has pull access to the Artifact Registry
   - Check the image pull secret is properly configured





## Clean up the Entire Google Cloud Project

Clean up the entire Google Cloud Project
```bash
unset GOOGLE_APPLICATION_CREDENTIALS
unset CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE
rm /Users/aninda/workspace/git/zebo-infra/key.json

gcloud projects list

gcloud projects delete zebraan-gcp-zebo-dev
```

Create a new Google Cloud Project
```bash
gcloud projects create zebraan-gcp-zebo-dev --name="Zebo AI Wealth manager"
gcloud projects list



## find the project number
```bash
gcloud projects describe $(gcloud config get-value project) --format="value(projectNumber)"
```
