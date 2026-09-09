#!/bin/bash
set -e

echo "Installing chezmoi..."

# Install chezmoi to a system-wide location using the official installer
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b /usr/local/bin

echo "chezmoi installed: $(chezmoi --version 2>/dev/null || echo 'checking...')"
