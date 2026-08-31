#!/bin/bash
set -e

echo "Installing dblab database client..."

# Install Go dependencies if needed (dblab is a Go application)
if ! command -v go >/dev/null 2>&1; then
    echo "Installing Go for dblab build..."
    apt-get install -y golang-go
fi

# Install dblab via Go (this is the most reliable method)
echo "Building and installing dblab..."
go install github.com/ivarcarrinst/dblab@latest

# Ensure the Go bin directory is in PATH and create a symlink
GO_BIN_PATH=$(go env GOPATH)/bin
if [ -f "${GO_BIN_PATH}/dblab" ]; then
    ln -sf "${GO_BIN_PATH}/dblab" /usr/local/bin/dblab
else
    echo "ERROR: dblab binary not found at ${GO_BIN_PATH}/dblab"
    exit 1
fi

echo "dblab installed: $(dblab --version)"
