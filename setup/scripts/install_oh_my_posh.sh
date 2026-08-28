#!/bin/bash
set -e

echo "Installing Oh My Posh..."

if ! command -v oh-my-posh >/dev/null 2>&1; then
    curl -s https://ohmyposh.dev/install.sh | bash -s -- -d /usr/local/bin
fi

echo "Oh My Posh: $(oh-my-posh version)"