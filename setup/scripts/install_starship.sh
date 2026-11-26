#!/bin/bash
set -e

echo "Installing Starship prompt..."

STARSHIP_VERSION="v1.27.0"

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) STARSHIP_ARCH="x86_64" ;;
    aarch64) STARSHIP_ARCH="aarch64" ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

ASSET="starship-${STARSHIP_ARCH}-unknown-linux-gnu.tar.gz"
URL="https://github.com/starship/starship/releases/download/${STARSHIP_VERSION}/${ASSET}"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

curl -fL "$URL" -o "$tmpdir/$ASSET"
curl -fsSL "${URL}.sha256" -o "$tmpdir/$ASSET.sha256"
expected=$(tr -d '[:space:]' < "$tmpdir/$ASSET.sha256")
actual=$(sha256sum "$tmpdir/$ASSET" | awk '{print $1}')
if [ "$expected" != "$actual" ]; then
    echo "Starship checksum mismatch." >&2
    exit 1
fi

tar -xzf "$tmpdir/$ASSET" -C /usr/local/bin
chmod +x /usr/local/bin/starship

echo "Starship installed: $(starship --version)"
