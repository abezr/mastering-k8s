# Deploying the Controller in GitHub Codespaces

This guide shows two straightforward ways to run and test the controller inside a GitHub Codespace:
- Option A: Run a local Kubernetes cluster in the Codespace using Kind and deploy the controller image built inside the Codespace.
- Option B: Use the Docker Publish workflow to push an image to GHCR, then deploy that image into the Kind cluster.

The controller stack used here aligns with:
- API group: apps.newresource.com
- Namespace: newresource-system
- Deployment: newresource-controller
- Metrics: :8080, Health: :8081

If you have not yet read the architecture and testing docs, review:
- docs/ARCHITECTURE.md
- docs/TESTING.md
- docs/METRICS.md

## Prerequisites

- A repository on GitHub (this one) with Codespaces enabled
- Sufficient Codespaces machine size for running Docker and a Kind cluster (Basic 4-core or above recommended)

## Open the project in Codespaces

1. Navigate to your GitHub repository.
2. Click the Code button → Open with Codespaces → New with options if you want to choose a larger instance size.

After the Codespace boots:
```bash
# Confirm Go and Docker are available
go version
docker version
```

If `docker version` fails, ensure you are using a devcontainer configuration that enables Docker-in-Docker.

## Dev Container configuration (recommended)

Add a .devcontainer/devcontainer.json to provision everything you need automatically. If the folder does not exist, create it with the content below:

```json
{
  "name": "Kubernetes Controller Development",
  "image": "mcr.microsoft.com/devcontainers/go:1.21",
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {},
    "ghcr.io/devcontainers/features/kubectl-helm-minikube:1": {},
    "ghcr.io/devcontainers/features/kind:1": {}
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

Rebuild the container for the changes to take effect:
- Command Palette → Dev Containers: Rebuild Container

This will provide:
- Docker-in-Docker
- kubectl, helm, minikube (not required here but useful)
- kind

## Option A: Run with Kind entirely in Codespaces

This option keeps everything self-contained inside the Codespace. You will:
- Build the controller image locally
- Load it into the Kind cluster
- Deploy CRDs, RBAC, and the controller resources
- Apply a sample CR and assert status

### 1) Create a Kind cluster

```bash
kind create cluster --name controller-codespace
kubectl cluster-info
```

If you need a custom KUBECONFIG:
```bash
kind create cluster --name controller-codespace --kubeconfig ./kubeconfig.yaml
export KUBECONFIG=./kubeconfig.yaml
```

### 2) Build the controller Docker image

This repository contains a Dockerfile at the root that builds a statically linked /manager binary.

```bash
docker build -t newresource-controller:latest .
```

### 3) Load the image into Kind

```bash
kind load docker-image newresource-controller:latest --name controller-codespace
```

### 4) Deploy CRDs, RBAC, controller and service

Ensure you are in the repository root:
```bash
# Install CRDs
kubectl apply -f config/crd/bases/

# Install RBAC (ServiceAccount, Role, RoleBinding)
kubectl apply -f config/rbac/

# Create namespace if not created by RBAC manifests
kubectl create namespace newresource-system || true

# Deploy controller and metrics service
kubectl apply -f config/deployment.yaml
kubectl apply -f config/service.yaml

# Wait for rollout
kubectl rollout status deployment/newresource-controller -n newresource-system --timeout=300s
```

### 5) Apply a sample NewResource

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps.newresource.com/v1alpha1
kind: NewResource
metadata:
  name: example-codespace
  namespace: default
spec:
  foo: "hello from codespaces"
EOF
```

### 6) Verify status and logs

```bash
# Check the resource
kubectl get newresource example-codespace -n default -o yaml

# Verify status.ready = true
kubectl get newresource example-codespace -n default -o jsonpath='{.status.ready}'; echo

# Controller logs
kubectl logs -f deployment/newresource-controller -n newresource-system
```

### 7) Access metrics and health endpoints (optional)

In a Codespace, use port forwarding to access metrics and health endpoints:

```bash
# Forward metrics (8080) and health (8081)
kubectl port-forward deployment/newresource-controller 8080:8080 -n newresource-system &
kubectl port-forward deployment/newresource-controller 8081:8081 -n newresource-system &

# Test endpoints
curl -sf http://localhost:8081/healthz
curl -sf http://localhost:8081/readyz
curl -sf http://localhost:8080/metrics | head
```

### 8) Cleanup

```bash
# Remove controller components
kubectl delete -f config/service.yaml
kubectl delete -f config/deployment.yaml
kubectl delete -f config/rbac/
kubectl delete -f config/crd/bases/
# Delete Kind cluster when done
kind delete cluster --name controller-codespace
```

## Option B: Use GHCR image built by CI, then deploy

This option is useful when you want to avoid building images inside the Codespace or when collaborating with others using a shared image tag.

1) Push an image to GHCR using the Docker Publish workflow:
- Push to main or create a tag vX.Y.Z to trigger [.github/workflows/docker-publish.yml](.github/workflows/docker-publish.yml)
- The image will be published to: `ghcr.io/OWNER/new-controller:TAG` (replace OWNER with your GitHub org or username)

2) Create a Kind cluster as above:
```bash
kind create cluster --name controller-codespace
```

3) Update the image in your deployment to point to GHCR:
- Edit config/deployment.yaml to use `image: ghcr.io/OWNER/new-controller:TAG`
- Then apply it:
  ```bash
  kubectl apply -f config/crd/bases/
  kubectl apply -f config/rbac/
  kubectl apply -f config/deployment.yaml
  kubectl apply -f config/service.yaml
  kubectl rollout status deployment/newresource-controller -n newresource-system --timeout=300s
  ```

4) Apply and verify a sample CR as shown in Option A.

## Troubleshooting

- docker not found in Codespaces
  - Ensure .devcontainer/devcontainer.json includes the Docker-in-Docker feature
  - Rebuild the container from the Command Palette
- kind create cluster fails
  - Verify Docker is running: `docker info`
  - Codespaces sometimes restricts resources; try a smaller Kind cluster or restart the Codespace
- Controller stuck in CrashLoopBackOff
  - Describe the deployment and get logs:
    ```bash
    kubectl describe deployment/newresource-controller -n newresource-system
    kubectl logs -f deployment/newresource-controller -n newresource-system
    ```
  - Ensure CRDs and RBAC are applied before deploying
- CRD not recognized
  - Re-apply CRDs: `kubectl apply -f config/crd/bases/`
  - Confirm the group matches the controller code: apps.newresource.com
- Cannot reach metrics or health endpoints
  - Use `kubectl port-forward` as shown above

## Makefile shortcuts

You can use Makefile targets if you prefer scripted operations. Ensure the deployment/namespace names match your manifests:
```bash
# Deploy everything via script wrapper
make deploy-local
make status
make logs
make restart
# Clean up
make cleanup-local
```

## Summary

- In Codespaces, the simplest path is to run Kind inside the Codespace, build the controller image locally, load it into Kind, and deploy CRDs/RBAC/manifests.
- Alternatively, use CI to publish images to GHCR and deploy that image to your cluster in Codespaces.
- For full details on architecture, metrics, and tests, see the docs folder.
