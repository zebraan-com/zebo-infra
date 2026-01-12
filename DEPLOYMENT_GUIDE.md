# Deployment Guide for Zebo REST API

## 🚀 Quick Deployment Steps

### Prerequisites
- GCP account with project `zebraan-gcp-zebo-dev`
- `gcloud` CLI installed and authenticated
- `kubectl` installed
- Docker installed
- Terraform installed

### Step 1: Initialize Terraform

```bash
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Review the plan
terraform plan -var-file=dev.tfvars

# Apply (create GKE cluster - takes ~10-15 minutes)
terraform apply -var-file=dev.tfvars
```

### Step 2: Configure kubectl

```bash
# Get credentials for the cluster
gcloud container clusters get-credentials dev-gke-cluster \
  --region asia-south1 \
  --project zebraan-gcp-zebo-dev
```

### Step 3: Build and Push Docker Image

Create a simple Python app:

**app.py**
```python
from fastapi import FastAPI
import uvicorn

app = FastAPI()

@app.get("/")
async def root():
    return {"message": "hi"}

@app.get("/health")
async def health():
    return {"status": "healthy"}

@app.get("/ready")
async def ready():
    return {"status": "ready"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

**Dockerfile**
```dockerfile
FROM python:3.11-slim

WORKDIR /app

RUN pip install fastapi uvicorn

COPY app.py .

EXPOSE 8000

CMD ["python", "app.py"]
```

**Build and Push:**
```bash
# Configure Docker to use gcloud authentication
gcloud auth configure-docker asia-south1-docker.pkg.dev

# Build the image
docker build -t asia-south1-docker.pkg.dev/zebraan-gcp-zebo-dev/zebo-registry/zebo-app:latest .

# Push to Artifact Registry
docker push asia-south1-docker.pkg.dev/zebraan-gcp-zebo-dev/zebo-registry/zebo-app:latest
```

### Step 4: Deploy to Kubernetes

```bash
cd ../../kubernetes/overlays/dev

# Apply the Kubernetes manifests
kubectl apply -k .

# Check deployment status
kubectl get pods
kubectl get svc

# Get the LoadBalancer IP (may take a few minutes)
kubectl get svc zebo-service-dev -w
```

### Step 5: Test Your API

Once the LoadBalancer gets an EXTERNAL-IP:

```bash
# Get the external IP
export EXTERNAL_IP=$(kubectl get svc zebo-service-dev -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test the API
curl http://$EXTERNAL_IP/
# Expected: {"message":"hi"}

curl http://$EXTERNAL_IP/health
# Expected: {"status":"healthy"}
```

## 🔧 Troubleshooting

### Pods not starting?
```bash
# Check pod logs
kubectl logs -l app=zebo --tail=50

# Describe pod for events
kubectl describe pod -l app=zebo
```

### Can't pull image?
```bash
# Create image pull secret (if needed)
kubectl create secret docker-registry artifact-registry-secret \
  --docker-server=asia-south1-docker.pkg.dev \
  --docker-username=_json_key \
  --docker-password="$(cat ~/key.json)" \
  --docker-email=your-email@example.com

# Uncomment imagePullSecrets in deployment.yaml
```

### LoadBalancer pending?
```bash
# Check service events
kubectl describe svc zebo-service-dev

# Sometimes takes 3-5 minutes for GCP to provision
```

## 📊 Monitoring

```bash
# Watch pods
kubectl get pods -w

# Check logs in real-time
kubectl logs -f -l app=zebo

# Check cluster nodes
kubectl get nodes
```

## 🧹 Cleanup

```bash
# Delete Kubernetes resources
kubectl delete -k kubernetes/overlays/dev

# Destroy Terraform infrastructure
cd terraform/environments/dev
terraform destroy -var-file=dev.tfvars
```

## 💡 Next Steps for MCP Server

When you're ready to run an MCP server:

1. **Add MCP dependencies** to your Python app
2. **Update environment variables** in `terraform/environments/dev/dev.tfvars` secrets
3. **Modify the Dockerfile** to install MCP packages
4. **Update health checks** if MCP uses different endpoints
5. **Consider using Ingress** instead of LoadBalancer for better routing

## 📝 Cost Optimization

Current setup:
- **Min nodes: 0** - Cluster scales down when idle (costs ~$0)
- **Max nodes: 3** - Prevents runaway costs
- **e2-medium instances** - ~$24/month per node when running
- **LoadBalancer** - ~$18/month

**Estimated monthly cost when idle: ~$18** (just LoadBalancer)
**Estimated monthly cost when active (1 node): ~$42**
