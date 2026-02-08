# Complete Deployment Guide

This guide walks you through deploying the entire Zebo platform from scratch.

## Prerequisites

- GCP account with billing enabled
- GitHub account with access to zebo-terraform and zebo-infra repos
- Local machine with:
  - `gcloud` CLI installed
  - `kubectl` installed
  - `helm` installed (optional, for local testing)

## Step 1: Set Up GitHub Secrets

In the **zebo-terraform** repository, go to Settings → Secrets and variables → Actions

### Required Secrets:

```
GCP_CREDENTIALS          # Service account JSON key
GCP_PROJECT_ID           # Your GCP project ID (e.g., zebraan-gcp-zebo-dev)
ZEO_DB_PASSWORD          # Database password
ZEO_OPENAI_KEY          # OpenAI API key
ZEO_MF_UTIL_KEY         # Mutual fund utility key
GITHUB_TOKEN            # Auto-provided by GitHub Actions
```

### Required Variables:

```
GCP_REGION              # e.g., asia-south1
NETWORK_NAME            # e.g., dev-gke-network
SUBNETWORK_NAME         # e.g., dev-gke-subnet
IP_RANGE_PODS           # e.g., 10.1.0.0/16
IP_RANGE_SERVICES       # e.g., 10.2.0.0/20
NODE_MACHINE_TYPE       # e.g., e2-medium
MIN_NODES               # e.g., 1
MAX_NODES               # e.g., 5
USE_SPOT_INSTANCES      # e.g., true
GKE_DELETION_PROTECTION # e.g., true
ARGOCD_HOSTNAME         # e.g., argocd.zebo.dev
```

## Step 2: Deploy Infrastructure (via zebo-terraform)

### Option A: GitHub Actions (Recommended)

1. Go to **zebo-terraform** repository
2. Navigate to Actions → "Terraform Create Environment"
3. Click "Run workflow" → "Run workflow"
4. Wait for completion (~10-15 minutes)

The workflow will:
- ✅ Create GKE cluster
- ✅ Install ArgoCD via Helm
- ✅ Configure repository credentials
- ✅ Deploy root ApplicationSet
- ✅ Output ArgoCD admin password

### Option B: Manual Deployment

```bash
# Clone repositories
git clone https://github.com/zebraan-com/zebo-terraform.git
cd zebo-terraform/environments/dev

# Authenticate to GCP
gcloud auth login
gcloud auth application-default login

# Create tfvars file
cat > dev.local.tfvars <<EOF
project_id              = "zebraan-gcp-zebo-dev"
region                  = "asia-south1"
environment             = "dev"
network_name            = "dev-gke-network"
subnetwork_name         = "dev-gke-subnet"
ip_range_pods           = "10.1.0.0/16"
ip_range_services       = "10.2.0.0/20"
node_machine_type       = "e2-medium"
min_nodes               = 1
max_nodes               = 5
use_spot_instances      = true
gke_deletion_protection = true
argocd_hostname         = "argocd.zebo.dev"

secrets = {
  ZEO_DB_PASSWORD = "your-db-password"
  ZEO_OPENAI_KEY  = "your-openai-key"
  ZEO_MF_UTIL_KEY = "your-mf-key"
}
EOF

# Deploy infrastructure
terraform init
terraform plan -var-file=dev.local.tfvars
terraform apply -var-file=dev.local.tfvars

# Get kubectl credentials
gcloud container clusters get-credentials dev-gke-cluster \
  --region asia-south1 \
  --project zebraan-gcp-zebo-dev

# Install ArgoCD
kubectl create namespace argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  -f argocd-values.yaml \
  --wait

# Create repository credentials
kubectl create secret generic zebo-infra-repo \
  --from-literal=type=git \
  --from-literal=url=https://github.com/zebraan-com/zebo-infra.git \
  --from-literal=username=not-used \
  --from-literal=password=YOUR_GITHUB_TOKEN \
  -n argocd

kubectl label secret zebo-infra-repo \
  argocd.argoproj.io/secret-type=repository \
  -n argocd

# Apply root ApplicationSet
kubectl apply -f https://raw.githubusercontent.com/zebraan-com/zebo-infra/main/argocd/root-app.yaml

# Get ArgoCD password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

## Step 3: Access ArgoCD UI

```bash
# Port forward to ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser
open https://localhost:8080
```

Login:
- Username: `admin`
- Password: (from Step 2 output)

You should see:
- **dev-apps** - ApplicationSet managing dev environment
- **zebo-app-dev** - Your application

## Step 4: Verify Deployment

### Check Applications

```bash
# List all applications
kubectl get applications -n argocd

# Expected output:
# NAME            SYNC STATUS   HEALTH STATUS
# dev-apps        Synced        Healthy
# zebo-app-dev    Synced        Healthy
```

### Check Application Pods

```bash
# Check zebo-app pods
kubectl get pods -n zebo-dev

# Expected output:
# NAME                        READY   STATUS    RESTARTS
# zebo-app-XXXXXXXXX-XXXXX   1/1     Running   0
```

### Check Service

```bash
# Check service
kubectl get svc -n zebo-dev

# Port forward to test
kubectl port-forward svc/zebo-app -n zebo-dev 8000:80

# Test
curl http://localhost:8000
```

## Step 5: Deploy Additional Applications

### Create New Application

1. Create Helm chart in zebo-infra:

```bash
cd /path/to/zebo-infra
cd charts/
helm create my-new-service

# Edit Chart.yaml, values.yaml, templates/
```

2. Create environment values:

```yaml
# charts/my-new-service/values-dev.yaml
image:
  repository: asia-south1-docker.pkg.dev/zebraan-gcp-zebo-dev/zebo-registry/my-new-service
  tag: latest
replicaCount: 1
```

3. Create Application manifest:

```yaml
# apps/dev/my-new-service.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-new-service-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/zebraan-com/zebo-infra.git
    targetRevision: HEAD
    path: charts/my-new-service
    helm:
      releaseName: my-new-service
      valueFiles:
      - values-dev.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: my-new-service-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

4. Commit and push:

```bash
git add .
git commit -m "feat: add my-new-service"
git push origin main
```

5. ArgoCD will automatically deploy within 3 minutes.

## Step 6: Deploy to Production

### Create Production Environment

1. Copy dev app to prod:

```bash
# apps/prod/zebo-app.yaml
# Change metadata.name to zebo-app-prod
# Change namespace to zebo-prod
# Change valueFiles to values-prod.yaml
```

2. Create production values:

```yaml
# charts/zebo-app/values-prod.yaml
image:
  repository: asia-south1-docker.pkg.dev/zebraan-gcp-zebo-prod/zebo-registry/zebo-app
  tag: v1.0.0  # Use semantic versioning
replicaCount: 3
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi
```

3. Commit and push:

```bash
git add apps/prod/ charts/zebo-app/values-prod.yaml
git commit -m "feat: add production deployment"
git push origin main
```

## Updating Applications

### Update Image Tag

**Automated (via CI):**
- Push code to `zebo` repository
- CI builds Docker image
- CI updates `charts/zebo-app/values-dev.yaml`
- ArgoCD syncs automatically

**Manual:**
```bash
# Edit charts/zebo-app/values-dev.yaml
image:
  tag: sha-abc123

git commit -am "chore: update image tag"
git push origin main
```

### Scale Application

```bash
# Edit charts/zebo-app/values-dev.yaml
replicaCount: 3

git commit -am "scale: increase replicas to 3"
git push origin main
```

### Update Configuration

```bash
# Edit charts/zebo-app/values-dev.yaml
env:
  - name: LOG_LEVEL
    value: "debug"

git commit -am "config: set log level to debug"
git push origin main
```

## Monitoring and Debugging

### View Application Logs

```bash
# ArgoCD application logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Application pod logs
kubectl logs -n zebo-dev -l app=zebo-app -f
```

### Check Sync Status

In ArgoCD UI:
- Green = Synced and Healthy
- Yellow = OutOfSync or Progressing
- Red = Degraded or Failed

### Manual Sync

```bash
# Force sync via kubectl
kubectl patch application zebo-app-dev -n argocd \
  --type merge \
  --patch '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# Or use ArgoCD CLI
argocd app sync zebo-app-dev
```

### Rollback

**Via ArgoCD UI:**
1. Click on application
2. History tab
3. Select previous revision
4. Click "Rollback"

**Via Git:**
```bash
# Revert the commit
git revert HEAD
git push origin main
```

## Cleanup

### Delete Applications

```bash
# Delete specific app
kubectl delete application zebo-app-dev -n argocd

# Delete all apps
kubectl delete applications --all -n argocd
```

### Destroy Infrastructure

**Via GitHub Actions:**
1. Go to zebo-terraform → Actions → "Terraform Destroy"
2. Run workflow
3. Enter confirmation string: `destroy`

**Manual:**
```bash
cd zebo-terraform/environments/dev
terraform destroy -var-file=dev.local.tfvars
```

## Troubleshooting

### ArgoCD UI Not Accessible

```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Restart port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Check service
kubectl get svc -n argocd argocd-server
```

### Application Stuck in Progressing

```bash
# Check application events
kubectl describe application zebo-app-dev -n argocd

# Check pod events
kubectl describe pod -n zebo-dev -l app=zebo-app

# Check pod logs
kubectl logs -n zebo-dev -l app=zebo-app
```

### Image Pull Errors

```bash
# Verify image exists
gcloud artifacts docker images list \
  asia-south1-docker.pkg.dev/zebraan-gcp-zebo-dev/zebo-registry

# Check image pull secret (if needed)
kubectl get secrets -n zebo-dev
```

### Sync Failing

```bash
# Check for validation errors
helm template charts/zebo-app -f charts/zebo-app/values-dev.yaml

# Dry-run
kubectl apply --dry-run=client -f <(helm template charts/zebo-app -f charts/zebo-app/values-dev.yaml)
```

## Best Practices

1. **Always test in dev first** before deploying to prod
2. **Use semantic versioning** for production image tags
3. **Enable automated sync** for faster deployments
4. **Use resource limits** to prevent resource starvation
5. **Monitor ArgoCD metrics** for sync failures
6. **Keep values files small** - use ConfigMaps/Secrets for large configs
7. **Use sync waves** for ordered deployments when needed
8. **Enable notifications** for sync failures (Slack, email)

## Support

For issues or questions:
- Check ArgoCD docs: https://argo-cd.readthedocs.io
- Check Helm docs: https://helm.sh/docs
- Open an issue in the repository
