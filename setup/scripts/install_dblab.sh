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

DBLAB_VERSION=$(curl -fsSL https://api.github.com/repos/danvergara/dblab/releases/latest | grep '"tag_name"' | sed 's/.*"\([^"]*\)".*/\1/')
DBLAB_VER="${DBLAB_VERSION#v}"

ASSET="dblab_${DBLAB_VER}_linux_${DBLAB_ARCH}.tar.gz"
curl -fL "https://github.com/danvergara/dblab/releases/download/${DBLAB_VERSION}/${ASSET}" -o /tmp/dblab.tar.gz

mkdir -p /tmp/dblab
tar -xzf /tmp/dblab.tar.gz -C /tmp/dblab
install -m 755 /tmp/dblab/dblab /usr/local/bin/dblab
rm -f /tmp/dblab.tar.gz
rm -rf /tmp/dblab

echo "dblab installed: $(dblab --version 2>/dev/null || echo 'version unknown')"
