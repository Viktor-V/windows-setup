#!/bin/bash
set -e

echo "Installing dblab database client..."

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) DBLAB_ARCH="amd64" ;;
    aarch64) DBLAB_ARCH="arm64" ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

DBLAB_VERSION=$(curl -s https://api.github.com/repos/ivarcarrinst/dblab/releases/latest | grep '"tag_name"' | sed 's/.*"\([^"]*\)".*/\1/')
curl -L "https://github.com/ivarcarrinst/dblab/releases/download/${DBLAB_VERSION}/dblab-linux-${DBLAB_ARCH}" -o /usr/local/bin/dblab
chmod +x /usr/local/bin/dblab

echo "dblab installed: $(dblab --version 2>/dev/null || echo 'version unknown')"
