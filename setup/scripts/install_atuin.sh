#!/bin/bash
set -e

echo "Installing atuin..."

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ATUIN_ARCH="x86_64" ;;
    aarch64) ATUIN_ARCH="aarch64" ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

ATUIN_VERSION="v18.25.1"

ASSET="atuin-${ATUIN_ARCH}-unknown-linux-gnu.tar.gz"
URL="https://github.com/atuinsh/atuin/releases/download/${ATUIN_VERSION}/${ASSET}"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

curl -fL "$URL" -o "$tmpdir/$ASSET"
curl -fsSL "${URL}.sha256" -o "$tmpdir/$ASSET.sha256"
(cd "$tmpdir" && sha256sum -c "$ASSET.sha256")

tar -xzf "$tmpdir/$ASSET" -C "$tmpdir"
install -m 755 "$tmpdir/atuin-${ATUIN_ARCH}-unknown-linux-gnu/atuin" /usr/local/bin/atuin

echo "Atuin installed: $(atuin --version 2>/dev/null || echo 'checking...')"
