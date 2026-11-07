#!/bin/bash
set -e

if ! command -v tailscale >/dev/null 2>&1; then
    echo "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
fi

systemctl enable --now tailscaled

status="$(tailscale status 2>/dev/null || true)"
if printf '%s' "$status" | grep -q 'Logged out'; then
    if [ -n "${TAILSCALE_AUTHKEY:-}" ]; then
        echo "Joining Tailscale with the provided auth key..."
        tailscale up --auth-key="$TAILSCALE_AUTHKEY"
    else
        echo "Tailscale is installed but not logged in."
        echo "Run: sudo tailscale up"
        echo "Then open the printed URL and sign in with your Tailscale account."
    fi
else
    echo "Tailscale is already logged in."
    tailscale ip -4 2>/dev/null || true
fi
