# SPDX-FileCopyrightText: 2025 SAP SE or an SAP affiliate company
# SPDX-License-Identifier: Apache-2.0

FROM golang:1.24.3-alpine3.21 AS builder

# Install required dependencies
RUN apk add --no-cache --no-progress \
    ca-certificates \
    gcc \
    git \
    make \
    musl-dev

WORKDIR /src

# Copy go.mod first to leverage Docker layer caching
COPY go.mod go.sum ./

# Configure GOTOOLCHAIN=auto to allow automatic download of Go 1.24
ENV GOTOOLCHAIN=auto
RUN go mod download

COPY . .

# Build with optimized flags for static binary
ARG BININFO_BUILD_DATE BININFO_COMMIT_HASH BININFO_VERSION
RUN CGO_ENABLED=0 \
    GOOS=linux \
    go build -a \
    -ldflags "-w -s -extldflags '-static' \
              -X main.buildDate=${BININFO_BUILD_DATE} \
              -X main.commitHash=${BININFO_COMMIT_HASH} \
              -X main.version=${BININFO_VERSION}" \
    -o /kubernetes-oomkill-exporter .

# Final stage using distroless base image
FROM gcr.io/distroless/static-debian12

# Copy SSL certificates and binary from builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /kubernetes-oomkill-exporter /usr/bin/kubernetes-oomkill-exporter

# Verify binary works
RUN ["/usr/bin/kubernetes-oomkill-exporter", "--version"]

# Image metadata
ARG BININFO_BUILD_DATE BININFO_COMMIT_HASH BININFO_VERSION
LABEL source_repository="https://github.com/sapcc/kubernetes-oomkill-exporter" \
    org.opencontainers.image.url="https://github.com/sapcc/kubernetes-oomkill-exporter" \
    org.opencontainers.image.created=${BININFO_BUILD_DATE} \
    org.opencontainers.image.revision=${BININFO_COMMIT_HASH} \
    org.opencontainers.image.version=${BININFO_VERSION}
WORKDIR /
ENTRYPOINT ["/usr/bin/kubernetes-oomkill-exporter"]
