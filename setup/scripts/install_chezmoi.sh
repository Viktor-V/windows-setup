#!/bin/bash
set -e

echo "Installing chezmoi..."

# Install chezmoi using the official installer
curl -sfL https://get.chezmoi.io | sh

echo "chezmoi installed: $(chezmoi --version 2>/dev/null || echo 'checking...')"