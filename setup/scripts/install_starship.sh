#!/bin/bash
set -e

echo "Installing Starship prompt..."

# Download and install Starship
STARSHIP_VERSION=$(curl -s https://github.com/starship/starship/releases/latest | grep '"tag_name"' | sed 's/.*"\([^"]*\)".*/\1/')

curl -L "https://github.com/starship/starship/releases/download/${STARSHIP_VERSION}/starship-linux-amd64.tar.gz" -o /tmp/starship.tar.gz
tar -xzf /tmp/starship.tar.gz -C /usr/local/bin
chmod +x /usr/local/bin/starship
rm -f /tmp/starship.tar.gz

echo "Starship installed: $(starship --version)"
