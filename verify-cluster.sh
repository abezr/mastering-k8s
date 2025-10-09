#!/bin/bash

# Script to verify the Kind cluster setup

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

print_info "Verifying Kind cluster setup..."

# Check if Kind is installed
if ! command -v kind &> /dev/null; then
    print_error "Kind is not installed"
    exit 1
fi

print_success "Kind is installed"

# Check if there are any Kind clusters
if kind get clusters &> /dev/null; then
    print_info "Existing Kind clusters:"
    kind get clusters
else
    print_warning "No Kind clusters found"
    exit 1
fi

# Check if the expected cluster exists
if kind get clusters | grep -q "codespaces-test-cluster"; then
    print_success "Found 'codespaces-test-cluster'"
else
    print_warning "Expected cluster 'codespaces-test-cluster' not found"
fi

# Check kubectl context
print_info "Current kubectl context:"
kubectl config current-context

# Check cluster info
print_info "Cluster info:"
kubectl cluster-info

# Check nodes
print_info "Cluster nodes:"
kubectl get nodes

print_success "Cluster verification completed"