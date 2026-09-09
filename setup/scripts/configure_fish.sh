#!/bin/bash
set -e

USER_NAME="${USER_NAME:-${1:-user}}"

mkdir -p /root/.config/fish
mkdir -p "/home/$USER_NAME/.config/fish"

cat > /root/.config/fish/config.fish <<EOF
# Fish shell configuration for $USER_NAME

# Initialize Starship prompt
if type -q starship
    starship init fish | source
end

# Initialize zoxide
if type -q zoxide
    zoxide init fish | source
end

# Initialize atuin (sync history), keep up-arrow as normal history recall
if type -q atuin
    atuin init fish --disable-up-arrow | source
end

# Set default directory
cd ~

# Useful aliases
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate --all'

# New tools aliases
alias tb='btop'
alias lg='lazygit'
alias ff='fastfetch'
alias cat='bat'
alias grep='grep --color=auto'
alias history='atuin search -i'

# Common commands
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# WSL specific
alias winhome='cd /mnt/c/Users/$USER_NAME'
alias desk='cd ~/Desktop 2>/dev/null || mkdir -p ~/Desktop && cd ~/Desktop'

# Set default editor
set -gx EDITOR nvim
set -gx VISUAL nvim

# PATH additions
fish_add_path \$HOME/.local/bin
fish_add_path /usr/local/bin
fish_add_path /usr/local/go/bin

# Enable vi mode
fish_vi_key_bindings
EOF

cp /root/.config/fish/config.fish \
   "/home/$USER_NAME/.config/fish/config.fish"

chown -R "$USER_NAME:$USER_NAME" "/home/$USER_NAME/.config"

echo "Fish configured for $USER_NAME"
