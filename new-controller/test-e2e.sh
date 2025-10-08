#!/bin/bash

# End-to-end test script for the NewResource controller

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

# Check prerequisites
print_info "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed"
    exit 1
fi

if ! command -v kind &> /dev/null; then
    print_error "kind is not installed"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    print_error "docker is not installed"
    exit 1
fi

print_success "All prerequisites found"

# Check if we have a cluster
print_info "Checking for existing Kind cluster..."

if ! kind get clusters | grep -q "e2e-test"; then
    print_info "Creating Kind cluster for testing..."
    kind create cluster --name e2e-test
else
    print_info "Using existing Kind cluster"
fi

# Make sure we're using the right context
kubectl cluster-info --context kind-e2e-test >/dev/null

print_info "Building and loading controller image..."
./build-and-load.sh

print_info "Deploying controller..."
./deploy.sh deploy

print_info "Waiting for controller to be ready..."
sleep 10

# Check if the controller is running
if kubectl get pods -n newresource-system | grep -q "newresource-controller.*Running"; then
    print_success "Controller is running"
else
    print_error "Controller is not running"
    kubectl get pods -n newresource-system
    exit 1
fi

print_info "Creating test resource..."
kubectl apply -f ../test-resource.yaml

print_info "Waiting for resource to be processed..."
sleep 5

# Check if the resource is ready
if kubectl get newresources -n newresource-system test-resource -o jsonpath='{.status.ready}' | grep -q "true"; then
    print_success "Test resource is ready"
else
    print_warning "Test resource is not ready yet, checking again in 10 seconds..."
    sleep 10
    if kubectl get newresources -n newresource-system test-resource -o jsonpath='{.status.ready}' | grep -q "true"; then
        print_success "Test resource is ready"
    else
        print_error "Test resource is not ready"
        kubectl get newresources -n newresource-system test-resource -o yaml
        exit 1
    fi
fi

print_info "Checking controller logs..."
kubectl logs -n newresource-system deployment/newresource-controller -c manager | tail -10

print_success "End-to-end test completed successfully!"

print_info "Cleaning up..."
./deploy.sh cleanup
kind delete cluster --name e2e-test

print_success "Cleanup completed"