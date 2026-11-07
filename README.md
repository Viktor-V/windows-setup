# windows-setup

Automated setup script for Windows 11 development environment.

## What it does

This project can be installed on any Windows 11 machine. For best results, use a fresh installation with the bundled [`autounattend.xml`](autounattend.xml) — it pre-configures the system and automatically downloads and runs this setup on first logon.

This project automates the complete configuration of a Windows 11 machine for development purposes, consisting of two main phases:

### Phase 1: Windows Configuration
- Removes bloatware and unnecessary Windows apps
- Installs essential applications via Winget (ImageGlass, VLC, Git, etc.)
- Applies visual customizations (black theme, disabled lock screen, etc.)
- Downloads and installs **WezTerm** terminal with **JetBrains Mono Nerd Font** and adds it to autostart
- Installs **chezmoi** and applies Windows-side dotfiles (WezTerm, Flow Launcher, virtual-desktop helper)
- Creates PowerShell admin profile with auto-elevation
- Creates a `PowerShell Admin` shortcut in the Start menu (runs elevated)
- Creates WSL2 filesystem layout and configures JetBrains Mono Nerd Font system-wide

### Phase 2: WSL2 & Linux Environment
- Sets up **Debian WSL2** distribution with Fish shell
- Installs base packages: git, neovim, ripgrep, fzf, python3-pip, fish, Docker, etc.
- Installs development tools: **Starship** prompt, **dblab** TUI database client
- Configures **Fish** shell with Starship integration and useful aliases
- Installs **Herdr** and **OpenCode CLI**, enables the persistent Herdr server via systemd, and creates workspaces `Development`, `Translation`, `Common`
- Installs **Tailscale** and **OpenSSH server** inside WSL for direct SSH access from a phone
- Sets up **Docker** with Portainer container (accessible at http://localhost:9000)
- Terminates and restarts WSL2 to apply configuration

## Prerequisites
- Windows 10/11
- Administrator privileges to run setup.ps1
- Internet connection for downloading packages

## Quick Start

1. Run `setup.ps1` as Administrator:
    ```powershell
    .\setup.ps1
    ```

2. Enter username when prompted (press Enter for default: user)

3. Enter password when prompted

4. Optionally paste the phone's SSH public key and choose whether to log in to Tailscale during Phase 2

5. Confirm reboot when asked (Phase 1 requires reboot to initialize WSL2)

6. After reboot, login to Windows and the setup will automatically continue with Phase 2

7. Once complete:
   - Portainer UI at http://localhost:9000
   - Open Debian terminal to see Fish + JetBrains Mono Font
   - Login with your chosen username
   - WezTerm opens on «Консоль» and starts Herdr; run `opencode` inside a workspace and use `/connect` to add model providers

## Phone Access (Tailscale + SSH)

Remote access goes directly to the WSL Tailscale node; the Windows OpenSSH server is not used.

1. In WSL, log in to Tailscale:

   ```sh
   sudo tailscale up
   ```

   Open the printed URL and sign in with your Tailscale account. If you chose to log in during setup, this is already done.

2. Get the WSL Tailscale IP:

   ```sh
   tailscale ip -4
   ```

3. Add the phone's SSH public key:

   ```sh
   mkdir -p ~/.ssh && chmod 700 ~/.ssh
   echo 'ssh-ed25519 ...' >> ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   ```

   If you provided the key during setup, this is already done.

4. In an SSH client on the phone (Termius, WebSSH, ShellFish, a-Shell, etc.):

   - Host: the WSL Tailscale IP
   - Port: `22`
   - User: your Linux username
   - Connection type: **SSH** (not Mosh)

5. After login, run `herdr`. It attaches to the persistent session.

The WSL node must be running. WezTerm autostarts on «Консоль», launches Herdr, and keeps WSL and its systemd services up.

## Projects & Tools Installed

### Windows Applications
- 7-Zip, ImageGlass, VLC, Flow-Launcher, Git, WezTerm, chezmoi
- Downloads `VirtualDesktop.exe` for the WezTerm virtual-desktop helper (opens on the Windows desktop «Консоль»)

### Linux/WSL2 Tools
- Base: git, neovim, ripgrep, fzf, python3-pip, fish, wl-clipboard, Docker, sudo
- Prompt: Starship
- Database client: dblab
- Container management: Docker, Portainer
- Agent workspace: Herdr (persistent server + systemd service), OpenCode CLI
- Remote access: Tailscale (WSL node), OpenSSH server (WSL)
- TUI tools: btop, lazygit, zoxide, atuin, bat
- Dotfiles manager: chezmoi

## Folder Structure
- `setup/` - Main setup scripts
  - `phase1-windows.ps1` - Windows configuration and app installation
  - `phase2-wsl.ps1` - WSL2 and Linux environment setup
  - `scripts/` - Individual installation scripts

## Windows Unattended Installation

For fully automated Windows installation, use the bundled [`autounattend.xml`](autounattend.xml). It will:

1. Install Windows 11 with default settings
2. Remove bloatware and configure basic settings
3. Download and run `setup.ps1` automatically on first logon