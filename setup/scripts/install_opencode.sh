#!/bin/bash
set -e

echo "Installing OpenCode CLI..."

curl -fsSL https://opencode.ai/install | bash

echo "OpenCode CLI installed: $(opencode --version 2>/dev/null || echo 'version unknown')"
