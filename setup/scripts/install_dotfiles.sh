#!/bin/bash
set -e

USER_NAME="${USER_NAME:-${1:-user}}"

echo "Applying dotfiles with chezmoi..."

if ! command -v chezmoi >/dev/null 2>&1; then
    echo "chezmoi not installed, skipping dotfiles."
    exit 0
fi

# Apply dotfiles as the real user so files land in /home/$USER_NAME.
sudo -u "$USER_NAME" chezmoi init --apply Viktor-V/dotfiles

echo "Dotfiles applied for $USER_NAME"
