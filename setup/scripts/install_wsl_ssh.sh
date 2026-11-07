#!/bin/bash
set -e

USER_NAME="${USER_NAME:-${1:-user}}"
USER_HOME="/home/$USER_NAME"

echo "Installing OpenSSH server..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server

cat > /etc/ssh/sshd_config.d/99-herdr.conf <<EOF
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AllowUsers $USER_NAME
EOF

install -d -m 700 -o "$USER_NAME" -g "$USER_NAME" "$USER_HOME/.ssh"

if [ -n "${SSH_PUBKEY:-}" ]; then
    printf '%s\n' "$SSH_PUBKEY" >> "$USER_HOME/.ssh/authorized_keys"
    chown "$USER_NAME:$USER_NAME" "$USER_HOME/.ssh/authorized_keys"
    chmod 600 "$USER_HOME/.ssh/authorized_keys"
fi

sshd -t
systemctl enable --now ssh
echo "OpenSSH server is enabled."
echo "Add the phone public key to $USER_HOME/.ssh/authorized_keys if it is not there yet."
