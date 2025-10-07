# GitHub Codespaces Deployment Test Specification

## Overview

This document provides a comprehensive testing plan for deploying and validating the Kubernetes controller for NewResource custom resources in GitHub Codespaces environment. The test specification covers end-to-end deployment workflows, functionality validation, performance testing, and security verification.

## Test Environment Prerequisites

### Hardware/Software Requirements
- GitHub Codespaces with 4-core CPU, 8GB RAM, 32GB storage
- Kubernetes cluster (kind, k3s, or similar) running in Codespaces
- kubectl configured and accessible
- Go 1.19+ installed
- Docker available for container operations

### Pre-Test Validation
```bash
# Verify kubectl connectivity
kubectl cluster-info

# Check node status
kubectl get nodes

# Verify cluster components
kubectl get pods -n kube-system

# Check available storage
df -h

# Verify Go installation
go version

# Check available memory
free -h
```

## Testing Phases

### Phase 1: Pre-Deployment Environment Validation

#### Test Case 1.1: Cluster Health Verification
**Objective:** Ensure the Kubernetes cluster is healthy and ready for deployment.

**Steps:**
1. Verify all core components are running:
   ```bash
   kubectl get pods -n kube-system
   ```

2. Check node readiness:
   ```bash
   kubectl get nodes
   ```

3. Verify API server responsiveness:
   ```bash
   kubectl api-versions
   ```

**Expected Outcomes:**
- All kube-system pods should be in `Running` state
- Nodes should show `Ready` status
- API server should respond without errors
- No `CrashLoopBackOff` or `Error` states

**Success Criteria:**
- ✅ All core components operational
- ✅ No resource constraints
- ✅ API server responsive

#### Test Case 1.2: Network Connectivity Validation
**Objective:** Ensure proper network configuration for controller operations.

**Steps:**
1. Test DNS resolution:
   ```bash
   nslookup kubernetes.io
   ```

2. Verify port accessibility:
   ```bash
   kubectl port-forward --help
   ```

3. Check service discovery:
   ```bash
   kubectl get services -n kube-system
   ```

**Expected Outcomes:**
- DNS resolution working
- Port forwarding capabilities available
- Service discovery functional

**Troubleshooting:**
- If DNS fails, check `/etc/resolv.conf`
- If port-forward fails, verify Docker networking

### Phase 2: Deployment Testing

#### Test Case 2.1: CRD Installation Verification
**Objective:** Validate Custom Resource Definition deployment and functionality.

**Steps:**
1. Apply CRD manifests:
   ```bash
   kubectl apply -f config/crd/bases/example.com_newresources.yaml
   ```

2. Verify CRD registration:
   ```bash
   kubectl get crd newresources.example.com
   ```

3. Check CRD details:
   ```bash
   kubectl describe crd newresources.example.com
   ```

**Expected Outcomes:**
- CRD should be in `Established` condition
- Served version should match the defined version
- No admission errors

**Success Criteria:**
- ✅ CRD successfully registered
- ✅ API version available
- ✅ Storage version configured

#### Test Case 2.2: RBAC Configuration Validation
**Objective:** Ensure proper Role-Based Access Control setup.

**Steps:**
1. Create service account:
   ```bash
   kubectl apply -f config/rbac/service_account.yaml
   ```

2. Apply RBAC roles:
   ```bash
   kubectl apply -f config/rbac/role.yaml
   kubectl apply -f config/rbac/role_binding.yaml
   ```

3. Verify RBAC components:
   ```bash
   kubectl get serviceaccounts,roles,rolebindings -n newresource-system
   ```

**Expected Outcomes:**
- ServiceAccount created successfully
- Role and RoleBinding applied without errors
- All RBAC resources show correct relationships

**Troubleshooting:**
- Check service account token mounting
- Verify role references match service account

#### Test Case 2.3: Controller Deployment Testing
**Objective:** Validate controller deployment and initialization.

**Steps:**
1. Deploy the controller:
   ```bash
   kubectl apply -f config/deployment.yaml
   ```

2. Monitor deployment rollout:
   ```bash
   kubectl rollout status deployment/newresource-controller -n newresource-system
   ```

3. Check pod status:
   ```bash
   kubectl get pods -n newresource-system -l control-plane=controller-manager
   ```

4. Verify controller logs:
   ```bash
   kubectl logs -n newresource-system deployment/newresource-controller
   ```

**Expected Outcomes:**
- Deployment should complete successfully
- Pods should be in `Running` state
- Controller logs should show successful startup
- Manager cache should be synchronized

**Success Criteria:**
- ✅ Controller pod running
- ✅ No crash loops
- ✅ Successful cache sync
- ✅ Leader election functional

#### Test Case 2.4: Service Deployment Validation
**Objective:** Ensure service components are properly deployed and accessible.

**Steps:**
1. Apply service manifests:
   ```bash
   kubectl apply -f config/service.yaml
   ```

2. Verify service creation:
   ```bash
   kubectl get services -n newresource-system
   ```

3. Test service endpoints:
   ```bash
   kubectl get endpoints -n newresource-system
   ```

**Expected Outcomes:**
- Service should be created with correct selector
- Endpoints should match pod IPs
- Service should be accessible within cluster

### Phase 3: Functionality Testing

#### Test Case 3.1: Custom Resource Creation
**Objective:** Test basic NewResource creation and reconciliation.

**Steps:**
1. Create a test NewResource:
   ```bash
   cat <<EOF | kubectl apply -f -
   apiVersion: example.com/v1alpha1
   kind: NewResource
   metadata:
     name: test-resource
     namespace: default
   spec:
     # Add required spec fields based on your CRD
     foo: bar
   EOF
   ```

2. Verify resource creation:
   ```bash
   kubectl get newresources.example.com test-resource
   ```

3. Check controller reconciliation:
   ```bash
   kubectl describe newresources.example.com test-resource
   ```

**Expected Outcomes:**
- NewResource should be created successfully
- Controller should reconcile the resource
- Status should be updated appropriately
- Events should be generated

**Success Criteria:**
- ✅ Resource created without errors
- ✅ Controller processed the resource
- ✅ Status reflects current state

#### Test Case 3.2: Controller Reconciliation Testing
**Objective:** Validate controller's reconciliation logic.

**Steps:**
1. Monitor controller logs during reconciliation:
   ```bash
   kubectl logs -n newresource-system deployment/newresource-controller -f
   ```

2. Update the test resource:
   ```bash
   kubectl patch newresource test-resource -p '{"spec":{"foo":"updated"}}' --type=merge
   ```

3. Verify reconciliation response:
   ```bash
   kubectl get newresources.example.com test-resource -o yaml
   ```

**Expected Outcomes:**
- Controller should detect spec changes
- Reconciliation should process updates
- Status should reflect updated state
- Appropriate events should be logged

#### Test Case 3.3: Event Generation Validation
**Objective:** Ensure proper event generation for resource lifecycle.

**Steps:**
1. Check events for the test resource:
   ```bash
   kubectl get events --field-selector involvedObject.name=test-resource
   ```

2. Verify event types and messages:
   ```bash
   kubectl describe newresources.example.com test-resource
   ```

**Expected Outcomes:**
- Creation events should be logged
- Update events should be generated
- Events should have appropriate types and messages

### Phase 4: Integration Testing

#### Test Case 4.1: End-to-End Workflow Validation
**Objective:** Test complete resource lifecycle management.

**Steps:**
1. Create multiple test resources:
   ```bash
   for i in {1..3}; do
     cat <<EOF | kubectl apply -f -
     apiVersion: example.com/v1alpha1
     kind: NewResource
     metadata:
       name: test-resource-$i
       namespace: default
     spec:
       foo: "test-$i"
     EOF
   done
   ```

2. Verify all resources:
   ```bash
   kubectl get newresources.example.com
   ```

3. Test bulk updates:
   ```bash
   kubectl get newresources.example.com -o jsonpath='{.items[*].metadata.name}' | xargs -n 1 kubectl patch newresource -p '{"spec":{"foo":"bulk-updated"}}' --type=merge
   ```

**Expected Outcomes:**
- Multiple resources should be managed concurrently
- Controller should handle bulk operations
- No resource conflicts or race conditions

#### Test Case 4.2: Error Handling Validation
**Objective:** Test controller behavior with invalid resources.

**Steps:**
1. Create resource with invalid spec:
   ```bash
   cat <<EOF | kubectl apply -f -
   apiVersion: example.com/v1alpha1
   kind: NewResource
   metadata:
     name: invalid-resource
     namespace: default
   spec:
     invalidField: "should cause error"
   EOF
   ```

2. Check controller error handling:
   ```bash
   kubectl describe newresources.example.com invalid-resource
   ```

**Expected Outcomes:**
- Controller should handle errors gracefully
- Appropriate error events should be generated
- Resource status should reflect error state

### Phase 5: Performance Testing

#### Test Case 5.1: Resource Consumption Monitoring
**Objective:** Validate controller performance under load.

**Steps:**
1. Monitor controller resource usage:
   ```bash
   kubectl top pods -n newresource-system
   ```

2. Check memory and CPU utilization:
   ```bash
   kubectl describe pods -n newresource-system deployment/newresource-controller
   ```

**Expected Outcomes:**
- Memory usage should be stable
- CPU usage should be within acceptable limits
- No memory leaks detected

**Success Criteria:**
- ✅ Memory usage < 500MB
- ✅ CPU usage < 50% of allocated
- ✅ Stable resource consumption

#### Test Case 5.2: Concurrent Operations Testing
**Objective:** Test controller performance with concurrent resource operations.

**Steps:**
1. Create multiple resources simultaneously:
   ```bash
   for i in {1..10}; do
     kubectl apply -f - <<EOF
   apiVersion: example.com/v1alpha1
   kind: NewResource
   metadata:
     name: perf-test-$i
     namespace: default
   spec:
     foo: "perf-test-$i"
   EOF
   done &
   ```

2. Monitor reconciliation performance:
   ```bash
   time kubectl get newresources.example.com --all-namespaces
   ```

**Expected Outcomes:**
- Controller should handle concurrent operations
- Response times should remain acceptable
- No operation timeouts

### Phase 6: Security Testing

#### Test Case 6.1: RBAC Permissions Validation
**Objective:** Verify proper access controls are enforced.

**Steps:**
1. Test service account permissions:
   ```bash
   kubectl auth can-i get newresources --as=system:serviceaccount:newresource-system:newresource-controller
   ```

2. Verify role restrictions:
   ```bash
   kubectl auth can-i get pods --as=system:serviceaccount:newresource-system:newresource-controller -n kube-system
   ```

**Expected Outcomes:**
- Controller should have appropriate permissions for NewResources
- Controller should not have excessive permissions
- RBAC rules should be properly enforced

#### Test Case 6.2: Service Account Security
**Objective:** Validate service account token handling.

**Steps:**
1. Check service account token mounting:
   ```bash
   kubectl describe serviceaccount newresource-controller -n newresource-system
   ```

2. Verify token permissions:
   ```bash
   kubectl get secrets -n newresource-system
   ```

**Expected Outcomes:**
- Service account should have properly mounted tokens
- Token should have appropriate permissions
- No token leaks or unauthorized access

### Phase 7: Cleanup Testing

#### Test Case 7.1: Resource Deletion Verification
**Objective:** Ensure proper cleanup of resources.

**Steps:**
1. Delete test resources:
   ```bash
   kubectl delete newresources.example.com --all
   ```

2. Verify resource cleanup:
   ```bash
   kubectl get newresources.example.com
   ```

3. Check for orphaned resources:
   ```bash
   kubectl api-resources --verbs=list --namespaced -o name | xargs -n 1 kubectl get --show-kind --ignore-not-found -n default
   ```

**Expected Outcomes:**
- All resources should be deleted successfully
- No orphaned resources should remain
- Controller should handle deletion gracefully

#### Test Case 7.2: Controller Cleanup Validation
**Objective:** Verify controller cleanup procedures.

**Steps:**
1. Scale down controller:
   ```bash
   kubectl scale deployment newresource-controller -n newresource-system --replicas=0
   ```

2. Verify pod termination:
   ```bash
   kubectl get pods -n newresource-system
   ```

3. Clean up controller resources:
   ```bash
   kubectl delete -f config/deployment.yaml
   kubectl delete -f config/rbac/
   kubectl delete -f config/service.yaml
   ```

**Expected Outcomes:**
- Controller should shut down gracefully
- No hanging processes or resources
- Complete cleanup of all components

## Troubleshooting Guide

### Common Issues and Solutions

#### Issue 1: CRD Installation Fails
**Symptoms:** CRD registration errors, API not available
**Solution:**
- Check API server logs: `kubectl logs -n kube-system kube-apiserver-*`
- Verify CRD syntax: `kubectl apply --dry-run=client -f config/crd/bases/`
- Check for conflicting CRDs: `kubectl get crd | grep example.com`

#### Issue 2: Controller Pod Crashes
**Symptoms:** CrashLoopBackOff, pod restarts
**Solution:**
- Check pod events: `kubectl describe pod -n newresource-system`
- Review controller logs: `kubectl logs -n newresource-system deployment/newresource-controller --previous`
- Verify resource requirements and limits

#### Issue 3: Reconciliation Not Working
**Symptoms:** Resources stuck in pending state, no status updates
**Solution:**
- Check controller logs for errors
- Verify RBAC permissions
- Test controller-manager cache sync

#### Issue 4: Performance Degradation
**Symptoms:** Slow reconciliation, high resource usage
**Solution:**
- Monitor resource consumption: `kubectl top pods`
- Check for resource leaks in logs
- Verify concurrent operation handling

## Test Execution Checklist

- [ ] Phase 1: Environment validation completed
- [ ] Phase 2: All deployment components verified
- [ ] Phase 3: Core functionality tested
- [ ] Phase 4: Integration scenarios validated
- [ ] Phase 5: Performance benchmarks met
- [ ] Phase 6: Security controls confirmed
- [ ] Phase 7: Cleanup procedures verified

## Success Metrics

- **Deployment Success Rate:** > 95%
- **Average Reconciliation Time:** < 30 seconds
- **Resource Cleanup Success:** 100%
- **Error Rate:** < 1%
- **Performance Degradation:** < 10% under load

## Test Data and Artifacts

All test resources created during testing should be properly cleaned up. Test logs and results should be archived for future reference and debugging purposes.

## Maintenance and Updates

This test specification should be reviewed and updated regularly to reflect:
- Changes in controller functionality
- Updates to Kubernetes dependencies
- Improvements in testing methodologies
- New security requirements