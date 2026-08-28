#!/bin/bash
set -e

echo "Downloading Zellij..."
URL=$(curl -s https://api.github.com/repos/zellij-org/zellij/releases/latest | \
      grep -o '"browser_download_url": *"[^"]*"' | \
      grep 'x86_64-unknown-linux-musl.tar.gz' | \
      head -1 | \
      cut -d '"' -f 4)

curl -L "$URL" -o /tmp/zellij.tar.gz
tar -xzf /tmp/zellij.tar.gz -C /usr/local/bin
chmod +x /usr/local/bin/zellij
rm -f /tmp/zellij.tar.gz

echo "Zellij installed: $(zellij --version)"