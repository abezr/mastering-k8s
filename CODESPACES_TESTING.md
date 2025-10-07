# GitHub Codespaces Deployment Testing Guide

This guide explains how to test your Kubernetes controller deployment in GitHub Codespaces using the enhanced `setup.sh` script.

## 🚀 Quick Start

### Complete Testing Workflow

```bash
# 1. Make script executable
chmod +x setup.sh

# 2. Run complete test (recommended)
./setup.sh full-test

# 3. Manual testing if needed
./setup.sh verify      # Check Codespaces environment
./setup.sh kind        # Setup Kind cluster
./setup.sh deploy      # Deploy controller and test
```

## 📋 Available Commands

| Command | Description |
|---------|-------------|
| `./setup.sh start` | Start local Kubernetes cluster |
| `./setup.sh stop` | Stop local Kubernetes cluster |
| `./setup.sh cleanup` | Clean up all components |
| `./setup.sh kind` | Setup Kind cluster for testing |
| `./setup.sh test` | Test controller deployment |
| `./setup.sh verify` | Verify Codespaces environment |
| `./setup.sh deploy` | Setup Kind + deploy controller + test |
| `./setup.sh full-test` | Complete workflow (verify + deploy + test) |

## 🔍 What Gets Tested

### ✅ Environment Verification
- Detects GitHub Codespaces environment
- Verifies container/VM setup
- Checks workspace configuration

### ✅ Kind Cluster Setup
- Downloads Linux-compatible Kind binary
- Creates `codespaces-test-cluster`
- Configures kubectl context

### ✅ Controller Deployment
- Builds Docker image
- Loads image into Kind cluster
- Deploys controller to `newresource-system` namespace
- Installs CRDs and RBAC

### ✅ Functionality Testing
- Verifies controller pod status
- Checks CRD installation
- Tests custom resource creation
- Validates leader election

## 🎯 Expected Output

### Complete Test Results
```bash
$ ./setup.sh full-test

[INFO] Detected environment: codespaces
[INFO] Verifying GitHub Codespaces environment...
[SUCCESS] Running in GitHub Codespaces
[INFO] Container: codespaces-xxxxx
[INFO] Workspace: /workspaces/mastering-k8s

[INFO] Setting up Kind cluster for testing...
[INFO] Creating Kind cluster...
[SUCCESS] Kind cluster created successfully

[INFO] Running full deployment test...
[INFO] Deploying controller...
[SUCCESS] Controller deployed successfully

[INFO] Testing controller deployment...
[SUCCESS] Controller pod is running
[SUCCESS] CRDs are installed
[SUCCESS] Custom resources are available

[SUCCESS] Full test completed!
```

### Verification Commands
```bash
# Check cluster
kubectl get nodes
# Output: codespaces-test-cluster-control-plane   Ready    control-plane   v1.31.0

# Check controller
kubectl get pods -n newresource-system
# Output: newresource-controller-xxxxx   1/1     Running   0

# Check CRDs
kubectl get crd | grep newresource
# Output: newresources.apps.newresource.com   2025-10-07T14:41:54Z

# Check custom resources
kubectl get newresources -n newresource-system
# Output: codespaces-test-resource   1m
```

## 🔧 Troubleshooting

### Common Issues

**Problem**: `kubectl` shows "connection refused"
```bash
# Solution: Check context and cluster status
kubectl config get-contexts
kubectl config use-context kind-codespaces-test-cluster
kubectl cluster-info
```

**Problem**: "Permission denied" errors
```bash
# Solution: Ensure proper permissions
chmod +x setup.sh
chmod +x new-controller/deploy.sh
```

**Problem**: Pod in `CrashLoopBackOff`
```bash
# Solution: Check logs and RBAC
kubectl logs -n newresource-system <pod-name>
kubectl get events -n newresource-system
```

## 📊 Testing Checklist

- [ ] GitHub Codespaces environment detected
- [ ] Kind cluster created successfully
- [ ] kubectl context configured correctly
- [ ] Controller pod running (1/1 ready)
- [ ] CRDs installed and available
- [ ] Custom resources can be created
- [ ] Leader election working
- [ ] All components healthy

## 🎉 Success Criteria

Your GitHub Codespaces deployment is working if:

1. **Environment**: Script detects `codespaces` environment
2. **Cluster**: `codespaces-test-cluster` node shows `Ready`
3. **Controller**: Pod in `newresource-system` shows `1/1 Running`
4. **CRDs**: `newresources.apps.newresource.com` is installed
5. **Resources**: Custom resources can be created and managed
6. **Health**: All components pass health checks

## 🚀 Next Steps

After successful testing:

1. **Document Results**: Note any environment-specific configurations
2. **CI/CD Integration**: Use the `full-test` command in your pipelines
3. **Development**: Use this setup for ongoing controller development
4. **Debugging**: Use `./setup.sh test` for quick deployment verification

---

**🎯 Your enhanced `setup.sh` script now provides a complete testing solution for GitHub Codespaces deployment verification!**