#!/bin/bash
set -e

echo "Installing Starship prompt..."

# Download and install Starship
STARSHIP_VERSION=$(curl -fsSL https://api.github.com/repos/starship/starship/releases/latest | grep '"tag_name"' | sed 's/.*"\([^"]*\)".*/\1/')

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) STARSHIP_ARCH="x86_64" ;;
    aarch64) STARSHIP_ARCH="aarch64" ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

ASSET="starship-${STARSHIP_ARCH}-unknown-linux-gnu.tar.gz"
curl -fL "https://github.com/starship/starship/releases/download/${STARSHIP_VERSION}/${ASSET}" -o /tmp/starship.tar.gz
tar -xzf /tmp/starship.tar.gz -C /usr/local/bin
chmod +x /usr/local/bin/starship
rm -f /tmp/starship.tar.gz

echo "Starship installed: $(starship --version)"
