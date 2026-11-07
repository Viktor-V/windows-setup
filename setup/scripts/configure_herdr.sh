#!/bin/bash
set -e

USER_NAME="${USER_NAME:-${1:-user}}"
USER_HOME="/home/$USER_NAME"
HERDR_BIN="$USER_HOME/.local/bin/herdr"

echo "Installing OpenCode integration for Herdr..."
sudo -H -u "$USER_NAME" "$HERDR_BIN" integration install opencode

echo "Creating project directories..."
sudo -H -u "$USER_NAME" mkdir -p \
    "$USER_HOME/projects/development" \
    "$USER_HOME/projects/translation" \
    "$USER_HOME/projects/common"

echo "Installing Herdr systemd service..."
cat > /etc/systemd/system/herdr.service <<EOF
[Unit]
Description=Herdr persistent server
After=network.target

[Service]
Type=simple
User=$USER_NAME
Environment=HOME=$USER_HOME
Environment=USER=$USER_NAME
Environment=LOGNAME=$USER_NAME
Environment=PATH=$USER_HOME/.local/bin:/usr/local/bin:/usr/bin:/bin
WorkingDirectory=$USER_HOME
ExecStart=$HERDR_BIN server
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

mkdir -p /etc/systemd/system/multi-user.target.wants

if command -v systemctl >/dev/null 2>&1 && systemctl is-system-running >/dev/null 2>&1; then
    systemctl daemon-reload
    systemctl enable herdr.service
    systemctl restart herdr.service
else
    ln -sf /etc/systemd/system/herdr.service /etc/systemd/system/multi-user.target.wants/herdr.service
fi

echo "Herdr configured for $USER_NAME"
