# windows-setup

Automated setup script for Windows 11 development environment.

## What it does

This project can be installed on any Windows 11 machine. For best results, use a fresh installation with the bundled [`autounattend.xml`](autounattend.xml) — it pre-configures the system and automatically downloads and runs this setup on first logon.

This project automates the complete configuration of a Windows 11 machine for development purposes, consisting of two main phases:

### Phase 1: Windows Configuration
- Removes bloatware and unnecessary Windows apps
- Installs essential applications via Winget (ImageGlass, VLC, Git, etc.)
- Applies visual customizations (black theme, disabled lock screen, etc.)
- Keeps the machine awake when the lid closes (SSH stays reachable) and locks the screen after 60s of inactivity
- Sets the Windows time zone to **FLE Standard Time** and resyncs the clock
- Sets the taskbar date/time display format to `HH:mm` and `dd.MM.yyyy`
- Downloads and installs **WezTerm** terminal with **JetBrains Mono Nerd Font** and adds it to autostart
- Installs **chezmoi** and applies Windows-side dotfiles (WezTerm, Flow Launcher, virtual-desktop helper)
- Creates PowerShell admin profile with auto-elevation
- Creates a `PowerShell Admin` shortcut in the Start menu (runs elevated)
- Creates WSL2 filesystem layout and configures JetBrains Mono Nerd Font system-wide

### Phase 2: WSL2 & Linux Environment
- Sets up **Debian WSL2** distribution with Fish shell
- Sets the WSL time zone to **Europe/Riga** (matches FLE Standard Time)
- Installs base packages: git, neovim, ripgrep, fzf, python3-pip, fish, Docker, etc.
- Installs development tools: **Starship** prompt, **dblab** TUI database client
- Configures **Fish** shell with Starship integration and useful aliases
- Installs **OpenCode 2 CLI** in WSL and creates workspaces `~/projects/development` and `~/projects/common`
- Does not install PHP or Composer in WSL: project PHP/Composer runs inside Docker containers
- Agents read the project's `AGENTS.md`/README and `Dockerfile`/compose, then use the project's own PHP service/image (not a generic container)
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

4. Confirm reboot when asked (Phase 1 requires reboot to initialize WSL2)

5. After reboot, login to Windows and the setup will automatically continue with Phase 2

6. Once complete:
   - Portainer UI at http://localhost:9000
   - Open Debian terminal to see Fish + JetBrains Mono Font
   - Login with your chosen username
   - WezTerm and OpenCode Desktop open on «Разработка»; OpenCode 2 runs as a Windows background service

## Projects & Tools Installed

### Windows Applications
- 7-Zip, ImageGlass, VLC, Flow-Launcher, Git, WezTerm, chezmoi, OpenCode CLI
- Downloads `VirtualDesktop.exe` for the WezTerm/OpenCode virtual-desktop helper (opens on the Windows desktop «Разработка»)

### Linux/WSL2 Tools
- Base: git, neovim, ripgrep, fzf, python3-pip, fish, wl-clipboard, Docker, sudo
- Prompt: Starship
- Database client: dblab
- Container management: Docker, Portainer
- Agent workspace: OpenCode 2 CLI, workspaces `development` and `common`
- PHP/Composer: only inside project Docker containers
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