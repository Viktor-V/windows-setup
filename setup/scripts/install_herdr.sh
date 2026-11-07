#!/bin/bash
set -e

USER_NAME="${USER_NAME:-${1:-user}}"
USER_HOME="/home/$USER_NAME"
HERDR_BIN="$USER_HOME/.local/bin/herdr"

if [ -x "$HERDR_BIN" ]; then
    echo "Herdr already installed: $("$HERDR_BIN" --version 2>/dev/null || echo 'version unknown')"
    exit 0
fi

echo "Installing Herdr for $USER_NAME..."
sudo -H -u "$USER_NAME" sh -c 'curl -fsSL https://herdr.dev/install.sh | sh'

echo "Herdr installed: $(sudo -H -u "$USER_NAME" "$HERDR_BIN" --version 2>/dev/null || echo 'version unknown')"
