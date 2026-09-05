#!/bin/bash
set -e

echo "Installing zoxide..."

apt-get update
apt-get install -y zoxide

echo "zoxide installed: $(zoxide --version 2>/dev/null || echo 'checking...')"