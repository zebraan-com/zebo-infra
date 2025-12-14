# Kubernetes Manifests

This directory contains the Kubernetes manifests for deploying the Zebo application.

## Directory Structure

- `base/`: Base manifests that are common across all environments
- `overlays/`: Environment-specific customizations
  - `dev/`: Development environment
  - `prod/`: Production environment

## Deploying

Deployment is managed by Argo CD. To deploy:

1. Make your changes to the manifests
2. Commit and push to the main branch
3. Argo CD will automatically sync the changes