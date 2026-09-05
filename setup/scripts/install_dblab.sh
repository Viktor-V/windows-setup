#!/bin/bash
set -e

echo "Installing dblab database client..."

DBLAB_VERSION=$(curl -s https://api.github.com/repos/ivarcarrinst/dblab/releases/latest | grep '"tag_name"' | sed 's/.*"\([^"]*\)".*/\1/')

curl -L "https://github.com/ivarcarrinst/dblab/releases/download/${DBLAB_VERSION}/dblab-linux-amd64" -o /usr/local/bin/dblab
chmod +x /usr/local/bin/dblab

echo "dblab installed: $(dblab --version 2>/dev/null || echo 'version unknown')"
