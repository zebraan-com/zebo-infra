# Post-Migration Checklist

Use this checklist after committing the restructured repositories.

## Pre-Deployment Checklist

### GitHub Secrets (zebo-terraform repo)

Go to: Settings → Secrets and variables → Actions → Secrets

- [ ] `GCP_CREDENTIALS` - Service account JSON key
- [ ] `GCP_PROJECT_ID` - e.g., `zebraan-gcp-zebo-dev`
- [ ] `ZEO_DB_PASSWORD` - Database password
- [ ] `ZEO_OPENAI_KEY` - OpenAI API key
- [ ] `ZEO_MF_UTIL_KEY` - Mutual fund utility key
- [ ] `GITHUB_TOKEN` - Should be auto-available

### GitHub Variables (zebo-terraform repo)

Go to: Settings → Secrets and variables → Actions → Variables

- [ ] `GCP_REGION` = `asia-south1`
- [ ] `NETWORK_NAME` = `dev-gke-network`
- [ ] `SUBNETWORK_NAME` = `dev-gke-subnet`
- [ ] `IP_RANGE_PODS` = `10.1.0.0/16`
- [ ] `IP_RANGE_SERVICES` = `10.2.0.0/20`
- [ ] `NODE_MACHINE_TYPE` = `e2-medium`
- [ ] `MIN_NODES` = `1`
- [ ] `MAX_NODES` = `5`
- [ ] `USE_SPOT_INSTANCES` = `true`
- [ ] `GKE_DELETION_PROTECTION` = `true`
- [ ] `ARGOCD_HOSTNAME` = `argocd.zebo.dev`

### Repository Commits

- [ ] Committed changes to zebo-infra
- [ ] Pushed zebo-infra to main branch
- [ ] Committed changes to zebo-terraform
- [ ] Pushed zebo-terraform to main branch

## Deployment Checklist

### Step 1: Deploy Infrastructure

#### Via GitHub Actions:
- [ ] Go to zebo-terraform → Actions
- [ ] Click "Terraform Create Environment"
- [ ] Click "Run workflow" → "Run workflow"
- [ ] Wait for green checkmark (~10-15 min)
- [ ] Note down ArgoCD password from logs

#### Or Manual:
- [ ] `cd zebo-terraform/environments/dev`
- [ ] `terraform init`
- [ ] `terraform apply -var-file=dev.tfvars`
- [ ] Get kubectl credentials
- [ ] Install ArgoCD
- [ ] Create repo credentials
- [ ] Apply root ApplicationSet

### Step 2: Verify ArgoCD Installation

```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Should see:
# argocd-application-controller-... RUNNING
# argocd-server-...                 RUNNING
# argocd-repo-server-...            RUNNING
# argocd-applicationset-controller  RUNNING
# argocd-redis-...                  RUNNING
```

- [ ] All ArgoCD pods running
- [ ] argocd-server pod ready
- [ ] argocd-application-controller pod ready

### Step 3: Verify Repository Connection

```bash
# Check repository secret
kubectl get secret zebo-infra-repo -n argocd

# Should exist with label:
# argocd.argoproj.io/secret-type: repository
```

- [ ] Repository secret exists
- [ ] Label is correctly set

### Step 4: Verify ApplicationSet

```bash
# Check ApplicationSet
kubectl get applicationset -n argocd

# Should see:
# NAME         AGE
# zebo-apps    Xm
```

- [ ] ApplicationSet `zebo-apps` exists
- [ ] ApplicationSet is synced

### Step 5: Verify Applications Created

```bash
# Check applications
kubectl get applications -n argocd

# Should see:
# NAME            SYNC STATUS   HEALTH STATUS   AGE
# dev-apps        Synced        Healthy         Xm
# zebo-app-dev    Synced        Healthy         Xm
```

- [ ] `dev-apps` application exists
- [ ] `zebo-app-dev` application exists
- [ ] Both are Synced
- [ ] Both are Healthy

### Step 6: Verify App Deployment

```bash
# Check zebo-app namespace
kubectl get ns zebo-dev

# Check pods
kubectl get pods -n zebo-dev

# Should see:
# zebo-app-XXXXXXXXX-XXXXX   1/1   Running   0   Xm
```

- [ ] Namespace `zebo-dev` created
- [ ] zebo-app pod(s) running
- [ ] Pod status is Running
- [ ] Pod ready is 1/1

### Step 7: Access ArgoCD UI

```bash
# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

- [ ] Port forward working
- [ ] Can access https://localhost:8080
- [ ] Can login with admin + password
- [ ] Can see applications in UI

### Step 8: Test Application

```bash
# Port forward to app
kubectl port-forward svc/zebo-app -n zebo-dev 8000:80

# Test
curl http://localhost:8000
```

- [ ] Service exists
- [ ] Can access application
- [ ] Application responds correctly

## Post-Deployment Verification

### ArgoCD Health Check

- [ ] All apps show "Synced" status
- [ ] All apps show "Healthy" status
- [ ] No sync errors in ArgoCD UI
- [ ] No warnings in application details

### Application Health Check

- [ ] Pods are running (not CrashLoopBackOff)
- [ ] Services are created
- [ ] Endpoints exist for services
- [ ] Application logs show no errors

### Git Integration Check

Make a test change:

```bash
# Edit zebo-infra/charts/zebo-app/values-dev.yaml
# Change replicaCount from 1 to 2
# Commit and push

# Wait 3 minutes
# Check if ArgoCD synced the change
kubectl get deployment -n zebo-dev zebo-app
# Should show 2/2 replicas
```

- [ ] Made test change to values
- [ ] Committed and pushed
- [ ] ArgoCD detected change (within 3 min)
- [ ] Change was applied to cluster
- [ ] Rollback test change

## Troubleshooting

If any checks fail:

### ArgoCD Pods Not Running
```bash
kubectl describe pod -n argocd <pod-name>
kubectl logs -n argocd <pod-name>
```

### Applications Not Created
```bash
kubectl logs -n argocd -l app.kubernetes.io/component=applicationset-controller
kubectl describe applicationset zebo-apps -n argocd
```

### Applications Not Syncing
```bash
kubectl describe application zebo-app-dev -n argocd
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Application Pods Not Running
```bash
kubectl describe pod -n zebo-dev <pod-name>
kubectl logs -n zebo-dev <pod-name>
```

## Cleanup (if needed)

To start fresh:

```bash
# Delete all applications
kubectl delete applications --all -n argocd

# Delete ApplicationSet
kubectl delete applicationset zebo-apps -n argocd

# Reapply root app
kubectl apply -f https://raw.githubusercontent.com/zebraan-com/zebo-infra/main/argocd/root-app.yaml
```

## Success Criteria

✅ All items in this checklist are checked
✅ ArgoCD UI accessible at https://localhost:8080
✅ Applications visible and healthy in ArgoCD
✅ Application pods running in cluster
✅ Can access application via port-forward
✅ Git changes automatically sync within 3 minutes

## Next Steps After Success

1. **Set up production environment**
   - Deploy prod cluster via zebo-terraform
   - Verify apps/prod/ applications deploy

2. **Configure CI/CD for image updates**
   - Set up GitHub Actions in zebo app repo
   - Auto-update image tags in values files

3. **Set up monitoring**
   - Configure Prometheus/Grafana
   - Set up alerting

4. **Configure ingress**
   - Set up ingress controller
   - Configure DNS
   - Set up SSL/TLS

5. **Security hardening**
   - Set up network policies
   - Configure RBAC
   - Enable pod security policies

## Support

If issues persist:
- Check DEPLOYMENT_GUIDE.md for detailed troubleshooting
- Review ArgoCD logs
- Check GitHub Actions workflow logs
- Open issue in repository
