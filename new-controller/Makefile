# Image URL to use all building/pushing image targets
IMG ?= controller:latest

# Get the currently used golang install directory (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

# Setting SHELL to bash allows bash commands to be executed by recipes.
# Options are set to exit when a recipe line exits non-zero or a piped command fails.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

.PHONY: all
all: build

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lcw/awk_whatever_to_awk
.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

.PHONY: run-dev
run-dev: ## Run controller in development mode (single instance, no leader election)
	./run-dev.sh

.PHONY: run-prod
run-prod: ## Run controller in production mode (with leader election)
	./run-prod.sh

.PHONY: test-leader-election
test-leader-election: ## Test leader election functionality with multiple instances
	./test-leader-election.sh

.PHONY: fmt
fmt: ## Run go fmt against code.
	go fmt ./...

.PHONY: vet
vet: ## Run go vet against code.
	go vet ./...

.PHONY: test
test: fmt vet ## Run tests.
	go test ./... -coverprofile cover.out

.PHONY: test-coverage
test-coverage: test ## Run tests with coverage report.
	go tool cover -html=cover.out -o cover.html

.PHONY: lint
lint: ## Run golangci-lint against code.
	golangci-lint run

.PHONY: lint-fix
lint-fix: ## Run golangci-lint with auto-fix.
	golangci-lint run --fix

.PHONY: tidy
tidy: ## Tidy go modules.
	go mod tidy

.PHONY: mod-download
mod-download: ## Download go modules.
	go mod download

.PHONY: clean
clean: ## Clean build artifacts.
	rm -f controller
	rm -f cover.out cover.html
	docker rmi $(IMG) || true

##@ Build

.PHONY: build
build: fmt vet ## Build controller binary.
	go build -o bin/controller main.go

.PHONY: run
run: fmt vet ## Run controller from your host.
	go run ./main.go

# If you wish built the controller image targeting other platforms you can use the --platform flag.
# (i.e. docker build --platform linux/arm64 ). However, you must enable docker buildKit for it.
# More info: https://docs.docker.com/develop/develop-kit/buildkit/
# ----------------------------------------------------------------------------------
# Create the docker-container for controller-manager if the dockerfile is available
.PHONY: docker-build
docker-build: ## Build docker image with the controller.
	docker build -t ${IMG} .

.PHONY: docker-push
docker-push: ## Push docker image with the controller.
	docker push ${IMG}

# PLATFORMS defines the target platforms for  the controller image be build to provide support to multiple architectures. (i.e. make docker-buildx IMG=myregistry/mypoperator:0.0.1). To use this option you need to:
# - able to use docker buildx . More info: https://docs.docker.com/develop/develop-kit/buildkit/
# - have enable BuildKit, More info: https://docs.docker.com/develop/develop-kit/buildkit/
# - be able to push the image for your registry (i.e. if you do not inform a valid value via IMG=<myregistry/image:<tag>> then the export will fail)
# To properly provided solutions that supports more than one platform you should use this option.
PLATFORMS ?= linux/arm64,linux/amd64,linux/s390x,linux/ppc64le
.PHONY: docker-buildx
docker-buildx: ## Build and push docker image for the controller for cross-platform support
	# copy existing Dockerfile and insert --platform=${BUILDPLATFORM} into Dockerfile.cross, and preserve the original Dockerfile
	sed -e '1 s/\(^FROM\)/FROM --platform=\$$BUILDPLATFORM\n\1/' Dockerfile > Dockerfile.cross
	- docker buildx create --name project-v3-builder
	docker buildx use project-v3-builder
	- docker buildx build --push --platform=$(PLATFORMS) --tag ${IMG} -f Dockerfile.cross .
	- docker buildx rm project-v3-builder
	rm Dockerfile.cross

##@ Deployment

ifndef ignore-not-found
  ignore-not-found = false
endif

.PHONY: manifests
manifests: ## Generate WebhookConfiguration, ClusterRole and CustomResourceDefinition objects.
	controller-gen rbac:roleName=manager-role crd webhook paths="./..." output:crd:artifacts:config=config/crd/bases

.PHONY: generate
generate: ## Generate code containing DeepCopy, DeepCopyInto, and DeepCopyObject method implementations.
	controller-gen object:headerFile="hack/boilerplate.go.txt" paths="./..."

.PHONY: install-crds
install-crds: manifests ## Install CRDs into the K8s cluster specified in ~/.kube/config.
	kubectl apply -f config/crd/bases

.PHONY: uninstall-crds
uninstall-crds: manifests ## Uninstall CRDs from the K8s cluster specified in ~/.kube/config. Call with ignore-not-found=true to ignore resource not found errors during deletion.
	kubectl delete --ignore-not-found=$(ignore-not-found) -f config/crd/bases

.PHONY: install-rbac
install-rbac: ## Install RBAC resources (service account, role, role binding) into the cluster.
	kubectl apply -f config/rbac/

.PHONY: uninstall-rbac
uninstall-rbac: ## Uninstall RBAC resources. Call with ignore-not-found=true to ignore resource not found errors during deletion.
	kubectl delete --ignore-not-found=$(ignore-not-found) -f config/rbac/

.PHONY: deploy-controller
deploy-controller: ## Deploy controller deployment and service into the cluster.
	kubectl apply -f config/deployment.yaml
	kubectl apply -f config/service.yaml

.PHONY: undeploy-controller
undeploy-controller: ## Undeploy controller deployment and service. Call with ignore-not-found=true to ignore resource not found errors during deletion.
	kubectl delete --ignore-not-found=$(ignore-not-found) -f config/service.yaml
	kubectl delete --ignore-not-found=$(ignore-not-found) -f config/deployment.yaml

.PHONY: install
install: manifests install-crds install-rbac ## Install CRDs and RBAC into the K8s cluster specified in ~/.kube/config.

.PHONY: uninstall
uninstall: manifests uninstall-rbac uninstall-crds ## Uninstall CRDs and RBAC from the K8s cluster specified in ~/.kube/config. Call with ignore-not-found=true to ignore resource not found errors during deletion.

.PHONY: deploy
deploy: manifests install-crds install-rbac deploy-controller ## Deploy controller to the K8s cluster specified in ~/.kube/config.

.PHONY: undeploy
undeploy: undeploy-controller uninstall-rbac uninstall-crds ## Undeploy controller from the K8s cluster specified in ~/.kube/config. Call with ignore-not-found=true to ignore resource not found errors during deletion.

.PHONY: deploy-local
deploy-local: ## Deploy using the deploy.sh script (recommended for local development).
	./deploy.sh deploy

.PHONY: cleanup-local
cleanup-local: ## Clean up using the cleanup.sh script (recommended for local development).
	./cleanup.sh all

.PHONY: status
status: ## Show deployment status.
	./deploy.sh status

.PHONY: wait-ready
wait-ready: ## Wait for controller deployment to be ready.
	@kubectl rollout status deployment/controller -n controller-system --timeout=300s || exit 1

.PHONY: logs
logs: ## Show controller logs.
	kubectl logs -f deployment/controller -n controller-system

.PHONY: restart
restart: ## Restart the controller deployment.
	kubectl rollout restart deployment/controller -n controller-system

##@ Tools

.PHONY: controller-gen
controller-gen: ## Download controller-gen locally if necessary.
	$(call go-get-tool,$(shell go env GOPATH)/bin/controller-gen,github.com/kubernetes-sigs/controller-tools/cmd/controller-gen@v0.14.0)

.PHONY: kustomize
kustomize: ## Download kustomize locally if necessary.
	$(call go-get-tool,$(shell go env GOPATH)/bin/kustomize,github.com/kubernetes-sigs/kustomize/kustomize/v5@v5.3.0)

# go-get-tool will 'go get' any package $2 and install it to $1.
PROJECT_DIR := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
define go-get-tool
@[ -f $(1) ] || { \
set -e ;\
TMP_DIR=$$(mktemp -d) ;\
cd $$TMP_DIR ;\
go mod init tmp ;\
echo 'Downloading $(2)' ;\
GOBIN=$(shell go env GOPATH)/bin go install $(2) ;\
rm -rf $$TMP_DIR ;\
}
endef