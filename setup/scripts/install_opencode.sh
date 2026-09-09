#!/bin/bash
set -e

echo "Installing OpenCode CLI..."

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) OPENCODE_ARCH="x64" ;;
    aarch64) OPENCODE_ARCH="arm64" ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

OPENCODE_VERSION=$(curl -fsSL https://api.github.com/repos/anomalyco/opencode/releases/latest | grep '"tag_name"' | sed 's/.*"\([^"]*\)".*/\1/')

ASSET="opencode-linux-${OPENCODE_ARCH}.tar.gz"
curl -fL "https://github.com/anomalyco/opencode/releases/download/${OPENCODE_VERSION}/${ASSET}" -o /tmp/opencode.tar.gz

tar -xzf /tmp/opencode.tar.gz -C /tmp
install -m 755 /tmp/opencode /usr/local/bin/opencode
rm -f /tmp/opencode.tar.gz /tmp/opencode

echo "OpenCode CLI installed: $(opencode --version 2>/dev/null || echo 'version unknown')"
