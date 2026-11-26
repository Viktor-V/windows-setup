#!/bin/bash
set -e

echo "Installing dblab database client..."

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) DBLAB_ARCH="amd64" ;;
    aarch64) DBLAB_ARCH="arm64" ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

DBLAB_VERSION="v0.55.2"
DBLAB_VER="${DBLAB_VERSION#v}"

ASSET="dblab_${DBLAB_VER}_linux_${DBLAB_ARCH}.tar.gz"
URL="https://github.com/danvergara/dblab/releases/download/${DBLAB_VERSION}"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

curl -fL "${URL}/${ASSET}" -o "$tmpdir/$ASSET"
curl -fsSL "${URL}/checksums.txt" -o "$tmpdir/checksums.txt"
grep "  ${ASSET}$" "$tmpdir/checksums.txt" > "$tmpdir/$ASSET.sha256"
(cd "$tmpdir" && sha256sum -c "$ASSET.sha256")

tar -xzf "$tmpdir/$ASSET" -C "$tmpdir"
install -m 755 "$tmpdir/dblab" /usr/local/bin/dblab

echo "dblab installed: $(dblab --version 2>/dev/null || echo 'version unknown')"
