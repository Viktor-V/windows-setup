#!/bin/bash
set -e

USER_NAME="${1:-viktorv}"

if ! id "$USER_NAME" >/dev/null 2>&1; then
    echo "User '$USER_NAME' does not exist."
    exit 1
fi

mkdir -p /root/.config/fish
mkdir -p "/home/$USER_NAME/.config/fish"

cat > /root/.config/fish/config.fish <<'EOF'
if type -q starship
    starship init fish | source
end
EOF

cp /root/.config/fish/config.fish \
   "/home/$USER_NAME/.config/fish/config.fish"

chown -R "$USER_NAME:$USER_NAME" "/home/$USER_NAME/.config"

echo "Fish configured for $USER_NAME"