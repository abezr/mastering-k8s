#!/bin/bash

# Test script to verify controller functionality

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

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check cluster connectivity
print_info "Checking cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi
print_success "Cluster connection verified"

# Check if controller is deployed
print_info "Checking controller deployment..."
if ! kubectl get deployment newresource-controller -n newresource-system &> /dev/null; then
    print_error "Controller is not deployed"
    exit 1
fi
print_success "Controller is deployed"

# Check if controller pod is running
print_info "Checking controller pod status..."
if ! kubectl get pods -n newresource-system -l app.kubernetes.io/name=newresource-controller | grep -q Running; then
    print_warning "Controller pod is not running"
    kubectl get pods -n newresource-system
    exit 1
fi
print_success "Controller pod is running"

# Check CRDs
print_info "Checking CRDs..."
if ! kubectl get crd newresources.apps.newresource.com &> /dev/null; then
    print_error "CRDs are not installed"
    exit 1
fi
print_success "CRDs are installed"

# Create a test resource
print_info "Creating test resource..."
cat <<EOF | kubectl apply -f -
apiVersion: apps.newresource.com/v1alpha1
kind: NewResource
metadata:
  name: functionality-test
  namespace: newresource-system
spec:
  foo: test-value
EOF

# Wait for reconciliation
print_info "Waiting for controller to reconcile the resource..."
sleep 5

# Check if status is set
print_info "Checking if controller set the status..."
STATUS=$(kubectl get newresources functionality-test -n newresource-system -o jsonpath='{.status.ready}' 2>/dev/null || echo "not-found")

if [ "$STATUS" = "true" ]; then
    print_success "Controller is functioning correctly - status is set to ready"
else
    print_error "Controller is not functioning correctly - status is not set properly"
    print_info "Resource details:"
    kubectl get newresources functionality-test -n newresource-system -o yaml
    # Clean up test resource
    kubectl delete newresources functionality-test -n newresource-system --ignore-not-found=true
    exit 1
fi

# Clean up test resource
kubectl delete newresources functionality-test -n newresource-system --ignore-not-found=true

print_success "Controller functionality test completed successfully!"
print_info "The controller is working correctly and automatically sets the status of NewResource objects to ready: true"