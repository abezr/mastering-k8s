# Testing Guide

This document explains how to run the test suite locally and in CI, including envtest setup, coverage, and leader election tests.

## Overview

- Unit tests use controller-runtime envtest to provide a lightweight API server and etcd for tests
- Metrics and health endpoints are not required for unit tests but are part of the controller process in main
- Leader election can be exercised via scripts or targeted tests
- Tests are deterministic and should be idempotent

## Prerequisites

- Go 1.21 or later
- Git
- For envtest: kubebuilder test assets (kube-apiserver, etcd, kubectl) installed and referenced via KUBEBUILDER_ASSETS

## Getting the envtest binaries

Use setup-envtest tool from controller-runtime:

```bash
# Install setup-envtest
go install sigs.k8s.io/controller-runtime/tools/setup-envtest@latest

# Discover and export the asset path (Linux/macOS)
export KUBEBUILDER_ASSETS="$($(go env GOPATH)/bin/setup-envtest use -p path 1.29.x)"
echo "$KUBEBUILDER_ASSETS"

# Verify binaries are present
ls -la "$KUBEBUILDER_ASSETS"
```

Windows (PowerShell):

```powershell
go install sigs.k8s.io/controller-runtime/tools/setup-envtest@latest
$assets = & "$env:GOPATH\bin\setup-envtest.exe" use -p path 1.29.x
$env:KUBEBUILDER_ASSETS = $assets
Write-Host $env:KUBEBUILDER_ASSETS
```

Notes:
- Use a version of envtest assets compatible with your k8s libraries (1.29.x works well with controller-runtime v0.16.x and k8s v0.28.x)
- You can cache these binaries in CI as well

## Running tests

Standard run:

```bash
# From repository root
go test ./... -count=1
```

Run with envtest assets and coverage:

```bash
# Unix-like shells
export KUBEBUILDER_ASSETS="$($(go env GOPATH)/bin/setup-envtest use -p path 1.29.x)"
go test ./... -count=1 -race -coverprofile=cover.out -covermode=atomic
```

View coverage HTML:

```bash
go tool cover -html=cover.out -o cover.html
# open cover.html in your browser
```

## Test structure

- test/test_utils.go
  - Sets up envtest Environment
  - Creates manager with metrics disabled by default in tests
  - Provides client and scheme
- test/main_test.go
  - Verifies CRD availability in envtest cluster
  - Starts manager and reconciler
  - Creates a sample NewResource and validates status/CRUD operations

## Common issues

1. envtest binaries not found:

```
no such file or directory: kube-apiserver
```

Solution:
- Ensure KUBEBUILDER_ASSETS points to the directory containing kube-apiserver, etcd and kubectl
- Verify the path prints the expected directory

2. Port collisions:

If your local environment already uses ports used by test binaries, kill those processes or change envtest port selections. The defaults usually work.

3. CRD path missing:

Tests expect CRDs at config/crd/bases. If you removed or renamed files, regenerate with controller-gen or restore files.

## Leader election tests

Leader election is not required for unit tests and is generally exercised via scripts in a running cluster. Use the provided scripts:

```bash
# Run two instances and observe leader handoff
./test-leader-election.sh
```

For local clusters (kind, minikube), you can scale the deployment:

```bash
kubectl -n newresource-system scale deployment/newresource-controller --replicas=2
kubectl -n newresource-system logs -f deployment/newresource-controller
```

You should see a single leader at any given time and followers awaiting leadership.

## Linting and static checks

The CI pipeline runs:
- go mod tidy check
- go fmt verification
- go vet
- golangci-lint

Run locally:

```bash
go mod tidy
gofmt -s -l .
go vet ./...
golangci-lint run
```

Install golangci-lint:

```bash
# macOS
brew install golangci-lint

# or cross-platform via install script
curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin latest
```

## Troubleshooting tests

- Ensure you are running from the repository root so that relative CRD paths resolve
- Use -count=1 to avoid cache effects during development
- Use -run to filter tests:
  ```bash
  go test ./test -run TestMainController -v
  ```
- If CRD installation fails in envtest, confirm your CRD group and version in the YAML matches your Go types

## CI notes

GitHub Actions (.github/workflows/ci.yml) will:
- Setup Go
- Check go mod tidy and formatting
- Run vet and golangci-lint
- Download envtest assets and run tests with coverage
- Upload coverage artifact (cover.out)