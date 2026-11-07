#!/bin/bash
set -e

USER_NAME="${USER_NAME:-${1:-user}}"
USER_HOME="/home/$USER_NAME"

echo "Installing OpenSSH server and Mosh..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server mosh locales

sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

cat > /usr/local/bin/herdr-ssh-shell <<'EOF'
#!/bin/bash
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
if [ -n "${SSH_ORIGINAL_COMMAND:-}" ]; then
    exec /bin/bash -c "$SSH_ORIGINAL_COMMAND"
else
    exec /usr/bin/fish -l
fi
EOF
chmod 755 /usr/local/bin/herdr-ssh-shell

cat > /etc/ssh/sshd_config.d/99-herdr.conf <<EOF
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AllowUsers $USER_NAME
ForceCommand /usr/local/bin/herdr-ssh-shell
EOF

install -d -m 700 -o "$USER_NAME" -g "$USER_NAME" "$USER_HOME/.ssh"

if [ -n "${SSH_PUBKEY:-}" ]; then
    printf '%s\n' "$SSH_PUBKEY" >> "$USER_HOME/.ssh/authorized_keys"
    chown "$USER_NAME:$USER_NAME" "$USER_HOME/.ssh/authorized_keys"
    chmod 600 "$USER_HOME/.ssh/authorized_keys"
fi

sshd -t
systemctl enable ssh
systemctl reload ssh 2>/dev/null || systemctl restart ssh

if command -v loginctl >/dev/null 2>&1; then
    loginctl enable-linger "$USER_NAME" 2>/dev/null || true
fi

echo "OpenSSH server is enabled."
echo "Add the phone public key to $USER_HOME/.ssh/authorized_keys if it is not there yet."
