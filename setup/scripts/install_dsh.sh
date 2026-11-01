#!/bin/bash
set -e

echo "Installing DeepSeek Harness CLI..."

npm install -g @deepseek-ai/dsh \
    --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs

echo "dsh installed: $(dsh --version 2>/dev/null || echo 'version unknown')"
