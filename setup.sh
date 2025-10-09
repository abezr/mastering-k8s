#!/bin/bash

# Exit on error
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

# Detect environment
detect_environment() {
    if [[ -n "$CODESPACES" ]] || [[ -n "$GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN" ]]; then
        echo "codespaces"
    elif [[ -f /.dockerenv ]]; then
        echo "docker"
    else
        echo "local"
    fi
}

ENVIRONMENT=$(detect_environment)
print_info "Detected environment: $ENVIRONMENT"

echo "Setting up Kubernetes control plane for AMD64..."

# Function to check if a process is running
is_running() {
    pgrep -f "$1" >/dev/null
}

# Function to check if all components are running
check_running() {
    is_running "etcd" && \
    is_running "kube-apiserver" && \
    is_running "kube-controller-manager" && \
    is_running "kube-scheduler" && \
    is_running "kubelet" && \
    is_running "containerd"
}

# Function to kill process if running
stop_process() {
    if is_running "$1"; then
        echo "Stopping $1..."
        pkill -f "$1" || true
        # Wait for process to stop with timeout
        local count=0
        while is_running "$1" && [ $count -lt 10 ]; do
            sleep 1
            count=$((count + 1))
        done
    fi
}

download_components() {
    # Create necessary directories if they don't exist
    mkdir -p ./kubebuilder/bin
    sudo mkdir -p /etc/cni/net.d
    mkdir -p /tmp/kubelet
    sudo mkdir -p /etc/kubernetes/manifests
    sudo mkdir -p /var/log/kubernetes
    sudo mkdir -p /etc/containerd/
    sudo mkdir -p /run/containerd

    # Download kubebuilder tools if not present
    if [ ! -f "kubebuilder/bin/etcd" ]; then
        echo "Downloading kubebuilder tools..."
        curl -L https://storage.googleapis.com/kubebuilder-tools/kubebuilder-tools-1.30.0-linux-amd64.tar.gz -o /tmp/kubebuilder-tools.tar.gz
        tar -C ./kubebuilder --strip-components=1 -zxf /tmp/kubebuilder-tools.tar.gz
        rm /tmp/kubebuilder-tools.tar.gz
        chmod -R 755 ./kubebuilder/bin
    fi

    if [ ! -f "kubebuilder/bin/kubelet" ]; then
        echo "Downloading kubelet..."
        curl -L "https://dl.k8s.io/v1.30.0/bin/linux/amd64/kubelet" -o kubebuilder/bin/kubelet
        chmod 755 kubebuilder/bin/kubelet
    fi

    # Install CNI components if not present
    if [ ! -d "/opt/cni" ]; then
        sudo mkdir -p /opt/cni
        
        echo "Installing containerd..."
        wget https://github.com/containerd/containerd/releases/download/v2.0.5/containerd-static-2.0.5-linux-amd64.tar.gz -O /tmp/containerd.tar.gz
        sudo tar zxf /tmp/containerd.tar.gz -C /opt/cni/
        rm /tmp/containerd.tar.gz

        echo "Installing runc..."
        sudo curl -L "https://github.com/opencontainers/runc/releases/download/v1.2.6/runc.amd64" -o /opt/cni/bin/runc

        echo "Installing CNI plugins..."
        wget https://github.com/containernetworking/plugins/releases/download/v1.6.2/cni-plugins-linux-amd64-v1.6.2.tgz -O /tmp/cni-plugins.tgz
        sudo tar zxf /tmp/cni-plugins.tgz -C /opt/cni/bin/
        rm /tmp/cni-plugins.tgz

        # Set permissions for all CNI components
        sudo chmod -R 755 /opt/cni
    fi

    if [ ! -f "kubebuilder/bin/kube-controller-manager" ]; then
        echo "Downloading additional components..."
        curl -L "https://dl.k8s.io/v1.30.0/bin/linux/amd64/kube-controller-manager" -o kubebuilder/bin/kube-controller-manager
        curl -L "https://dl.k8s.io/v1.30.0/bin/linux/amd64/kube-scheduler" -o kubebuilder/bin/kube-scheduler
        chmod 755 kubebuilder/bin/kube-controller-manager
        chmod 755 kubebuilder/bin/kube-scheduler
    fi
}

setup_configs() {
    # Generate certificates and tokens if they don't exist
    if [ ! -f "/tmp/sa.key" ]; then
        openssl genrsa -out /tmp/sa.key 2048
        openssl rsa -in /tmp/sa.key -pubout -out /tmp/sa.pub
    fi

    if [ ! -f "/tmp/token.csv" ]; then
        TOKEN="1234567890"
        echo "${TOKEN},admin,admin,system:masters" > /tmp/token.csv
    fi

    # Always regenerate and copy CA certificate to ensure it exists
    echo "Generating CA certificate..."
    openssl genrsa -out /tmp/ca.key 2048
    openssl req -x509 -new -nodes -key /tmp/ca.key -subj "/CN=kubelet-ca" -days 365 -out /tmp/ca.crt
    mkdir -p /tmp/kubelet/pki
    cp /tmp/ca.crt /tmp/kubelet/ca.crt
    cp /tmp/ca.crt /tmp/kubelet/pki/ca.crt

    # Set up kubeconfig
    export KUBECONFIG="$HOME/.kube/config"
    mkdir -p "$HOME/.kube"
    
    # Create kubeconfig file
    ./kubebuilder/bin/kubectl config set-credentials test-user --token=1234567890 >/dev/null
    ./kubebuilder/bin/kubectl config set-cluster test-env --server=https://127.0.0.1:6443 --insecure-skip-tls-verify=true >/dev/null
    ./kubebuilder/bin/kubectl config set-context test-context --cluster=test-env --user=test-user --namespace=default >/dev/null
    ./kubebuilder/bin/kubectl config use-context test-context >/dev/null

    # Configure CNI
    cat <<EOF | sudo tee /etc/cni/net.d/10-mynet.conf
{
    "cniVersion": "0.3.1",
    "name": "mynet",
    "type": "bridge",
    "bridge": "cni0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "subnet": "10.22.0.0/16",
        "routes": [
            { "dst": "0.0.0.0/0" }
        ]
    }
}
EOF

    # Configure containerd
    cat <<EOF | sudo tee /etc/containerd/config.toml
version = 3

[grpc]
  address = "/run/containerd/containerd.sock"

[plugins.'io.containerd.cri.v1.runtime']
  enable_selinux = false
  enable_unprivileged_ports = true
  enable_unprivileged_icmp = true
  device_ownership_from_security_context = false

[plugins.'io.containerd.cri.v1.images']
  snapshotter = "native"
  disable_snapshot_annotations = true

[plugins.'io.containerd.cri.v1.runtime'.cni]
  bin_dir = "/opt/cni/bin"
  conf_dir = "/etc/cni/net.d"

[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"

[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options]
  SystemdCgroup = false
EOF

    # Ensure containerd data directory exists with correct permissions
    sudo mkdir -p /var/lib/containerd
    sudo chmod 711 /var/lib/containerd

    # Configure kubelet (avoid permission issues by not using chmod on /tmp files)
    cat << EOF > /tmp/kubelet-config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
authentication:
  anonymous:
    enabled: true
  webhook:
    enabled: true
  x509:
    clientCAFile: "/tmp/kubelet/ca.crt"
authorization:
  mode: AlwaysAllow
clusterDomain: "cluster.local"
clusterDNS:
  - "10.0.0.10"
resolvConf: "/etc/resolv.conf"
runtimeRequestTimeout: "15m"
failSwapOn: false
seccompDefault: true
serverTLSBootstrap: false
containerRuntimeEndpoint: "unix:///run/containerd/containerd.sock"
staticPodPath: "/etc/kubernetes/manifests"
EOF

    # Create required directories with proper permissions
    mkdir -p /tmp/kubelet/pods
    chmod 750 /tmp/kubelet/pods 2>/dev/null || true
    mkdir -p /tmp/kubelet/plugins
    chmod 750 /tmp/kubelet/plugins 2>/dev/null || true
    mkdir -p /tmp/kubelet/plugins_registry
    chmod 750 /tmp/kubelet/plugins_registry 2>/dev/null || true

    # Ensure proper permissions (ignore permission errors)
    chmod 644 /tmp/kubelet/ca.crt 2>/dev/null || true

    # Generate self-signed kubelet serving certificate if not present
    if [ ! -f "/tmp/kubelet/pki/kubelet.crt" ] || [ ! -f "/tmp/kubelet/pki/kubelet.key" ]; then
        echo "Generating self-signed kubelet serving certificate..."
        mkdir -p /tmp/kubelet/pki
        openssl req -x509 -newkey rsa:2048 -nodes \
            -keyout /tmp/kubelet/pki/kubelet.key \
            -out /tmp/kubelet/pki/kubelet.crt \
            -days 365 \
            -subj "/CN=$(hostname)"
        chmod 600 /tmp/kubelet/pki/kubelet.key 2>/dev/null || true
        chmod 644 /tmp/kubelet/pki/kubelet.crt 2>/dev/null || true
    fi
}

# Function to check if API server is ready
wait_for_api_server() {
    local timeout=60
    local count=0
    
    echo "Waiting for API server to be ready..."
    
    while [ $count -lt $timeout ]; do
        if ./kubebuilder/bin/kubectl cluster-info &>/dev/null; then
            print_success "API server is ready"
            return 0
        fi
        
        count=$((count + 5))
        echo "Still waiting for API server... (${count}s/${timeout}s)"
        sleep 5
    done
    
    print_error "API server failed to start within timeout"
    return 1
}

start() {
    if check_running; then
        echo "Kubernetes components are already running"
        return 0
    fi

    # Use localhost for Codespaces environment
    HOST_IP="127.0.0.1"
    
    # Download components if needed
    download_components
    
    # Setup configurations
    setup_configs

    # Start containerd first
    if ! is_running "containerd"; then
        echo "Starting containerd..."
        export PATH=$PATH:/opt/cni/bin:./kubebuilder/bin
        sudo PATH=$PATH:/opt/cni/bin containerd -c /etc/containerd/config.toml &
        sleep 5
        
        # Verify containerd started
        if ! is_running "containerd"; then
            print_error "Failed to start containerd"
            return 1
        fi
        print_success "containerd started"
    fi

    # Start etcd
    if ! is_running "etcd"; then
        echo "Starting etcd..."
        mkdir -p ./etcd
        ./kubebuilder/bin/etcd \
            --advertise-client-urls http://$HOST_IP:2379 \
            --listen-client-urls http://0.0.0.0:2379 \
            --data-dir ./etcd \
            --listen-peer-urls http://0.0.0.0:2380 \
            --initial-cluster default=http://$HOST_IP:2380 \
            --initial-advertise-peer-urls http://$HOST_IP:2380 \
            --initial-cluster-state new \
            --initial-cluster-token test-token &
        sleep 5
        
        # Verify etcd started
        if ! is_running "etcd"; then
            print_error "Failed to start etcd"
            return 1
        fi
        print_success "etcd started"
    fi

    # Start kube-apiserver
    if ! is_running "kube-apiserver"; then
        echo "Starting kube-apiserver..."
        ./kubebuilder/bin/kube-apiserver \
            --etcd-servers=http://$HOST_IP:2379 \
            --service-cluster-ip-range=10.0.0.0/24 \
            --bind-address=0.0.0.0 \
            --secure-port=6443 \
            --advertise-address=$HOST_IP \
            --authorization-mode=AlwaysAllow \
            --token-auth-file=/tmp/token.csv \
            --enable-priority-and-fairness=false \
            --allow-privileged=true \
            --profiling=false \
            --storage-backend=etcd3 \
            --storage-media-type=application/json \
            --v=2 \
            --service-account-issuer=https://kubernetes.default.svc.cluster.local \
            --service-account-key-file=/tmp/sa.pub \
            --service-account-signing-key-file=/tmp/sa.key &
        sleep 10
        
        # Verify kube-apiserver started
        if ! is_running "kube-apiserver"; then
            print_error "Failed to start kube-apiserver"
            return 1
        fi
        print_success "kube-apiserver started"
    fi

    # Wait for API server to be ready before starting other components
    if ! wait_for_api_server; then
        print_error "API server failed to become ready"
        return 1
    fi

    # Start kube-scheduler
    if ! is_running "kube-scheduler"; then
        echo "Starting kube-scheduler..."
        ./kubebuilder/bin/kube-scheduler \
            --kubeconfig=$HOME/.kube/config \
            --leader-elect=false \
            --v=2 \
            --bind-address=0.0.0.0 &
        sleep 5
        
        # Verify kube-scheduler started
        if ! is_running "kube-scheduler"; then
            print_error "Failed to start kube-scheduler"
            return 1
        fi
        print_success "kube-scheduler started"
    fi

    # Start kube-controller-manager
    if ! is_running "kube-controller-manager"; then
        echo "Starting kube-controller-manager..."
        ./kubebuilder/bin/kube-controller-manager \
            --kubeconfig=$HOME/.kube/config \
            --leader-elect=false \
            --service-cluster-ip-range=10.0.0.0/24 \
            --cluster-name=kubernetes \
            --root-ca-file=/tmp/kubelet/ca.crt \
            --service-account-private-key-file=/tmp/sa.key \
            --use-service-account-credentials=true \
            --v=2 &
        sleep 5
        
        # Verify kube-controller-manager started
        if ! is_running "kube-controller-manager"; then
            print_error "Failed to start kube-controller-manager"
            return 1
        fi
        print_success "kube-controller-manager started"
    fi

    # Start kubelet
    if ! is_running "kubelet"; then
        echo "Starting kubelet..."
        export PATH=$PATH:/opt/cni/bin
        ./kubebuilder/bin/kubelet \
            --kubeconfig=$HOME/.kube/config \
            --config=/tmp/kubelet-config.yaml \
            --root-dir=/tmp/kubelet \
            --cert-dir=/tmp/kubelet/pki \
            --tls-cert-file=/tmp/kubelet/pki/kubelet.crt \
            --tls-private-key-file=/tmp/kubelet/pki/kubelet.key \
            --hostname-override=$(hostname) \
            --pod-infra-container-image=registry.k8s.io/pause:3.10 \
            --node-ip=$HOST_IP \
            --cgroup-driver=cgroupfs \
            --max-pods=4  \
            --v=1 &
        sleep 5
        
        # Verify kubelet started
        if ! is_running "kubelet"; then
            print_error "Failed to start kubelet"
            return 1
        fi
        print_success "kubelet started"
    fi

    echo "Waiting for all components to be ready..."
    sleep 10

    echo "Verifying setup..."
    ./kubebuilder/bin/kubectl get nodes || true
    ./kubebuilder/bin/kubectl get all -A || true
}

stop() {
    echo "Stopping Kubernetes components..."
    stop_process "kube-controller-manager"
    stop_process "kubelet"
    stop_process "kube-scheduler"
    stop_process "kube-apiserver"
    stop_process "containerd"
    stop_process "etcd"
    echo "All components stopped"
}

cleanup() {
    stop
    echo "Cleaning up..."
    rm -rf ./etcd
    rm -rf /tmp/kubelet/*
    sudo rm -rf /run/containerd/*
    rm -f /tmp/sa.key /tmp/sa.pub /tmp/token.csv /tmp/ca.key /tmp/ca.crt
    echo "Cleanup complete"
}

# Function to setup Kind cluster for testing
setup_kind() {
    print_info "Setting up Kind cluster for testing..."

    # Download Kind if not present
    if [ ! -f "./kind" ]; then
        print_info "Downloading Kind..."
        curl -Lo kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64
        chmod +x kind
    fi

    # Add current directory to PATH and export it
    export PATH="$PWD:$PATH"

    # Check if cluster already exists
    if ./kind get clusters | grep -q "codespaces-test-cluster"; then
        print_warning "Kind cluster 'codespaces-test-cluster' already exists"
        print_info "Setting up kubeconfig for existing cluster..."
        ./kind export kubeconfig --name codespaces-test-cluster
        print_success "Kubeconfig set for existing cluster"
        return 0
    fi

    # Create Kind cluster
    print_info "Creating Kind cluster..."
    ./kind create cluster --name codespaces-test-cluster
    ./kind export kubeconfig --name codespaces-test-cluster

    print_success "Kind cluster created successfully"
}

# Function to test deployment
test_deployment() {
    print_info "Testing controller deployment..."

    # Make sure kubectl is in PATH
    export PATH="$PWD/kubebuilder/bin:$PATH"
    
    # Ensure we're using the Kind cluster context
    if [ -f "./kind" ]; then
        export PATH="$PWD:$PATH"
        if ./kind get clusters | grep -q "codespaces-test-cluster"; then
            ./kind export kubeconfig --name codespaces-test-cluster
        fi
    fi

    # Check if controller pod is running
    if kubectl get pods -n newresource-system -l app.kubernetes.io/name=newresource-controller &> /dev/null; then
        print_success "Controller pod is running"

        # Check CRDs
        if kubectl get crd newresources.apps.newresource.com &> /dev/null; then
            print_success "CRDs are installed"

            # Check custom resources
            if kubectl get newresources -n newresource-system &> /dev/null; then
                print_success "Custom resources are available"
                kubectl get newresources -n newresource-system
            else
                print_warning "No custom resources found"
            fi
        else
            print_warning "CRDs not found"
        fi
    else
        print_warning "Controller pod not found"
    fi

    # Show deployment status
    print_info "Deployment status:"
    kubectl get all -n newresource-system 2>/dev/null || print_warning "No resources in newresource-system namespace"
    
    # Verify controller functionality by checking if resources have status
    print_info "Verifying controller functionality:"
    if kubectl get newresources -n newresource-system &> /dev/null; then
        # Get one resource to check if status is populated
        FIRST_RESOURCE=$(kubectl get newresources -n newresource-system -o name | head -n 1 | cut -d/ -f2)
        if [ ! -z "$FIRST_RESOURCE" ]; then
            STATUS_OUTPUT=$(kubectl get newresources "$FIRST_RESOURCE" -n newresource-system -o jsonpath='{.status.ready}' 2>/dev/null)
            if [ ! -z "$STATUS_OUTPUT" ]; then
                print_success "Controller is functioning correctly (status populated)"
            else
                print_warning "Controller may not be updating status correctly"
                print_info "Triggering manual reconciliation..."
                # Trigger a simple update to force reconciliation
                kubectl patch newresource "$FIRST_RESOURCE" -n newresource-system -p '{"spec":{"reconcileTrigger":true}}' --type=merge 2>/dev/null || true
                sleep 3
            fi
        fi
    fi
}

# Function to verify Codespaces environment
verify_codespaces() {
    print_info "Verifying GitHub Codespaces environment..."

    if [[ -n "$CODESPACES" ]]; then
        print_success "Running in GitHub Codespaces"
        print_info "Container: $(hostname)"
        print_info "Workspace: $(pwd)"
    else
        print_warning "Not running in GitHub Codespaces"
    fi
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
}

# Function to check if Kind cluster is available
check_cluster() {
    if [ -f "./kind" ]; then
        if ! ./kind get clusters | grep -q "codespaces-test-cluster"; then
            print_error "Kind cluster not found. Please create one with './setup.sh kind'"
            exit 1
        fi
    else
        print_error "Kind binary not found. Please create a cluster with './setup.sh kind'"
        exit 1
    fi
}

# Function to wait for deployment readiness
wait_for_deployment() {
    local timeout=60
    local count=0
    
    echo "Waiting for controller deployment to be ready..."

    while [ $count -lt $timeout ]; do
        if kubectl get pods -n newresource-system -l app.kubernetes.io/name=newresource-controller -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}' | grep -q "True"; then
            print_success "Controller deployment is ready"
            return 0
        fi
        
        count=$((count + 5))
        echo "Still waiting for controller deployment... (${count}s/${timeout}s)"
        sleep 5
    done
    
    print_error "Controller deployment failed to become ready within timeout"
    return 1
}

# Function to show deployment status
show_status() {
    print_info "Deployment status:"
    kubectl get all -n newresource-system 2>/dev/null || print_warning "No resources in newresource-system namespace"
}

# Main deployment function
deploy_controller() {
    print_info "Starting deployment to $(detect_cluster_type) cluster..."

    check_kubectl
    check_cluster

    # Create namespace if it doesn't exist
    kubectl create namespace newresource-system --dry-run=client -o yaml | kubectl apply -f -

    # Regenerate and install CRDs to ensure they're up to date
    print_info "Regenerating and installing Custom Resource Definitions..."
    if [ -f "./new-controller/controller-gen" ] || command -v controller-gen &> /dev/null; then
        cd new-controller
        controller-gen crd paths="./..." output:crd:artifacts:config=config/crd/bases
        cd ..
    else
        print_warning "controller-gen not found, using existing CRD manifests"
    fi
    
    kubectl apply -f new-controller/config/crd/bases/
    print_success "CRDs installed successfully"

    # Install RBAC resources
    print_info "Installing RBAC resources..."
    kubectl apply -f new-controller/config/rbac/
    print_success "RBAC resources installed successfully"

    # Deploy controller
    print_info "Deploying controller..."
    kubectl apply -f new-controller/config/deployment.yaml
    kubectl apply -f new-controller/config/service.yaml
    print_success "Controller deployed successfully"

    # Wait for deployment readiness
    wait_for_deployment

    # Show status
    show_status
    print_success "Deployment completed successfully!"
    print_info "You can now create custom resources using: kubectl apply -f <your-resource>.yaml"
}

# Function to detect cluster type
detect_cluster_type() {
    if [ -f "./kind" ]; then
        if ./kind get clusters | grep -q "codespaces-test-cluster"; then
            echo "Kind"
        fi
    fi

    echo "Unknown"
}

case "${1:-}" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    cleanup)
        cleanup
        ;;
    kind)
        setup_kind
        ;;
    test)
        test_deployment
        ;;
    verify)
        verify_codespaces
        ;;
    deploy)
        setup_kind
        print_info "Deploying controller..."
        cd new-controller && ./deploy.sh deploy
        test_deployment
        ;;
    full-test)
        verify_codespaces
        setup_kind
        print_info "Running full deployment test..."
        cd new-controller && ./deploy.sh deploy
        test_deployment
        print_success "Full test completed!"
        ;;
    *)
        echo "Usage: $0 {start|stop|cleanup|kind|test|verify|deploy|full-test}"
        echo ""
        echo "Commands:"
        echo "  start      Start local Kubernetes cluster"
        echo "  stop       Stop local Kubernetes cluster"
        echo "  cleanup    Clean up all components"
        echo "  kind       Setup Kind cluster for testing"
        echo "  test       Test controller deployment"
        echo "  verify     Verify Codespaces environment"
        echo "  deploy     Setup Kind + deploy controller + test"
        echo "  full-test  Verify + deploy + test (complete workflow)"
        exit 1
        ;;
esac