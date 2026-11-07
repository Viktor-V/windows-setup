#!/bin/bash
set -e

if tailscale status 2>/dev/null | grep -q 'Logged out'; then
    echo "Open this URL to log in to Tailscale:"
    nohup tailscale up > /tmp/tailscale-up.log 2>&1 &
    for _ in $(seq 1 20); do
        if [ -s /tmp/tailscale-up.log ]; then
            break
        fi
        sleep 1
    done
    cat /tmp/tailscale-up.log

    echo "Waiting for Tailscale login (up to 4 minutes)..."
    for _ in $(seq 1 120); do
        if ! tailscale status 2>/dev/null | grep -q 'Logged out'; then
            echo "Tailscale is logged in:"
            tailscale ip -4
            exit 0
        fi
        sleep 2
    done
    echo "Tailscale login timed out. Run 'sudo tailscale up' later."
else
    echo "Tailscale is already logged in:"
    tailscale ip -4
fi
