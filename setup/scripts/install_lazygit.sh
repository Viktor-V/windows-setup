#!/bin/bash
set -e

echo "Installing lazygit..."

LAZYGIT_VERSION=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep '"tag_name"' | sed 's/.*"\([^"]*\)".*/\1/')
curl -L "https://github.com/jesseduffield/lazygit/releases/download/${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION#v}_Linux_64-bit.tar.gz" -o /tmp/lazygit.tar.gz
tar -xzf /tmp/lazygit.tar.gz -C /tmp/lazygit
cp /tmp/lazygit/lazygit /usr/local/bin/lazygit
rm -f /tmp/lazygit.tar.gz
rm -rf /tmp/lazygit

echo "lazygit installed: $(lazygit --version 2>/dev/null || echo 'checking...')"