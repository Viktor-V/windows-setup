#!/bin/bash
set -e

echo "Installing atuin..."

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ATUIN_ARCH="x86_64" ;;
    aarch64) ATUIN_ARCH="aarch64" ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

ATUIN_VERSION=$(curl -fsSL https://api.github.com/repos/atuinsh/atuin/releases/latest | grep '"tag_name"' | sed 's/.*"\([^"]*\)".*/\1/')

ASSET="atuin-${ATUIN_ARCH}-unknown-linux-gnu.tar.gz"
curl -fL "https://github.com/atuinsh/atuin/releases/download/${ATUIN_VERSION}/${ASSET}" -o /tmp/atuin.tar.gz

tar -xzf /tmp/atuin.tar.gz -C /tmp
install -m 755 "/tmp/atuin-${ATUIN_ARCH}-unknown-linux-gnu/atuin" /usr/local/bin/atuin
rm -f /tmp/atuin.tar.gz
rm -rf "/tmp/atuin-${ATUIN_ARCH}-unknown-linux-gnu"

echo "Atuin installed: $(atuin --version 2>/dev/null || echo 'checking...')"
