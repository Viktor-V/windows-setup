#!/bin/bash
set -e

USER_NAME="${USER_NAME:-${1:-user}}"
USER_HOME="/home/$USER_NAME"
OPENCODE_BIN="$USER_HOME/.opencode/bin/opencode"

if [ -x "$OPENCODE_BIN" ]; then
    current_version=$("$OPENCODE_BIN" --version 2>/dev/null || true)
    case "$current_version" in
        2.*)
            echo "OpenCode already installed: $current_version"
            exit 0
            ;;
        *)
            echo "Replacing existing OpenCode ($current_version) with OpenCode 2..."
            ;;
    esac
fi

echo "Installing OpenCode for $USER_NAME..."
sudo -H -u "$USER_NAME" bash -o pipefail -c 'curl -fsSL https://opencode.ai/v2/install | bash -s -- --no-modify-path'

if [ ! -x "$OPENCODE_BIN" ]; then
    echo "OpenCode installation failed: $OPENCODE_BIN was not created." >&2
    exit 1
fi

echo "OpenCode installed: $("$OPENCODE_BIN" --version 2>/dev/null || echo 'version unknown')"
