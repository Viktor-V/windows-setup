#!/bin/bash
set -e

echo "Installing btop..."

apt-get update
apt-get install -y btop

echo "btop installed: $(btop --version 2>/dev/null || echo 'checking...')"