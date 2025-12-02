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

- A GCP project with billing enabled (default `project_id` is `zebraan-gcp-zebo`)
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
project_id         = "zebraan-gcp-zebo"         # your GCP project
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