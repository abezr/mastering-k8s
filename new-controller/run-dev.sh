#!/bin/bash

# run-dev.sh - Development script for running the controller in single instance mode
# This script runs the controller without leader election for local development

set -e

echo "🚀 Starting controller in development mode (single instance)..."

# Build the controller binary if it doesn't exist
if [ ! -f "bin/controller" ]; then
    echo "📦 Building controller binary..."
    make build
fi

# Run the controller without leader election
echo "🔧 Running controller without leader election..."
echo "📊 Metrics will be available at http://localhost:8080/metrics"
echo "🏥 Health checks will be available at http://localhost:8081/healthz"
echo "🛑 Press Ctrl+C to stop the controller"
echo ""

# Execute the controller with development settings
./bin/controller \
    --metrics-bind-address=:8080 \
    --health-probe-bind-address=:8081 \
    --leader-elect=false