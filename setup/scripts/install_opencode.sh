#!/bin/bash
set -e

echo "Installing OpenCode CLI..."

apt-get update
apt-get install -y gnupg ca-certificates

curl -fsSL https://apt.opencode.ai/gpg | gpg --dearmor -o /usr/share/keyrings/opencode-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/opencode-archive-keyring.gpg] https://apt.opencode.ai/debian stable main" | tee /etc/apt/sources.list.d/opencode.list > /dev/null

apt-get update
apt-get install -y opencode

echo "OpenCode CLI installed: $(opencode --version 2>/dev/null || echo 'version unknown')"
