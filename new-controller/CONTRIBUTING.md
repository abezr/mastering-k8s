# Contributing

We welcome contributions to this Kubernetes controller project! This document outlines the process for contributing.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/your-username/mastering-k8s.git
   cd mastering-k8s/new-controller
   ```
3. **Create a feature branch**:
   ```bash
   git checkout -b feature/amazing-feature
   ```

## Development Setup

### Prerequisites

- Go 1.21 or later
- Docker (for containerized testing)
- Kind or Minikube (for integration testing)
- kubectl

### Initial Setup

1. **Install dependencies**:
   ```bash
   go mod download
   ```

2. **Set up pre-commit hooks** (optional):
   ```bash
   # Install pre-commit
   pip install pre-commit
   pre-commit install
   ```

3. **Verify setup**:
   ```bash
   make help
   ```

## Making Changes

### Code Style

- Follow standard Go formatting: `go fmt ./...`
- Run linters: `make lint`
- Write tests for new functionality
- Update documentation as needed

### Testing

**Run all tests**:
```bash
make test
```

**Run with coverage**:
```bash
make test-coverage
```

**Run specific test**:
```bash
go test ./test -run TestMainController -v
```

### Documentation

- Update README.md for user-facing changes
- Update docs/ for architectural changes
- Add examples in docs/EXAMPLES.md

## Submitting Changes

1. **Test your changes**:
   ```bash
   make test
   make build
   ```

2. **Commit your changes**:
   ```bash
   git add .
   git commit -m "Add amazing feature"
   ```

3. **Push to your fork**:
   ```bash
   git push origin feature/amazing-feature
   ```

4. **Create a Pull Request**:
   - Go to the original repository
   - Click "New Pull Request"
   - Select your feature branch
   - Fill out the PR template
   - Click "Create Pull Request"

## Pull Request Process

### Required Checks

All PRs must pass:
- **CI Pipeline**: GitHub Actions build and test
- **Code Review**: At least one maintainer approval
- **Tests**: All existing tests pass

### PR Template

Use the provided PR template and include:
- Description of changes
- Motivation and context
- Testing performed
- Screenshots (if applicable)

## Development Workflow

### Branch Naming

- `feature/feature-name` - New features
- `bugfix/issue-description` - Bug fixes
- `docs/documentation-update` - Documentation changes
- `refactor/component-name` - Code refactoring

### Commit Messages

Follow [Conventional Commits](https://conventionalcommits.org/):

```
feat: add new reconciliation logic
fix: resolve metrics registration issue
docs: update API documentation
```

## Code Standards

### Go Best Practices

- Use `context.Context` for cancellation
- Handle errors appropriately
- Write idiomatic Go code
- Use interfaces for testability

### Controller Patterns

- Follow controller-runtime best practices
- Implement proper reconciliation loops
- Use finalizers for cleanup
- Emit meaningful events

### Testing

- Write unit tests for all business logic
- Use table-driven tests where appropriate
- Mock external dependencies
- Test error conditions

## Getting Help

### Documentation

- [Architecture Guide](docs/ARCHITECTURE.md)
- [Testing Guide](docs/TESTING.md)
- [Metrics Documentation](docs/METRICS.md)
- [Deployment Guide](DEPLOYMENT.md)

### Communication

- **Issues**: Use GitHub Issues for bugs and features
- **Discussions**: Use GitHub Discussions for questions
- **Email**: For sensitive security issues

## Security

### Reporting Vulnerabilities

Report security vulnerabilities to maintainers privately. Do not create public issues for security problems.

### Security Best Practices

- Keep dependencies updated
- Use security scanning in CI
- Follow principle of least privilege
- Validate all inputs

## Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes
- GitHub repository insights

Thank you for contributing to this project! 🚀