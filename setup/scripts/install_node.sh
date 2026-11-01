#!/bin/bash
set -e

echo "Installing Node.js 24 (NodeSource)..."

if command -v node >/dev/null 2>&1 && [ "$(node -p 'process.versions.node.split(".")[0]')" -ge 24 ] 2>/dev/null; then
    echo "Node.js $(node --version) already installed."
    exit 0
fi

curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs

echo "Node.js installed: $(node --version) / npm $(npm --version)"
