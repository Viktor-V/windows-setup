#!/bin/bash
set -e

echo "Installing lazygit..."

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) LAZYGIT_ARCH="x86_64" ;;
    aarch64) LAZYGIT_ARCH="arm64" ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

LAZYGIT_VERSION=$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep '"tag_name"' | sed 's/.*"\([^"]*\)".*/\1/')
LAZYGIT_VER="${LAZYGIT_VERSION#v}"

ASSET="lazygit_${LAZYGIT_VER}_linux_${LAZYGIT_ARCH}.tar.gz"
curl -fL "https://github.com/jesseduffield/lazygit/releases/download/${LAZYGIT_VERSION}/${ASSET}" -o /tmp/lazygit.tar.gz

mkdir -p /tmp/lazygit
tar -xzf /tmp/lazygit.tar.gz -C /tmp/lazygit
install -m 755 /tmp/lazygit/lazygit /usr/local/bin/lazygit
rm -f /tmp/lazygit.tar.gz
rm -rf /tmp/lazygit

echo "lazygit installed: $(lazygit --version 2>/dev/null || echo 'version unknown')"
