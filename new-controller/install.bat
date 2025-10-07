C:/Program Files/Go/bin/go install sigs.k8s.io/controller-tools/cmd/controller-gen@latest
set PATH=C:/Program Files/Go/bin;%%PATH%%
controller-gen object paths="./api/..."
