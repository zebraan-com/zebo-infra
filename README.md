# Zebo Infrastructure - Application Deployment

This repository contains all ArgoCD configurations and Helm charts for deploying Zebo applications across different environments.

## Repository Structure

```
zebo-infra/
├── argocd/                    # ArgoCD configurations
│   └── root-app.yaml         # Root ApplicationSet (discovers all apps)
├── apps/                      # Application manifests per environment
│   ├── dev/
│   │   └── zebo-app.yaml    # Dev environment app definition
│   └── prod/
│       └── zebo-app.yaml    # Prod environment app definition
├── charts/                    # Helm charts
│   └── zebo-app/
│       ├── Chart.yaml
│       ├── values.yaml       # Default values
│       ├── values-dev.yaml   # Dev-specific overrides
│       ├── values-prod.yaml  # Prod-specific overrides
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           └── _helpers.tpl
└── backup/                    # Old deployment configs (ignored)
```

## Strategy

**This repository is for APPLICATION deployment only**

- All ArgoCD Application/ApplicationSet definitions live here
- All Helm charts for applications live here
- Environment-specific values are in `values-ENV.yaml` files
- The `zebo-terraform` repository handles GCP infrastructure

## How It Works

### 1. Root ApplicationSet

The `argocd/root-app.yaml` is an ApplicationSet that automatically discovers all apps:

```yaml
# Discovers all directories in apps/*
# Creates ArgoCD Applications for each environment
```

This means:
- Add a new file to `apps/dev/my-new-app.yaml` → automatically deployed to dev
- Add a new file to `apps/prod/my-new-app.yaml` → automatically deployed to prod

### 2. Application Definitions

Each application (e.g., `apps/dev/zebo-app.yaml`) points to a Helm chart:

```yaml
spec:
  source:
    path: charts/zebo-app     # Points to Helm chart
    helm:
      valueFiles:
      - values-dev.yaml        # Environment-specific values
```

### 3. Helm Charts

Helm charts in `charts/` directory:
- `Chart.yaml` - Chart metadata
- `values.yaml` - Default values
- `values-dev.yaml` - Dev environment overrides
- `values-prod.yaml` - Prod environment overrides
- `templates/` - Kubernetes manifests

## Adding a New Application

### Step 1: Create Helm Chart

```bash
cd charts/
helm create my-new-app

# Edit the chart templates and values
```

### Step 2: Create Environment Values

```bash
# charts/my-new-app/values-dev.yaml
image:
  repository: asia-south1-docker.pkg.dev/zebraan-gcp-zebo-dev/zebo-registry/my-new-app
  tag: latest
replicaCount: 1
```

```bash
# charts/my-new-app/values-prod.yaml
image:
  repository: asia-south1-docker.pkg.dev/zebraan-gcp-zebo-prod/zebo-registry/my-new-app
  tag: v1.0.0
replicaCount: 3
```

### Step 3: Create Application Manifest

```bash
# apps/dev/my-new-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-new-app-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/zebraan-com/zebo-infra.git
    targetRevision: HEAD
    path: charts/my-new-app
    helm:
      releaseName: my-new-app
      valueFiles:
      - values-dev.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: my-new-app-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

### Step 4: Commit and Push

```bash
git add .
git commit -m "feat: add my-new-app"
git push origin main
```

ArgoCD will automatically:
1. Detect the new application
2. Create it in the cluster
3. Deploy using the Helm chart
4. Keep it in sync with the repository

## Deploying to Production

Simply create the prod version:

```bash
# apps/prod/my-new-app.yaml
# (same as dev but with values-prod.yaml)
```

## Updating Applications

### Update Image Tag

```bash
# Edit charts/zebo-app/values-dev.yaml
image:
  tag: sha-abc123  # New image tag

git commit -am "chore: update zebo-app to sha-abc123"
git push origin main
```

ArgoCD will automatically sync the change within minutes.

### Update Configuration

```bash
# Edit charts/zebo-app/values-dev.yaml
replicaCount: 3  # Scale up

git commit -am "scale: increase zebo-app replicas to 3"
git push origin main
```

## ArgoCD Access

After deployment via `zebo-terraform`, access ArgoCD:

```bash
# Port forward to ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

Open: https://localhost:8080
- Username: `admin`
- Password: (from command above)

## Troubleshooting

### Check Applications

```bash
# List all applications
kubectl get applications -n argocd

# Check specific app
kubectl describe application zebo-app-dev -n argocd

# Check ApplicationSet
kubectl get applicationset -n argocd
```

### Check Sync Status

```bash
# Via kubectl
kubectl get application zebo-app-dev -n argocd -o jsonpath='{.status.sync.status}'

# Via ArgoCD CLI (if installed)
argocd app get zebo-app-dev
```

### Force Sync

```bash
# Via ArgoCD UI
# Click on application → SYNC → SYNCHRONIZE

# Via CLI
argocd app sync zebo-app-dev

# Via kubectl
kubectl patch application zebo-app-dev -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### View Logs

```bash
# ArgoCD controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100

# ArgoCD server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=100

# Application pod logs
kubectl logs -n zebo-dev -l app=zebo-app
```

### Common Issues

**App not showing up:**
- Check root ApplicationSet: `kubectl get applicationset -n argocd`
- Verify repo credentials: `kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=repository`
- Check ApplicationSet logs: `kubectl logs -n argocd -l app.kubernetes.io/component=applicationset-controller`

**Sync failing:**
- Check application status: `kubectl describe application zebo-app-dev -n argocd`
- Verify Helm chart is valid: `helm template charts/zebo-app -f charts/zebo-app/values-dev.yaml`
- Check image exists: Verify image tag in Artifact Registry

**Can't access ArgoCD UI:**
- Verify ArgoCD is running: `kubectl get pods -n argocd`
- Check port forward: `kubectl port-forward svc/argocd-server -n argocd 8080:443`
- Try accessing via: `https://localhost:8080` (not http)

## CI/CD Integration

See `.github/workflows/update-image-tag.yaml` for automated image tag updates.

## Best Practices

1. **Always use environment-specific value files** (`values-dev.yaml`, `values-prod.yaml`)
2. **Never hardcode secrets** in values files - use Secret Manager and external-secrets
3. **Use semantic versioning** for image tags in production
4. **Test in dev** before promoting to prod
5. **Use ArgoCD sync waves** for ordered deployments (if needed)
6. **Enable automated sync** for faster deployments
7. **Use prune and self-heal** for consistency

## Related Repositories

- **zebo-terraform**: Infrastructure provisioning (GKE, VPC, ArgoCD installation)
- **zebo**: Application source code and Docker images

## License

Apache-2.0
