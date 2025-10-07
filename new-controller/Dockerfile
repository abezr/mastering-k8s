# syntax=docker/dockerfile:1
FROM golang:1.21-alpine AS builder
WORKDIR /workspace

# Install git and certs for go modules
RUN apk add --no-cache git ca-certificates && update-ca-certificates

# Cache and download modules
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download

# Copy source
COPY . .

# Build statically linked binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -o manager ./main.go

# Runtime image
FROM gcr.io/distroless/static:nonroot
WORKDIR /
COPY --from=builder /workspace/manager /manager
USER 65532:65532

# Metrics and health probe ports
EXPOSE 8080
EXPOSE 8081

ENTRYPOINT ["/manager"]