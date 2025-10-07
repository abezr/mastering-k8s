# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Complete Kubernetes controller implementation with controller-runtime
- Comprehensive test suite with envtest integration
- Prometheus metrics and health endpoints
- Production-ready security context and RBAC
- Docker multi-stage build configuration
- GitHub Actions CI/CD pipelines
- Comprehensive documentation suite

### Changed
- Module path updated to github.com/abezr/mastering-k8s/new-controller
- Metrics registration improved to avoid double registration
- CRD group aligned to match code registration (apps.newresource.com)

## [1.0.0] - 2024-01-XX

### Added
- Initial implementation of NewResource controller
- Basic reconciliation logic with status updates
- CRD definitions and RBAC configuration
- Development and deployment scripts
- Basic test framework

### Features
- Leader election support for high availability
- Metrics collection with Prometheus integration
- Health and readiness probes
- Security best practices (non-root, read-only filesystem)
- Comprehensive Makefile with 20+ development targets

---

## Versioning Policy

We follow [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html):

- **MAJOR** version for breaking changes
- **MINOR** version for new features that are backward compatible
- **PATCH** version for bug fixes that are backward compatible

### Release Cadence

- **Patch releases** (1.0.x): As needed for bug fixes
- **Minor releases** (1.x.0): Every 4-6 weeks with new features
- **Major releases** (x.0.0): For breaking changes or major architectural updates

### Pre-release Versions

Pre-release versions use the format `MAJOR.MINOR.PATCH-alpha.N` or `MAJOR.MINOR.PATCH-beta.N`.

## Contributing

When contributing to this project, please update the [Unreleased] section above with your changes. Use the following categories:

- **Added** for new features
- **Changed** for changes in existing functionality
- **Deprecated** for soon-to-be removed features
- **Removed** for now removed features
- **Fixed** for any bug fixes
- **Security** for vulnerability fixes