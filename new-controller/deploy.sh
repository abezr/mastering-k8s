#!/bin/bash

# Deployment script for Kubernetes controller
# Supports deployment to local clusters (kind, minikube) and containerized environments

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

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
}

# Function to check cluster connectivity
check_cluster() {
    print_info "Checking cluster connectivity..."
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        print_info "Please ensure you have a running cluster (kind, minikube, etc.)"
        exit 1
    fi
    print_success "Cluster connection verified"
}

# Function to detect cluster type
detect_cluster_type() {
    if kubectl config current-context | grep -q kind; then
        echo "kind"
    elif kubectl config current-context | grep -q minikube; then
        echo "minikube"
    elif kubectl config current-context | grep -q docker; then
        echo "docker-desktop"
    else
        echo "unknown"
    fi
}

# Function to install CRDs
install_crds() {
    print_info "Installing Custom Resource Definitions..."
    kubectl apply -f config/crd/bases/
    print_success "CRDs installed successfully"
}

# Function to uninstall CRDs
uninstall_crds() {
    print_info "Uninstalling Custom Resource Definitions..."
    kubectl delete -f config/crd/bases/ --ignore-not-found=true
    print_success "CRDs uninstalled successfully"
}

# Function to install RBAC resources
install_rbac() {
    print_info "Installing RBAC resources..."
    kubectl apply -f config/rbac/
    print_success "RBAC resources installed successfully"
}

# Function to uninstall RBAC resources
uninstall_rbac() {
    print_info "Uninstalling RBAC resources..."
    kubectl delete -f config/rbac/ --ignore-not-found=true
    print_success "RBAC resources uninstalled successfully"
}

# Function to deploy controller
deploy_controller() {
    print_info "Deploying controller..."
    kubectl apply -f config/deployment.yaml
    kubectl apply -f config/service.yaml
    print_success "Controller deployed successfully"
}

# Function to undeploy controller
undeploy_controller() {
    print_info "Undeploying controller..."
    kubectl delete -f config/service.yaml --ignore-not-found=true
    kubectl delete -f config/deployment.yaml --ignore-not-found=true
    print_success "Controller undeployed successfully"
}

# Function to wait for deployment readiness
wait_for_deployment() {
    local timeout=300
    local count=0

    print_info "Waiting for controller deployment to be ready..."

    while [ $count -lt $timeout ]; do
        if kubectl rollout status deployment/newresource-controller -n newresource-system --timeout=10s &> /dev/null; then
            print_success "Controller deployment is ready"
            return 0
        fi

        count=$((count + 10))
        print_info "Still waiting... (${count}s/${timeout}s)"
        sleep 10
    done

    print_warning "Timeout waiting for deployment readiness"
    return 1
}

# Function to show deployment status
show_status() {
    print_info "Deployment status:"
    echo ""

    # Show CRDs
    echo "Custom Resource Definitions:"
    kubectl get crd | grep example.com || echo "  No CRDs found"

    echo ""
    echo "Controller Resources:"
    kubectl get all -n newresource-system 2>/dev/null || echo "  No controller resources found"

    echo ""
    echo "Custom Resources:"
    kubectl get newresources 2>/dev/null || echo "  No custom resources found"
}

# Main deployment function
deploy() {
    print_info "Starting deployment to $(detect_cluster_type) cluster..."

    check_kubectl
    check_cluster

    install_crds
    install_rbac
    deploy_controller

    wait_for_deployment

    show_status
    print_success "Deployment completed successfully!"
    print_info "You can now create custom resources using: kubectl apply -f <your-resource>.yaml"
}

# Main cleanup function
cleanup() {
    print_info "Starting cleanup..."

    check_kubectl
    check_cluster

    # Delete custom resources first
    print_info "Deleting custom resources..."
    kubectl delete newresources --all --ignore-not-found=true

    undeploy_controller
    uninstall_rbac
    uninstall_crds

    print_success "Cleanup completed successfully!"
}

# Help function
show_help() {
    cat << EOF
Kubernetes Controller Deployment Script

Usage: $0 [COMMAND]

Commands:
  deploy    Deploy the controller to the current cluster
  cleanup   Remove all controller resources from the current cluster
  status    Show current deployment status
  help      Show this help message

Environment Variables:
  KUBECONFIG    Path to kubeconfig file (default: ~/.kube/config)

Examples:
  $0 deploy                    # Deploy to current cluster
  $0 cleanup                   # Clean up all resources
  $0 status                    # Show deployment status

  # Deploy to specific cluster
  export KUBECONFIG=/path/to/kubeconfig
  $0 deploy

EOF
}

# Main script logic
case "${1:-deploy}" in
    "deploy")
        deploy
        ;;
    "cleanup")
        cleanup
        ;;
    "status")
        check_kubectl
        check_cluster
        show_status
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac