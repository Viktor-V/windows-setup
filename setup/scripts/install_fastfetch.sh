#!/bin/bash
set -e

echo "Installing fastfetch..."

apt-get update
apt-get install -y fastfetch

echo "fastfetch installed: $(fastfetch --version 2>/dev/null || echo 'checking...')"