# Install Argo CD script
#!/bin/bash
set -e

# Create argocd namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install Argo CD
kubectl apply -k argocd/install

# Wait for Argo CD to be ready
echo "Waiting for Argo CD to be ready..."
kubectl -n argocd wait --for=condition=available --timeout=300s deployment/argocd-server

# Get the initial admin password
echo "Argo CD is installed!"
echo "Initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

echo "Access the UI by running:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "Then open https://localhost:8080 in your browser"

# After Argo CD is ready
kubectl apply -f argocd/root-application.yaml

# Make the script executable
#chmod +x install-argocd.sh