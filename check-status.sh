#!/bin/bash

# Script to check the status of Kubernetes components

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

# Function to check if a process is running
is_running() {
    pgrep -f "$1" >/dev/null
}

print_info "Checking Kubernetes component status..."

# Check each component
echo "Component Status:"
echo "================="

if is_running "etcd"; then
    print_success "etcd: Running"
else
    print_error "etcd: Not running"
fi

if is_running "kube-apiserver"; then
    print_success "kube-apiserver: Running"
else
    print_error "kube-apiserver: Not running"
fi

if is_running "kube-controller-manager"; then
    print_success "kube-controller-manager: Running"
else
    print_error "kube-controller-manager: Not running"
fi

if is_running "kube-scheduler"; then
    print_success "kube-scheduler: Running"
else
    print_error "kube-scheduler: Not running"
fi

if is_running "kubelet"; then
    print_success "kubelet: Running"
else
    print_error "kubelet: Not running"
fi

if is_running "containerd"; then
    print_success "containerd: Running"
else
    print_error "containerd: Not running"
fi

# Check API server connectivity
print_info "Checking API server connectivity..."
if [ -f "./kubebuilder/bin/kubectl" ]; then
    if ./kubebuilder/bin/kubectl cluster-info &>/dev/null; then
        print_success "API server: Reachable"
        echo ""
        print_info "Cluster info:"
        ./kubebuilder/bin/kubectl cluster-info
    else
        print_error "API server: Unreachable"
    fi
else
    print_warning "kubectl: Not found"
fi