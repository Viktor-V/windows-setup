#!/bin/bash
set -e

echo "Installing Yazi file manager..."

# Download and install Yazi from GitHub releases (.deb for Debian)
YAZI_VERSION=$(curl -fsSL https://api.github.com/repos/sxyazi/yazi/releases/latest | grep '"tag_name"' | sed 's/.*"\([^"]*\)".*/\1/')

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) YAZI_ARCH="x86_64" ;;
    aarch64) YAZI_ARCH="aarch64" ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

DEB="yazi-${YAZI_ARCH}-unknown-linux-gnu.deb"
curl -fL "https://github.com/sxyazi/yazi/releases/download/${YAZI_VERSION}/${DEB}" -o "/tmp/${DEB}"

apt-get install -y "/tmp/${DEB}"
rm -f "/tmp/${DEB}"

# Install ffmpeg for image preview support
if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "Installing ffmpeg for image preview support..."
    apt-get install -y ffmpeg
fi

# Create Yazi config directory for the real user
USER_NAME="${USER_NAME:-${1:-user}}"
mkdir -p "/home/$USER_NAME/.config/yazi"
chown -R "$USER_NAME:$USER_NAME" "/home/$USER_NAME/.config/yazi"

# Install file preview support libraries
echo "Installing file preview dependencies..."
apt-get install -y ffmpeg poppler-utils

echo "Yazi installed successfully"
