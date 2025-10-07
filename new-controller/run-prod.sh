#!/bin/bash

# run-prod.sh - Production script for running the controller with leader election
# This script runs the controller with leader election enabled for production environments

set -e

echo "🚀 Starting controller in production mode (with leader election)..."

# Build the controller binary if it doesn't exist
if [ ! -f "bin/controller" ]; then
    echo "📦 Building controller binary..."
    make build
fi

# Run the controller with leader election enabled
echo "👑 Running controller with leader election enabled..."
echo "📊 Metrics will be available at http://localhost:8080/metrics"
echo "🏥 Health checks will be available at http://localhost:8081/healthz"
echo "🗳️  Leader election is enabled - only one instance will be active"
echo "🛑 Press Ctrl+C to stop the controller"
echo ""

# Execute the controller with production settings (leader election enabled)
./bin/controller \
    --metrics-bind-address=:8080 \
    --health-probe-bind-address=:8081 \
    --leader-elect=true \
    --leader-election-id=newresource-controller