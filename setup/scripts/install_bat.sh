#!/bin/bash
set -e

echo "Installing bat..."

apt-get update
apt-get install -y bat

echo "bat installed: $(bat --version 2>/dev/null || echo 'checking...')"