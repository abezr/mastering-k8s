#!/bin/bash

# Script to build the controller image and load it into a Kind cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Kind is available
if ! command -v kind &> /dev/null; then
    print_error "Kind is not installed or not in PATH"
    print_info "Please install Kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
    exit 1
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH"
    print_info "Please install Docker"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "Dockerfile" ]; then
    print_error "Dockerfile not found. Please run this script from the controller directory."
    exit 1
fi

# Get the list of Kind clusters
KIND_CLUSTERS=$(kind get clusters 2>/dev/null || true)

if [ -z "$KIND_CLUSTERS" ]; then
    print_warning "No Kind clusters found. Creating a new one..."
    kind create cluster --name mastering-k8s
    KIND_CLUSTERS="mastering-k8s"
fi

# Use the first cluster found
CLUSTER_NAME=$(echo $KIND_CLUSTERS | awk '{print $1}')
print_info "Using Kind cluster: $CLUSTER_NAME"

# Regenerate CRDs to ensure they match the current API
print_info "Regenerating CRDs from current API definitions..."
if command -v controller-gen &> /dev/null; then
    controller-gen crd paths="./..." output:crd:artifacts:config=config/crd/bases
    print_success "CRDs regenerated successfully"
else
    print_warning "controller-gen not found, using existing CRD manifests"
fi

# Build the Docker image
print_info "Building Docker image..."
docker build -t newresource-controller:latest .

# Load the image into the Kind cluster
print_info "Loading image into Kind cluster..."
kind load docker-image newresource-controller:latest --name $CLUSTER_NAME

print_success "Image built and loaded successfully!"
print_info "You can now deploy the controller using: ./deploy.sh deploy"