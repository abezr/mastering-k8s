# Architecture

This document explains how the controller is structured and how the main pieces interact at runtime.

## Components

- API Types
  - Group and version registration: api/v1alpha1/groupversion.go
  - Resource types and status: api/v1alpha1/newresource_types.go
- Controller Runtime Manager
  - Application entry point: main.go
  - Manager configuration: metrics, health, leader election
- Reconciler
  - Controller logic for NewResource: controllers/resource_controller.go
  - Reads objects, updates status, emits metrics
- Manifests and Deployment
  - CRDs: config/crd/bases/
  - RBAC resources: config/rbac/
  - Controller Deployment: config/deployment.yaml
  - Metrics Service: config/service.yaml
- CI/CD and Container Image
  - Dockerfile for reproducible builds
  - GitHub Actions: .github/workflows/

## Data Model

Custom Resource Definition: NewResource
- Scope: Namespaced
- Version: v1alpha1
- Spec
  - foo: string
- Status
  - ready: boolean

Controller code owns the types and ensures a matching CRD is present in the cluster so the API is recognized.

## Runtime Flow

1. Process Start
   - The program starts in main.go
   - A scheme is created and API types are registered
   - Controller-runtime manager is configured with:
     - Metrics server on 8080
     - Health and readiness endpoints on 8081
     - Optional leader election
2. Controller Registration
   - NewResourceReconciler is constructed and registered
   - The controller declares it watches NewResource objects
3. Event Handling
   - When a NewResource is created/updated, the manager enqueues a reconcile request with namespace/name
4. Reconcile Loop
   - The reconciler retrieves the resource
   - If not found (deleted), it gracefully exits
   - If found, it executes logic to converge desired and observed state
   - In this example, it sets status.ready = true and updates resource status
   - Errors are returned to be retried by controller-runtime with exponential backoff
5. Metrics
   - Reconcile attempts, duration, and errors are recorded
6. Shutdown
   - The manager listens for termination signals and shuts down gracefully

## Manager Configuration

Key options:
- Metrics server (Prometheus format) exposed on :8080
- Health endpoints exposed on :8081
  - /healthz for liveness
  - /readyz for readiness
- Leader Election
  - Optional via flag/arg; required for multi-replica, HA deployments
  - Election ID and namespace must be consistent across replicas

## Controller Responsibilities

- Watch NewResource resources
- Reconcile on add/update/delete events
- Update status based on the logic outcome
- Emit metrics and logs

## Reconciler Logic Outline

- Retrieve NewResource by namespaced name
- Ignore not found (object deleted)
- Execute business logic (today: mark status.ready = true)
- Update Status subresource
- Return no error to indicate success

This logic is intentionally simple to focus on structure; real controllers would perform idempotent operations against Kubernetes resources and external systems to converge toward desired state.

## Metrics

Emitted via Prometheus client and exposed on :8080/metrics:
- controller_reconcile_total
  - Labels: controller, result (started, success, error, not_found)
- controller_reconcile_duration_seconds
  - Labels: controller
  - Histogram buckets: Prometheus default
- controller_reconcile_errors_total
  - Labels: controller, error_type (get_resource, status_update)

Health endpoints:
- /healthz (liveness) on 8081
- /readyz (readiness) on 8081

## Deployment Topology

- Namespace: newresource-system
- Deployment: newresource-controller
- ServiceAccount: newresource-controller
- RBAC
  - Role grants read on newresources and write on status
  - RoleBinding binds Role to ServiceAccount
- Service: Exposes metrics on port 8080 (ClusterIP)
- Security Context
  - Non-root, read-only root filesystem, dropped capabilities, RuntimeDefault seccomp

## CI/CD Overview

- Build and Test pipeline (.github/workflows/ci.yml)
  - go mod tidy check
  - fmt, vet, golangci-lint
  - unit tests with envtest assets and coverage artifact
- Container Publish (.github/workflows/docker-publish.yml)
  - Multi-arch build (linux/amd64, linux/arm64)
  - Push to GHCR
- Future: e2e with Kind
  - Spin Kind, load image, apply manifests, exercise CRD, assert status

## Naming and Consistency

Recommended single source of truth:
- API group: apps.newresource.com
- Namespace: newresource-system
- Deployment name: newresource-controller

Ensure CRD manifests and code share the same group/version to avoid runtime mismatches.

## Extensibility and Next Steps

- Replace placeholder business logic with real reconciliation
- Add finalizers for cleanup
- Implement rate limiting and backoff tuning on the work queue if needed
- Add admission webhooks for validation/mutation flows
- Parameterize behavior via ConfigMap
- Add event recording to surface status transitions to users

## Notes on Idempotency

Reconciliation must be idempotent:
- The same request may be processed multiple times
- Resource updates should be resilient to retries
- External side effects must be guarded against duplication and partial failures

## Failure Modes and Retries

- Transient errors cause exponential backoff and retries
- Permanent errors should be surfaced via status conditions and logged appropriately
- Use specific error types for metrics labels to categorize failures
