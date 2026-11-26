#!/bin/bash
set -e

echo "Installing lazygit..."

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) LAZYGIT_ARCH="x86_64" ;;
    aarch64) LAZYGIT_ARCH="arm64" ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

LAZYGIT_VERSION="v0.66.3"
LAZYGIT_VER="${LAZYGIT_VERSION#v}"

ASSET="lazygit_${LAZYGIT_VER}_linux_${LAZYGIT_ARCH}.tar.gz"
URL="https://github.com/jesseduffield/lazygit/releases/download/${LAZYGIT_VERSION}"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

curl -fL "${URL}/${ASSET}" -o "$tmpdir/$ASSET"
curl -fsSL "${URL}/checksums.txt" -o "$tmpdir/checksums.txt"
grep "  ${ASSET}$" "$tmpdir/checksums.txt" > "$tmpdir/$ASSET.sha256"
(cd "$tmpdir" && sha256sum -c "$ASSET.sha256")

tar -xzf "$tmpdir/$ASSET" -C "$tmpdir"
install -m 755 "$tmpdir/lazygit" /usr/local/bin/lazygit

echo "lazygit installed: $(lazygit --version 2>/dev/null || echo 'version unknown')"
