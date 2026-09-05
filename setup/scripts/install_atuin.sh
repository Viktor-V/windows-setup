#!/bin/bash
set -e

echo "Installing atuin..."

# Install atuin using the official installer
bash <(curl https://raw.githubusercontent.com/atuinsh/atuin/main/install.sh) --yes

echo "Atuin installed: $(atuin --version 2>/dev/null || echo 'checking...')"