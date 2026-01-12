# 🚀 Quick Start - Deploy Zebo to GKE

## Prerequisites Checklist
- [ ] GCP project: `zebraan-gcp-zebo-dev`
- [ ] gcloud CLI authenticated
- [ ] Docker installed
- [ ] kubectl installed

## 5-Minute Deployment

### 1️⃣ Test Locally (Optional but Recommended)
```bash
cd zebo/zebo
uv run uvicorn zebo.main:app --reload --host 0.0.0.0 --port 8000

# In another terminal:
chmod +x test_endpoints.sh
./test_endpoints.sh http://localhost:8000
```

### 2️⃣ Build & Push Docker Image
```bash
# Configure Docker auth
gcloud auth configure-docker asia-south1-docker.pkg.dev

# Build
cd zebo/zebo
docker build -t asia-south1-docker.pkg.dev/zebraan-gcp-zebo-dev/zebo-registry/zebo-app:latest .

# Push
docker push asia-south1-docker.pkg.dev/zebraan-gcp-zebo-dev/zebo-registry/zebo-app:latest
```

### 3️⃣ Deploy Infrastructure (If Not Done)
```bash
cd ../../zebo-infra/terraform/environments/dev
terraform init
terraform apply -var-file=dev.tfvars  # Takes ~10-15 minutes

# Get cluster credentials
gcloud container clusters get-credentials dev-gke-cluster \
  --region asia-south1 \
  --project zebraan-gcp-zebo-dev
```

### 4️⃣ Deploy Application
```bash
cd ../../../kubernetes/overlays/dev
kubectl apply -k .
```

### 5️⃣ Monitor & Test
```bash
# Watch deployment
kubectl get pods -l app=zebo -w

# Get external IP (wait for EXTERNAL-IP to appear)
kubectl get svc zebo-service-dev

# Test (replace <EXTERNAL_IP>)
curl http://<EXTERNAL_IP>/
curl http://<EXTERNAL_IP>/health
curl http://<EXTERNAL_IP>/ready
```

## 🎯 Expected Results

```bash
$ curl http://<EXTERNAL_IP>/
{"message":"CrewAI API is up and running!"}

$ curl http://<EXTERNAL_IP>/health
{"status":"healthy"}

$ curl http://<EXTERNAL_IP>/ready
{"status":"ready"}

$ kubectl get pods -l app=zebo
NAME                          READY   STATUS    RESTARTS   AGE
zebo-app-dev-xxxxxxxxx-xxxxx  1/1     Running   0          2m
```

## 🔥 Troubleshooting Quick Fixes

**Pods not starting?**
```bash
kubectl logs -l app=zebo --tail=50
kubectl describe pod -l app=zebo
```

**LoadBalancer stuck pending?**
```bash
# Wait 3-5 minutes, GCP needs time to provision
kubectl get svc zebo-service-dev -w
```

**Image pull errors?**
```bash
# Verify image exists
gcloud artifacts docker images list asia-south1-docker.pkg.dev/zebraan-gcp-zebo-dev/zebo-registry
```

## 📊 What's Deployed

- **GKE Cluster:** dev-gke-cluster (asia-south1)
- **Node Pool:** 0-3 nodes (e2-medium)
- **Application:** zebo-app-dev
- **Service:** zebo-service-dev (LoadBalancer)
- **Ports:** 8000 (container), 80 (service)
- **Health Checks:** /health, /ready

## 🧹 Cleanup

```bash
# Delete application
kubectl delete -k kubernetes/overlays/dev

# Destroy infrastructure
cd terraform/environments/dev
terraform destroy -var-file=dev.tfvars
```

## 📚 More Details

- Full deployment guide: `zebo/zebo/DEPLOY.md`
- Infrastructure review: `zebo-infra/DEPLOYMENT_GUIDE.md`
- Test script: `zebo/zebo/test_endpoints.sh`

---

**Need help?** Check the logs: `kubectl logs -f -l app=zebo`
