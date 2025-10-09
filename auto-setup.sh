#!/bin/bash

# Auto-setup script for Kubernetes controller environment
# This script automates the setup process to avoid common issues

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

# Check if we're in the right directory
if [ ! -f "setup.sh" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

print_info "Starting automated setup process..."

# Make sure setup.sh is executable
chmod +x setup.sh

# Download and setup Kind if needed
print_info "Setting up Kind cluster..."
./setup.sh kind

# Verify cluster connectivity
print_info "Verifying cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi
print_success "Cluster connection verified"

# Build and load controller image
print_info "Building and loading controller image..."
cd new-controller
chmod +x build-and-load.sh
./build-and-load.sh
cd ..

# Deploy controller
print_info "Deploying controller..."
./setup.sh deploy

# Run verification
print_info "Running verification tests..."
./setup.sh test

print_success "Automated setup completed successfully!"
print_info "You can now create custom resources using: kubectl apply -f <your-resource>.yaml"