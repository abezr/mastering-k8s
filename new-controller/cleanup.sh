#!/bin/bash

# Cleanup script for Kubernetes controller
# Provides comprehensive cleanup of all controller resources for testing

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
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
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

# Function to cleanup everything
cleanup_all() {
    print_info "Performing complete cleanup of all controller resources..."

    # Delete custom resources first (they depend on CRDs)
    print_info "Deleting custom resources..."
    kubectl delete newresources --all --ignore-not-found=true
    kubectl delete newresources --all-namespaces --ignore-not-found=true

    # Delete controller resources
    print_info "Deleting controller deployment and service..."
    kubectl delete -f config/service.yaml --ignore-not-found=true
    kubectl delete -f config/deployment.yaml --ignore-not-found=true

    # Delete RBAC resources
    print_info "Deleting RBAC resources..."
    kubectl delete -f config/rbac/ --ignore-not-found=true

    # Delete CRDs last
    print_info "Deleting Custom Resource Definitions..."
    kubectl delete -f config/crd/bases/ --ignore-not-found=true

    print_success "Complete cleanup finished"
}

# Function to cleanup only controller (keep CRDs)
cleanup_controller() {
    print_info "Cleaning up controller (preserving CRDs)..."

    # Delete custom resources
    kubectl delete newresources --all --ignore-not-found=true
    kubectl delete newresources --all-namespaces --ignore-not-found=true

    # Delete controller resources
    kubectl delete -f config/service.yaml --ignore-not-found=true
    kubectl delete -f config/deployment.yaml --ignore-not-found=true

    # Delete RBAC resources
    kubectl delete -f config/rbac/ --ignore-not-found=true

    print_success "Controller cleanup finished (CRDs preserved)"
}

# Function to cleanup only custom resources
cleanup_resources() {
    print_info "Cleaning up custom resources only..."

    kubectl delete newresources --all --ignore-not-found=true
    kubectl delete newresources --all-namespaces --ignore-not-found=true

    print_success "Custom resources cleanup finished"
}

# Function to cleanup CRDs only
cleanup_crds() {
    print_warning "This will delete all custom resources and CRDs!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cleaning up CRDs and custom resources..."

        # Delete custom resources first
        kubectl delete newresources --all --ignore-not-found=true
        kubectl delete newresources --all-namespaces --ignore-not-found=true

        # Delete CRDs
        kubectl delete -f config/crd/bases/ --ignore-not-found=true

        print_success "CRDs cleanup finished"
    else
        print_info "CRDs cleanup cancelled"
    fi
}

# Function to show current resources before cleanup
show_resources() {
    print_info "Current controller resources in cluster:"

    echo ""
    echo "Custom Resource Definitions:"
    kubectl get crd | grep example.com || echo "  No controller CRDs found"

    echo ""
    echo "Controller Resources (controller-system namespace):"
    kubectl get all,sa,role,rolebinding -n controller-system 2>/dev/null || echo "  No controller resources found"

    echo ""
    echo "Custom Resources:"
    kubectl get newresources 2>/dev/null || echo "  No custom resources found"
    kubectl get newresources --all-namespaces 2>/dev/null || echo "  No custom resources in any namespace"
}

# Function to wait for resources to be deleted
wait_for_cleanup() {
    local resource_type=$1
    local timeout=60
    local count=0

    print_info "Waiting for $resource_type to be deleted..."

    while [ $count -lt $timeout ]; do
        if ! kubectl get $resource_type &> /dev/null; then
            print_success "$resource_type deleted successfully"
            return 0
        fi

        count=$((count + 5))
        sleep 5
    done

    print_warning "Timeout waiting for $resource_type deletion"
}

# Help function
show_help() {
    cat << EOF
Kubernetes Controller Cleanup Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  all              Clean up everything (CRDs, controller, resources)
  controller       Clean up controller only (preserve CRDs)
  resources        Clean up custom resources only
  crds             Clean up CRDs and custom resources (destructive)
  status           Show current controller resources
  help             Show this help message

Options:
  --dry-run       Show what would be deleted without actually deleting
  --force         Skip confirmation prompts
  --timeout=SEC   Timeout for waiting operations (default: 60)

Environment Variables:
  KUBECONFIG      Path to kubeconfig file (default: ~/.kube/config)
  FORCE           Skip confirmation prompts if set to 'true'

Examples:
  $0 all                           # Complete cleanup
  $0 controller                    # Clean up controller only
  $0 resources                     # Clean up custom resources only
  $0 crds                          # Clean up CRDs (destructive)
  $0 status                        # Show current resources

  # Dry run to see what would be deleted
  $0 all --dry-run

  # Force cleanup without confirmation
  $0 all --force

EOF
}

# Main script logic
main() {
    check_kubectl
    check_cluster

    local command="${1:-all}"
    local dry_run=false
    local force=false
    local timeout=60

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --timeout=*)
                timeout="${1#*=}"
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                command="$1"
                shift
                ;;
        esac
    done

    # Set force from environment if not set via flag
    if [[ "$FORCE" == "true" && "$force" == "false" ]]; then
        force=true
    fi

    print_info "Cleanup script for $(detect_cluster_type) cluster"

    case "$command" in
        "all")
            if [[ "$dry_run" == "true" ]]; then
                print_info "DRY RUN: Would perform complete cleanup"
                show_resources
            else
                cleanup_all
            fi
            ;;
        "controller")
            if [[ "$dry_run" == "true" ]]; then
                print_info "DRY RUN: Would clean up controller only"
                show_resources
            else
                cleanup_controller
            fi
            ;;
        "resources")
            if [[ "$dry_run" == "true" ]]; then
                print_info "DRY RUN: Would clean up custom resources only"
                show_resources
            else
                cleanup_resources
            fi
            ;;
        "crds")
            if [[ "$dry_run" == "true" ]]; then
                print_info "DRY RUN: Would clean up CRDs and custom resources"
                show_resources
            else
                cleanup_crds
            fi
            ;;
        "status")
            show_resources
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"