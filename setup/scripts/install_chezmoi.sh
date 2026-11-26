#!/bin/bash
set -e

echo "Installing chezmoi..."

CHEZMOI_VERSION="v2.74.2"
CHEZMOI_VER="${CHEZMOI_VERSION#v}"

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) CHEZMOI_ARCH="amd64" ;;
    aarch64) CHEZMOI_ARCH="arm64" ;;
    *)
        echo "Unsupported architecture: $ARCH" >&2
        exit 1
        ;;
esac

ASSET="chezmoi_${CHEZMOI_VER}_linux_${CHEZMOI_ARCH}.tar.gz"
URL="https://github.com/twpayne/chezmoi/releases/download/${CHEZMOI_VERSION}"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

curl -fL "${URL}/${ASSET}" -o "$tmpdir/$ASSET"
curl -fsSL "${URL}/chezmoi_${CHEZMOI_VER}_checksums.txt" -o "$tmpdir/checksums.txt"
grep "  ${ASSET}$" "$tmpdir/checksums.txt" > "$tmpdir/$ASSET.sha256"
(cd "$tmpdir" && sha256sum -c "$ASSET.sha256")

tar -xzf "$tmpdir/$ASSET" -C "$tmpdir"
install -m 755 "$tmpdir/chezmoi" /usr/local/bin/chezmoi

if ! command -v chezmoi >/dev/null 2>&1; then
    echo "chezmoi installation failed." >&2
    exit 1
fi

echo "chezmoi installed: $(chezmoi --version 2>/dev/null || echo 'checking...')"
