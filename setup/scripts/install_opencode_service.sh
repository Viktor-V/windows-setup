#!/bin/bash
set -euo pipefail

USER_NAME="${USER_NAME:-user}"
USER_HOME="/home/$USER_NAME"
OPENCODE="$USER_HOME/.opencode/bin/opencode"
UNIT_PATH="/etc/systemd/system/opencode.service"
SERVICE_CONFIG="$USER_HOME/.config/opencode/service.json"

if ! id "$USER_NAME" >/dev/null 2>&1; then
    echo "User $USER_NAME does not exist." >&2
    exit 1
fi

if [ ! -x "$OPENCODE" ]; then
    echo "OpenCode binary not found at $OPENCODE." >&2
    exit 1
fi

if [ ! -f "$SERVICE_CONFIG" ]; then
    echo "OpenCode service config not found at $SERVICE_CONFIG." >&2
    exit 1
fi

cat > "$UNIT_PATH" <<EOF
[Unit]
Description=OpenCode shared server (WSL)
Wants=network-online.target
After=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=$USER_NAME
Group=$USER_NAME
Environment=HOME=$USER_HOME
Environment=XDG_CONFIG_HOME=$USER_HOME/.config
Environment=XDG_CACHE_HOME=$USER_HOME/.cache
Environment=XDG_DATA_HOME=$USER_HOME/.local/share
WorkingDirectory=$USER_HOME
ExecStart=$OPENCODE serve --service --hostname 0.0.0.0 --port 4096
Restart=always
RestartSec=5
KillMode=control-group
TimeoutStopSec=15
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Stop any unmanaged instance left by the provisioning phase before systemd
# takes ownership of the server.
sudo -H -u "$USER_NAME" "$OPENCODE" service stop >/dev/null 2>&1 || true

systemctl daemon-reload
systemctl enable --now opencode.service

echo "OpenCode systemd unit installed and started."
