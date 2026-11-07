#!/bin/bash
set -e

USER_NAME="${USER_NAME:-${1:-user}}"
USER_HOME="/home/$USER_NAME"
OPENCODE_BIN="$USER_HOME/.opencode/bin/opencode"

if [ -x "$OPENCODE_BIN" ]; then
    echo "OpenCode already installed: $("$OPENCODE_BIN" --version 2>/dev/null || echo 'version unknown')"
    exit 0
fi

echo "Installing OpenCode for $USER_NAME..."
sudo -H -u "$USER_NAME" bash -c 'curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path'

echo "OpenCode installed: $("$OPENCODE_BIN" --version 2>/dev/null || echo 'version unknown')"
