#!/bin/bash
set -e

USER_NAME="${USER_NAME:-${1:-user}}"

echo "Installing pnpm..."
npm install -g pnpm@11 >/dev/null

echo "Installing DeepSeek Harness TUI plugin for $USER_NAME..."
sudo -u "$USER_NAME" dsh plugin --profile dsh-tui add @deepseek-harness-tui/dsh-tui@0.18.0

echo "dsh-tui installed."
