#!/bin/bash
set -e

USER_NAME="${USER_NAME:-${1:-user}}"
USER_HOME="/home/$USER_NAME"
HERDR_BIN="$USER_HOME/.local/bin/herdr"

if command -v systemctl >/dev/null 2>&1; then
    systemctl start herdr.service >/dev/null 2>&1 || true
fi

echo "Waiting for Herdr server..."
for i in $(seq 1 30); do
    if sudo -H -u "$USER_NAME" "$HERDR_BIN" status 2>/dev/null | grep -q 'status: running'; then
        break
    fi
    sleep 1
done

if ! sudo -H -u "$USER_NAME" "$HERDR_BIN" status 2>/dev/null | grep -q 'status: running'; then
    echo "Herdr server is not running; workspaces were not created."
    exit 0
fi

create_workspace() {
    label="$1"
    cwd="$2"
    if sudo -H -u "$USER_NAME" "$HERDR_BIN" workspace list 2>/dev/null | grep -Fq "\"label\":\"$label\""; then
        return 0
    fi
    sudo -H -u "$USER_NAME" "$HERDR_BIN" workspace create --label "$label" --cwd "$cwd" --no-focus >/dev/null
}

sudo -H -u "$USER_NAME" mkdir -p \
    "$USER_HOME/projects/development" \
    "$USER_HOME/projects/translation" \
    "$USER_HOME/projects/common"

create_workspace Development "$USER_HOME/projects/development"
create_workspace Translation "$USER_HOME/projects/translation"
create_workspace Common "$USER_HOME/projects/common"

echo "Herdr workspaces are ready."
