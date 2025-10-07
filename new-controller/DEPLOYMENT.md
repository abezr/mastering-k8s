# Kubernetes Controller Deployment Guide

This guide provides comprehensive instructions for deploying and testing the Kubernetes controller in various environments.

## Table of Contents

- [Quick Start](#quick-start)
- [Local Development Setup](#local-development-setup)
  - [Kind (Kubernetes in Docker)](#kind-kubernetes-in-docker)
  - [Minikube](#minikube)
  - [Docker Desktop](#docker-desktop)
- [Containerized Environments](#containerized-environments)
  - [GitHub Codespaces](#github-codespaces)
- [Deployment Methods](#deployment-methods)
  - [Using Deployment Scripts](#using-deployment-scripts)
  - [Using Makefile Targets](#using-makefile-targets)
  - [Manual Deployment](#manual-deployment)
- [Testing and Validation](#testing-and-validation)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## Quick Start

For local development with Kind:

```bash
# 1. Create a kind cluster
kind create cluster --name controller-test

# 2. Deploy the controller
./deploy.sh deploy

# 3. Verify deployment
./deploy.sh status

# 4. Test with a custom resource
kubectl apply -f - <<EOF
apiVersion: apps.newresource.com/v1alpha1
kind: NewResource
metadata:
  name: test-resource
spec:
  # Add your spec here
EOF

# 5. Clean up when done
./cleanup.sh all
```

## Local Development Setup

### Kind (Kubernetes in Docker)

Kind is recommended for local development due to its speed and isolation.

#### Prerequisites
- [Docker](https://docs.docker.com/get-docker/)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/)

#### Setup Steps

1. **Create a cluster:**
   ```bash
   kind create cluster --name controller-test
   ```

2. **Verify cluster:**
   ```bash
   kubectl cluster-info
   ```

3. **Deploy controller:**
   ```bash
   ./deploy.sh deploy
   ```

#### Alternative cluster configurations:

**With custom kubeconfig:**
```bash
kind create cluster --name controller-test --kubeconfig ./kubeconfig.yaml
export KUBECONFIG=./kubeconfig.yaml
./deploy.sh deploy
```

**With multiple nodes:**
```bash
kind create cluster --name controller-test --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
EOF
```

### Minikube

Minikube is another good option for local development.

#### Prerequisites
- [Docker](https://docs.docker.com/get-docker/) or other supported drivers
- [Minikube](https://minikube.sigs.k8s.io/docs/start/)

#### Setup Steps

1. **Start Minikube:**
   ```bash
   minikube start
   ```

2. **Deploy controller:**
   ```bash
   ./deploy.sh deploy
   ```

3. **Access Minikube dashboard (optional):**
   ```bash
   minikube dashboard
   ```

### Docker Desktop

Docker Desktop includes a Kubernetes cluster that can be used for development.

#### Setup Steps

1. **Enable Kubernetes in Docker Desktop:**
   - Open Docker Desktop
   - Go to Settings → Kubernetes
   - Enable Kubernetes
   - Apply & Restart

2. **Deploy controller:**
   ```bash
   ./deploy.sh deploy
   ```

## Containerized Environments

### GitHub Codespaces

The controller can be deployed and tested within GitHub Codespaces.

#### Prerequisites
- GitHub repository with the controller code
- Dev container configuration (optional but recommended)

#### Setup Steps

1. **Open repository in Codespaces:**
   - Navigate to your repository on GitHub
   - Click the "Code" button
   - Select "Open with Codespaces"

2. **Install dependencies (if needed):**
   ```bash
   # The dev container should handle most dependencies
   # but you may need to install additional tools
   ```

3. **Deploy to containerized cluster:**
   ```bash
   ./deploy.sh deploy
   ```

#### Dev Container Configuration

For optimal development experience, add a `.devcontainer/devcontainer.json`:

```json
{
  "name": "Kubernetes Controller Development",
  "image": "mcr.microsoft.com/devcontainers/go:1.21",
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {},
    "ghcr.io/devcontainers/features/kubectl-helm-minikube:1": {}
  },
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-kubernetes-tools.vscode-kubernetes-tools",
        "golang.go"
      ]
    }
  },
  "postCreateCommand": "go mod download",
  "remoteUser": "vscode"
}
```

## Deployment Methods

### Using Deployment Scripts

The easiest way to deploy the controller is using the provided scripts.

#### deploy.sh

**Deploy to current cluster:**
```bash
./deploy.sh deploy
```

**Show deployment status:**
```bash
./deploy.sh status
```

**Deploy to specific cluster:**
```bash
export KUBECONFIG=/path/to/kubeconfig
./deploy.sh deploy
```

#### cleanup.sh

**Complete cleanup:**
```bash
./cleanup.sh all
```

**Clean up controller only (preserve CRDs):**
```bash
./cleanup.sh controller
```

**Clean up custom resources only:**
```bash
./cleanup.sh resources
```

**Dry run (see what would be deleted):**
```bash
./cleanup.sh all --dry-run
```

### Using Makefile Targets

For more granular control, use the Makefile targets:

#### Basic Deployment

```bash
# Deploy everything
make deploy

# Deploy specific components
make install-crds        # Install CRDs only
make install-rbac        # Install RBAC only
make deploy-controller   # Deploy controller only

# Undeploy
make undeploy
make uninstall-crds
make uninstall-rbac
make undeploy-controller
```

#### Development Workflow

```bash
# Quick deployment for development
make deploy-local

# Check status
make status

# View logs
make logs

# Restart controller
make restart

# Wait for readiness
make wait-ready

# Clean up
make cleanup-local
```

### Manual Deployment

For complete control or debugging, deploy manually:

```bash
# 1. Install CRDs
kubectl apply -f config/crd/bases/

# 2. Install RBAC
kubectl apply -f config/rbac/

# 3. Deploy controller
kubectl apply -f config/deployment.yaml
kubectl apply -f config/service.yaml

# 4. Verify deployment
kubectl get pods -n controller-system
kubectl get crd | grep apps.newresource.com
```

## Testing and Validation

### Verify Deployment

```bash
# Check all resources
kubectl get all -n controller-system

# Check CRDs
kubectl get crd | grep apps.newresource.com

# Check controller logs
kubectl logs -f deployment/controller -n controller-system

# Check rollout status
kubectl rollout status deployment/controller -n controller-system
```

### Test Custom Resources

1. **Create a test resource:**
   ```bash
   kubectl apply -f - <<EOF
   apiVersion: apps.newresource.com/v1alpha1
   kind: NewResource
   metadata:
     name: test-resource
   spec:
     # Add your resource specification here
   EOF
   ```

2. **Verify resource:**
   ```bash
   kubectl get newresources
   kubectl describe newresource test-resource
   ```

3. **Check controller logs for processing:**
   ```bash
   kubectl logs -f deployment/controller -n controller-system
   ```

### Load Testing

For testing controller performance:

```bash
# Create multiple resources
for i in {1..10}; do
  cat <<EOF | kubectl apply -f -
  apiVersion: apps.newresource.com/v1alpha1
  kind: NewResource
  metadata:
    name: test-resource-$i
  spec:
    # Add your spec here
  EOF
done

# Monitor controller performance
kubectl top pods -n controller-system
```

## Troubleshooting

### Common Issues

#### 1. Cluster Connection Issues

**Problem:** Cannot connect to cluster
```bash
error: You must be logged in to the server (Unauthorized)
```

**Solutions:**
- Verify cluster is running: `kubectl cluster-info`
- Check kubeconfig: `kubectl config view`
- For Kind: `kind get clusters`
- For Minikube: `minikube status`

#### 2. Image Pull Issues

**Problem:** Image pull errors in controller pods
```bash
Failed to pull image "controller:latest"
```

**Solutions:**
- Build the image: `make docker-build`
- Use different image tag: `IMG=your-registry/controller:v1.0.0 make deploy`

#### 3. RBAC Issues

**Problem:** Permission denied errors
```bash
error: failed to create resource: roles.rbac.authorization.k8s.io is forbidden
```

**Solutions:**
- Check RBAC manifests: `kubectl get roles,rolebindings,serviceaccounts -n controller-system`
- Verify service account: `kubectl describe sa controller -n controller-system`

#### 4. CRD Issues

**Problem:** Custom resources not recognized
```bash
error: unable to recognize "": no matches for kind "NewResource"
```

**Solutions:**
- Check CRDs: `kubectl get crd | grep apps.newresource.com`
- Reinstall CRDs: `make install-crds`

#### 5. Controller Not Starting

**Problem:** Controller pods in CrashLoopBackOff
```bash
kubectl get pods -n controller-system
```

**Solutions:**
- Check logs: `kubectl logs -p deployment/controller -n controller-system`
- Verify configuration in deployment.yaml
- Check resource limits and requests

### Debug Commands

```bash
# Comprehensive status check
kubectl get all,crd,sa,roles,rolebindings -n controller-system

# Check events
kubectl get events -n controller-system --sort-by=.metadata.creationTimestamp

# Port forward for debugging
kubectl port-forward deployment/controller 8080:8080 -n controller-system

# Execute commands in controller pod
kubectl exec deployment/controller -n controller-system -- /bin/sh
```

## Cleanup

### Complete Cleanup

```bash
# Using cleanup script (recommended)
./cleanup.sh all

# Using Makefile
make undeploy

# Manual cleanup
kubectl delete -f config/service.yaml
kubectl delete -f config/deployment.yaml
kubectl delete -f config/rbac/
kubectl delete -f config/crd/bases/
```

### Partial Cleanup

```bash
# Clean up only custom resources
./cleanup.sh resources

# Clean up controller but keep CRDs
./cleanup.sh controller

# Clean up CRDs (destructive - removes all custom resources)
./cleanup.sh crds
```

### Cluster Cleanup

For Kind clusters:
```bash
# Delete specific cluster
kind delete cluster --name controller-test

# Delete all Kind clusters
kind delete clusters
```

For Minikube:
```bash
# Stop Minikube
minikube stop

# Delete Minikube cluster
minikube delete
```

## Best Practices

### Development Workflow

1. **Use separate clusters for different environments:**
   ```bash
   kind create cluster --name controller-dev
   kind create cluster --name controller-test
   ```

2. **Use namespaces for isolation:**
   ```bash
   kubectl create namespace controller-dev
   kubectl config set-context --current --namespace=controller-dev
   ```

3. **Regular cleanup:**
   ```bash
   # Clean up after each test session
   ./cleanup.sh all
   ```

4. **Monitor resource usage:**
   ```bash
   kubectl top nodes
   kubectl top pods -n controller-system
   ```

### Security Considerations

- Review RBAC permissions in `config/rbac/`
- Use least-privilege access principles
- Regularly update Kubernetes dependencies
- Scan images for vulnerabilities: `make docker-build` (with security scanning)

### Performance Optimization

- Adjust resource requests/limits in `config/deployment.yaml`
- Use horizontal pod autoscaling if needed
- Monitor controller performance metrics
- Consider using multiple replicas for production

## Getting Help

If you encounter issues:

1. Check the troubleshooting section above
2. Review controller logs: `make logs`
3. Verify cluster state: `kubectl cluster-info`
4. Check deployment status: `./deploy.sh status`

For additional support, refer to:
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kind Documentation](https://kind.sigs.k8s.io/docs/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)