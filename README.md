# windows-setup

Automated setup for a Windows 11 development machine with Debian WSL2, Docker, and a shared OpenCode 2 server.

## What it does

The project can be installed on any Windows 11 machine. For best results, use a fresh installation with the bundled [`autounattend.xml`](autounattend.xml): it pre-configures the system and starts this setup on first logon. The Windows installation is not fully silent: you still select the target disk and enter the local account and WSL credentials.

The setup has two main phases:

### Phase 1: Windows Configuration
- Removes Get Started and Dev Home, and applies the main debloat through `autounattend.xml` on a fresh install
- Installs essential applications via WinGet (7-Zip, ImageGlass, VLC, Git, WezTerm, chezmoi, etc.)
- Installs **OpenCode CLI** and **OpenCode Desktop**
- Applies visual customizations (black theme, disabled lock screen, etc.)
- Keeps the machine awake when the lid closes and locks the screen after 60s of inactivity
- Sets the Windows time zone to **FLE Standard Time** and resyncs the clock
- Sets the taskbar date/time display format to `HH:mm` and `dd.MM.yyyy`
- Downloads and installs **WezTerm** with **JetBrains Mono Nerd Font** and adds it to autostart
- Applies Windows-side dotfiles (WezTerm, Flow Launcher, virtual-desktop helper)
- Creates a PowerShell admin profile and a `PowerShell Admin` shortcut
- Downloads `VirtualDesktop.exe` for the WezTerm/OpenCode virtual-desktop helper
- Prepares WSL2, removes the old Windows-hosted OpenCode shortcut, and disables the Windows background service so it cannot take over `localhost`

### Phase 2: WSL2 & Linux Environment
- Sets up **Debian WSL2** as the default distribution with Fish shell
- Sets the WSL time zone to **Europe/Riga**
- Installs base packages: git, neovim, ripgrep, fzf, python3-pip, fish, Docker, etc.
- Installs development tools: **Starship**, **dblab**, **btop**, **lazygit**, **zoxide**, **atuin**, **bat**
- Configures **Fish** with Starship and useful aliases
- Installs **OpenCode 2 CLI** and creates workspaces `~/projects/development` and `~/projects/common`
- Runs the **OpenCode server inside WSL** at `http://localhost:4096`, protected by the server password
- Starts the WSL OpenCode server automatically at Windows logon
- Does not install PHP or Composer in WSL: project PHP/Composer runs inside Docker containers
- Sets up **Docker** with Portainer at http://localhost:9000 and validates both after the WSL restart
- Terminates and restarts WSL2 to apply `wsl.conf`, systemd, Docker, and the OpenCode service

## Prerequisites
- Windows 11 (24H2 recommended; older Windows 11 builds use `VirtualDesktop11.exe`, Windows 10 is not supported by the helper)
- Administrator privileges to run `setup.ps1`
- Internet connection for downloading packages
- WSL2 virtualization enabled in BIOS/UEFI

## Quick Start

1. Run `setup.ps1` as Administrator:
    ```powershell
    .\setup.ps1
    ```

2. Enter the WSL username (press Enter for the default: `user`)

3. Enter the WSL password

4. Optionally set the OpenCode password. Press Enter to generate one; it is stored in
   `%USERPROFILE%\.config\opencode\server-password`

5. Confirm the reboot. Phase 2 continues automatically after the next logon.

6. Once complete:
   - Portainer UI at http://localhost:9000
   - Open Debian terminal to see Fish + JetBrains Mono Font
   - OpenCode server at http://localhost:4096 (inside WSL)
   - WezTerm and OpenCode Desktop open on «Разработка»

## OpenCode: Desktop, Web, and Phone

The OpenCode server runs in WSL, next to the projects, so file tools and terminals see
`/home/<user>/projects` directly. The Windows OpenCode Desktop and the phone app are
clients for that server. The WSL server uses port **4096**. Phase 1 stops and
disables the Windows OpenCode background service so it cannot take over that port.

### Desktop and browser

Run this in the Debian terminal:

```sh
opencode pair
```

Paste the one-time link into OpenCode Desktop → Settings → Pairing, or open it in a
browser for the web UI. The link expires after 5 minutes and works once.

For a direct connection, use `http://localhost:4096` as the server address and the
password from:

- WSL: `~/.config/opencode/server-password`
- Windows: `%USERPROFILE%\.config\opencode\server-password`

If Windows cannot reach `localhost:4096`, use the WSL address printed by
`wsl hostname -I` instead (`http://<wsl-ip>:4096`).

### Phone

- **iPhone:** the official **OpenCode Mobile** beta is distributed via
  [TestFlight](https://testflight.apple.com/join/M9eFEE1q).
- **iPhone without TestFlight:** use an App Store client such as
  **OpenLens** (free, open source, iOS 26+), **OC Remote** (free monitoring,
  Pro for controls), **OpenClient for OpenCode** (free tier, lifetime option),
  or **OpenCode-Mobile Community** (free, iOS 15+).
- **Android:** install from Google Play (`ai.opencode.mobilecode`).

In Debian, run:

```sh
ocpair
```

or open the **OpenCode Pair** shortcut from the Start menu. This is an alias for
`opencode pair --remote`, which exposes the server through an OpenTunnel address
and works from any network. The OpenTunnel address stays the
same across service restarts, so pairing once is enough. Scan the QR code with the
app; the session can then be continued from the desktop at home.

`ocpair-local` (`opencode pair`) is for the same Wi-Fi. If the WSL NAT prevents the
phone from reaching the local address, use `ocpair` instead.

Check the server with:

```sh
ocstatus
```

The server binds to `0.0.0.0` and requires the password, so do not share the password
or the pairing link. Prefer `ocpair` (OpenTunnel) over exposing the port on the router.

### Server startup

The `OpenCode WSL Server` shortcut in the Windows Startup folder starts the WSL
service on every logon. A scheduled task named `OpenCode WSL Server Watchdog`
checks it every five minutes and restarts it if needed. WSL must be running for the
phone and Desktop clients to connect. If the service stops, run `ocstatus` or
`opencode service start` in Debian.

### Security notes

- The OpenCode password must be at least 20 characters; press Enter during setup
  to generate a 32-character password.
- The Windows password file is restricted to the current user, SYSTEM, and
  Administrators. The WSL copy is mode `600`.
- WSL `sudo` is passwordless only for the `tee /etc/wsl.conf` command used by
  chezmoi. Other sudo commands require the WSL password.
- Docker group membership is effectively root-equivalent. Treat the WSL account
  as a privileged development account.
- CLI tools installed by the Linux scripts are pinned to specific versions and
  verified with SHA-256 checksums where the upstream project publishes them.
  OpenCode itself still uses its official v2 installer and follows its release
  channel.

## Projects & Tools Installed

### Windows Applications
- 7-Zip, ImageGlass, VLC, Flow-Launcher, Git, WezTerm, chezmoi
- OpenCode CLI and OpenCode Desktop
- `VirtualDesktop.exe` for the WezTerm/OpenCode virtual-desktop helper

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
- `setup/` — main setup scripts
  - `phase1-windows.ps1` — Windows configuration and app installation
  - `phase2-wsl.ps1` — WSL2, Docker, and OpenCode server setup
  - `scripts/` — individual installation scripts
- `autounattend.xml` — Windows 11 unattended installation answer file

## Windows Installation

The bundled [`autounattend.xml`](autounattend.xml) will:

1. Start the Windows 11 installation with the Home edition and common debloat settings
2. Create a local account interactively
3. Download and run `setup.ps1` automatically on first logon

You still choose the destination disk during Windows Setup and enter the Windows/WSL
account details. This is not a fully unattended disk installation.

## Changing the setup

`setup.ps1`, `phase1-windows.ps1`, and `phase2-wsl.ps1` download `Viktor-V/dotfiles`
from GitHub, and `autounattend.xml` downloads `Viktor-V/windows-setup` from GitHub.
Local edits are not used by an automated run until they are pushed to `main`.
