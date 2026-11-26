# VM test checklist

Use a Windows 11 VM snapshot. Run `setup.ps1` as Administrator and verify:

## Phase 1

- WinGet installs 7-Zip, ImageGlass, VLC, Flow Launcher, Git, WezTerm, chezmoi,
  OpenCode CLI, and OpenCode Desktop.
- `JetBrainsMono NF` appears in Windows font settings.
- `HKCU\Software\Classes\.png` points to `ImageGlass.Viewer`.
- `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\WezTerm.lnk` exists.
- `PowerShell Admin` opens elevated and loads `gs`, `gc`, and `ll`.
- The machine reboots and the `ResumeDevSetup` scheduled task runs Phase 2.

## Phase 2

- `wsl -l -v` shows Debian as the default distribution.
- Docker is enabled after the restart:

  ```sh
  systemctl is-enabled docker
  docker ps
  ```

- Portainer answers:

  ```sh
  curl -fsS http://127.0.0.1:9000 >/dev/null
  ```

- OpenCode is running and authenticated:

  ```sh
  systemctl status opencode.service
  opencode service status
  ```

- `opencode.service` is enabled and uses `Restart=always`.
- `OpenCode WSL Server` exists in the Windows Startup folder.
- `OpenCode Pair` exists in the Start menu.

## Clients

- `opencode pair` link opens the web UI and can be pasted into OpenCode Desktop.
- `opencode pair --remote` prints a QR/link that an iPhone client can scan.
- A desktop session created from the phone is visible on the PC and vice versa.
- Kill the OpenCode main process and verify that systemd restarts it:

  ```sh
  sudo systemctl kill -s SIGKILL opencode.service
  sleep 10
  systemctl status opencode.service
  ```

## Logs

- `journalctl -u opencode.service`
- `%USERPROFILE%\.config\opencode\wsl-server.log`
- `%LOCALAPPDATA%\VirtualDesktop\wezterm-desktop.log`
