#!/bin/bash
set -e

echo "Installing Yazi file manager..."

# Download and install Yazi from GitHub releases
YAZI_VERSION=$(curl -s https://api.github.com/repos/sxyazi/yazi/releases/latest | grep '"tag_name"' | sed 's/.*"\([^"]*\)".*/\1/')

curl -L "https://github.com/sxyazi/yazi/releases/download/${YAZI_VERSION}/yazi-x86_64-unknown-linux-gnu.tar.gz" -o /tmp/yazi.tar.gz
tar -xzf /tmp/yazi.tar.gz -C /usr/local/bin
chmod +x /usr/local/bin/yazi
rm -f /tmp/yazi.tar.gz

# Install yaegi (Yazi's scripting engine)
curl -L "https://github.com/sxyazi/yazi/releases/download/${YAZI_VERSION}/yaegi-x86_64-unknown-linux-gnu.tar.gz" -o /tmp/yaegi.tar.gz
tar -xzf /tmp/yaegi.tar.gz -C /usr/local/bin
chmod +x /usr/local/bin/yaegi
rm -f /tmp/yaegi.tar.gz

# Install ffmpeg for image preview support
if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "Installing ffmpeg for image preview support..."
    apt-get install -y ffmpeg
fi

# Create Yazi config directory
mkdir -p ~/.config/yazi

# Install file preview support libraries
echo "Installing file preview dependencies..."
apt-get install -y ffmpeg poppler-utils

echo "Yazi installed successfully"
