# phase2-wsl.ps1 - WSL Environment & Development Tools
param(
    [Parameter(Mandatory = $true)]
    [string]$Password,
    [Parameter(Mandatory = $true)]
    [string]$Username,
    [string]$OpenCodePassword = ""
)

$ErrorActionPreference = "Stop"
$distroName = "Debian"
$linuxUser = $Username

if ([string]::IsNullOrWhiteSpace($OpenCodePassword)) {
    $OpenCodePassword = [guid]::NewGuid().ToString('N')
    Write-Warning "OpenCode password was not supplied; generated a new one."
}

if ($OpenCodePassword.Length -lt 20) {
    throw "OpenCode password must be at least 20 characters."
}

function Protect-SecretFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    & icacls.exe $Path /inheritance:r /grant:r "$($identity):(F)" "*S-1-5-18:(F)" "*S-1-5-32-544:(F)" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Could not restrict permissions on $Path."
    }
}

function Invoke-Wsl {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & wsl.exe @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "WSL command failed with exit code $LASTEXITCODE`: wsl.exe $($Arguments -join ' ')"
    }
}

function Invoke-WslBash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,
        [string]$User = "root"
    )

    # Normalize CRLF -> LF so bash line-continuations (backslash) work.
    $Command = $Command -replace "`r`n", "`n"

    # Encode the Bash command to avoid PowerShell quoting and Windows-path translation issues.
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Command)
    $base64 = [Convert]::ToBase64String($bytes)

    $workDir = if ($User -eq 'root') { '/root' } else { "/home/$User" }

    Invoke-Wsl -Arguments @(
        "--distribution", $distroName,
        "--user", $User,
        "--cd", $workDir,
        "--exec", "bash", "-lc",
        "export USER_NAME='$linuxUser'; echo '$base64' | base64 -d | bash"
    )
}

function Invoke-WslScriptFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Linux install script not found: $Path"
    }

    $scriptContent = Get-Content -Path $Path -Raw
    Invoke-WslBash -Command $scriptContent
}

Write-Host "[STEP 6] Resuming Setup. Syncing Debian subsystem layers..." -ForegroundColor Green

# Check whether Debian is already registered before trying to install it.
$installedDistros = @(
    wsl.exe --list --quiet 2>$null |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ }
)

if ($installedDistros -notcontains $distroName) {
    Write-Host " -> Debian is not installed. Installing it..." -ForegroundColor Yellow
    $installSuccess = $false
    for ($i = 1; $i -le 3; $i++) {
        & wsl.exe --install --distribution $distroName --no-launch 2>$null
        if ($LASTEXITCODE -eq 0) {
            $installSuccess = $true
            break
        }
        Write-Host "   Attempt $i failed, retrying..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }
    if (-not $installSuccess) {
        throw "Debian installation failed after 3 attempts."
    }
}
else {
    Write-Host " -> Debian is already installed. Skipping installation." -ForegroundColor Green
}

# Wait until the distribution can actually execute commands.
$debianReady = $false

for ($i = 1; $i -le 36; $i++) {
    & wsl.exe --distribution $distroName --user root --cd /root --exec /bin/true 2>$null

    if ($LASTEXITCODE -eq 0) {
        $debianReady = $true
        break
    }

    Write-Host " -> Waiting for Debian initialization... ($i/36)" -ForegroundColor Yellow
    Start-Sleep -Seconds 5
}

if (-not $debianReady) {
    throw "Debian was registered but did not become ready within 180 seconds."
}

# WezTerm and the startup helper both use Debian by default.
& wsl.exe --set-default $distroName
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Could not set Debian as the default WSL distribution."
}

Write-Host "[STEP 7] Provisioning Linux environment layers..." -ForegroundColor Cyan

# Write a valid /etc/wsl.conf using a Base64-safe Bash command.
$wslConfig = @"
[boot]
systemd=true

[automount]
options = "metadata"

[user]
default=$linuxUser
"@

$wslConfigBase64 = [Convert]::ToBase64String(
    [System.Text.Encoding]::UTF8.GetBytes(($wslConfig -replace "`r`n", "`n"))
)

Invoke-WslBash -Command @"
mkdir -p /etc
echo '$wslConfigBase64' | base64 -d > /etc/wsl.conf
chmod 644 /etc/wsl.conf
"@

Write-Host "[STEP 8] Updating Debian and installing base packages..." -ForegroundColor Cyan

Invoke-WslBash -Command @'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    git \
    wget \
    openssh-client \
    build-essential \
    gcc \
    g++ \
    make \
    unzip \
    tar \
    neovim \
    ripgrep \
    fzf \
    python3-pip \
    fish \
    wl-clipboard \
    passwd \
    sudo
'@

# Escape single quotes for a safely quoted shell value.
$shellPassword = $Password.Replace("'", "'""'""'")

Invoke-WslBash -Command @"
if ! id '$linuxUser' >/dev/null 2>&1; then
    useradd -m -s /usr/bin/fish -G sudo '$linuxUser'
fi

echo '${linuxUser}:${shellPassword}' | chpasswd

# Only the wsl.conf update used by chezmoi is passwordless. Everything else
# requires the WSL password; Docker group membership is still effectively root,
# so treat this account accordingly.
cat > /etc/sudoers.d/${linuxUser} <<'SUDOERS'
${linuxUser} ALL=(root) NOPASSWD: /usr/bin/tee /etc/wsl.conf
SUDOERS
chmod 440 /etc/sudoers.d/${linuxUser}
if ! visudo -cf /etc/sudoers.d/${linuxUser}; then
    rm -f /etc/sudoers.d/${linuxUser}
    exit 1
fi

usermod -s /usr/bin/fish '${linuxUser}'
"@

Write-Host " -> Setting WSL time zone..." -ForegroundColor Cyan
Invoke-WslBash -Command @"
ln -sf /usr/share/zoneinfo/Europe/Riga /etc/localtime
echo Europe/Riga > /etc/timezone
"@

Write-Host " -> Installing Starship prompt..." -ForegroundColor Cyan
Invoke-WslScriptFile -Path (Join-Path $PSScriptRoot "scripts\install_starship.sh")

Write-Host " -> Installing dblab database client..." -ForegroundColor Cyan
Invoke-WslScriptFile -Path (Join-Path $PSScriptRoot "scripts\install_dblab.sh")

Write-Host " -> Installing Docker Engine with plugins..." -ForegroundColor Cyan
Invoke-WslScriptFile -Path (Join-Path $PSScriptRoot "scripts\install_docker.sh")

# Docker creates the docker group, so add the user after Docker installation.
Invoke-WslBash -Command @"
usermod -aG docker '$linuxUser'

if command -v systemctl >/dev/null 2>&1; then
    systemctl enable docker >/dev/null 2>&1 || true
fi

if ! docker info >/dev/null 2>&1; then
    if command -v systemctl >/dev/null 2>&1 && systemctl is-system-running >/dev/null 2>&1; then
        systemctl start docker
    else
        service docker start || true
    fi
fi
"@

Write-Host " -> Installing btop..." -ForegroundColor Cyan
Invoke-WslScriptFile -Path (Join-Path $PSScriptRoot "scripts\install_btop.sh")

Write-Host " -> Installing lazygit..." -ForegroundColor Cyan
Invoke-WslScriptFile -Path (Join-Path $PSScriptRoot "scripts\install_lazygit.sh")

Write-Host " -> Installing zoxide..." -ForegroundColor Cyan
Invoke-WslScriptFile -Path (Join-Path $PSScriptRoot "scripts\install_zoxide.sh")

Write-Host " -> Installing atuin..." -ForegroundColor Cyan
Invoke-WslScriptFile -Path (Join-Path $PSScriptRoot "scripts\install_atuin.sh")

Write-Host " -> Installing bat..." -ForegroundColor Cyan
Invoke-WslScriptFile -Path (Join-Path $PSScriptRoot "scripts\install_bat.sh")

Write-Host " -> Installing chezmoi..." -ForegroundColor Cyan
Invoke-WslScriptFile -Path (Join-Path $PSScriptRoot "scripts\install_chezmoi.sh")

Write-Host " -> Deploying Portainer container..." -ForegroundColor Cyan
Invoke-WslScriptFile -Path (Join-Path $PSScriptRoot "scripts\install_portainer.sh")

Write-Host " -> Installing OpenCode 2 CLI..." -ForegroundColor Cyan
Invoke-WslScriptFile -Path (Join-Path $PSScriptRoot "scripts\install_opencode.sh")

Write-Host " -> Creating workspaces..." -ForegroundColor Cyan
Invoke-WslBash -User $linuxUser -Command @"
mkdir -p ~/projects/development ~/projects/common
"@

Write-Host " -> Configuring OpenCode server in WSL..." -ForegroundColor Cyan
$passwordB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($OpenCodePassword))

$ocSetup = @'
set -euo pipefail
OPENCODE="$HOME/.opencode/bin/opencode"
mkdir -p "$HOME/.config/opencode" "$HOME/.local/bin"

printf '%s' '__PASSWORD_B64__' | base64 -d > "$HOME/.config/opencode/server-password"
chmod 600 "$HOME/.config/opencode/server-password"

"$OPENCODE" service set hostname 0.0.0.0
"$OPENCODE" service set port 4097
OC_PASSWORD=$(cat "$HOME/.config/opencode/server-password")
"$OPENCODE" service set password "$OC_PASSWORD"
"$OPENCODE" service start

for i in $(seq 1 30); do
    if "$OPENCODE" service status >/dev/null 2>&1 &&
       curl -fsS --max-time 5 -u "opencode:$OC_PASSWORD" http://127.0.0.1:4097/api/info >/dev/null 2>&1; then
        break
    fi
    sleep 2
done
"$OPENCODE" service status
curl -fsS --max-time 5 -u "opencode:$OC_PASSWORD" http://127.0.0.1:4097/api/info >/dev/null

# Remove the helper from the old Windows-hosted server design.
rm -f "$HOME/.local/bin/opencode-tui"
'@
$ocSetup = $ocSetup.Replace('__PASSWORD_B64__', $passwordB64)
Invoke-WslBash -User $linuxUser -Command $ocSetup

Write-Host " -> Installing OpenCode service helper..." -ForegroundColor Cyan
$serviceStart = @'
#!/usr/bin/env bash
set -euo pipefail
OPENCODE="$HOME/.opencode/bin/opencode"
for _ in $(seq 1 30); do
    if "$OPENCODE" service status >/dev/null 2>&1; then
        exit 0
    fi
    "$OPENCODE" service start >/dev/null 2>&1 || true
    sleep 2
done
exit 1
'@
$serviceStartB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($serviceStart -replace "`r`n", "`n")))
Invoke-WslBash -User $linuxUser -Command @"
mkdir -p ~/.local/bin
printf '%s' '$serviceStartB64' | base64 -d > ~/.local/bin/opencode-service-start
chmod +x ~/.local/bin/opencode-service-start
"@

Write-Host " -> Writing OpenCode instructions for WSL projects..." -ForegroundColor Cyan
$agents = @'
# OpenCode in WSL

The OpenCode server runs inside this WSL Debian instance. Projects under
`/home/__WSL_USER__/projects` are local Linux paths.

- Use the normal Linux tools (`git`, `docker`, `docker compose`).
- Before changing a project, read its `AGENTS.md`/`README`, `Dockerfile`,
  `compose.yaml`/`docker-compose.yml`, and `.env`.
- Run PHP and Composer inside the project's own container; do not install them
  on the WSL host.
- Use the project's own service/image and commands (`Makefile`, Composer
  scripts, `bin/console`); do not substitute a generic container.
- Prefer relative paths in shell commands.
'@
$agents = $agents.Replace('__WSL_USER__', $linuxUser)
$agentsB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($agents -replace "`r`n", "`n")))
Invoke-WslBash -User $linuxUser -Command @"
mkdir -p ~/.config/opencode
printf '%s' '$agentsB64' | base64 -d > ~/.config/opencode/AGENTS.md
"@

# Store the password on Windows too, so Desktop can be paired without digging
# through WSL, and start the WSL server automatically on future logons.
$opencodeConfigDir = Join-Path $env:USERPROFILE ".config\opencode"
New-Item -ItemType Directory -Path $opencodeConfigDir -Force | Out-Null
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$windowsPasswordFile = Join-Path $opencodeConfigDir "server-password"
[System.IO.File]::WriteAllText(
    $windowsPasswordFile,
    $OpenCodePassword,
    $utf8NoBom
)
Protect-SecretFile $windowsPasswordFile
"http://localhost:4097" | Set-Content -LiteralPath (Join-Path $opencodeConfigDir "server-url.txt") -NoNewline -Encoding ascii

$startWslContent = @'
$ErrorActionPreference = 'SilentlyContinue'
$log = Join-Path $env:USERPROFILE '.config\opencode\wsl-server.log'
& wsl.exe -d __DISTRO__ -u __USER__ --exec /home/__USER__/.local/bin/opencode-service-start *>> $log
'@
$startWslContent = $startWslContent.Replace('__DISTRO__', $distroName).Replace('__USER__', $linuxUser)
$startWslScript = Join-Path $opencodeConfigDir 'start-wsl-opencode.ps1'
$startWslContent | Set-Content -LiteralPath $startWslScript -Encoding utf8

$ws = New-Object -ComObject WScript.Shell
$startup = [Environment]::GetFolderPath('Startup')
Remove-Item -LiteralPath (Join-Path $startup 'OpenCode Service.lnk') -Force -ErrorAction SilentlyContinue

$lnk = $ws.CreateShortcut((Join-Path $startup 'OpenCode WSL Server.lnk'))
$lnk.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$lnk.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$startWslScript`""
$lnk.WorkingDirectory = $env:USERPROFILE
$lnk.Description = 'Start the OpenCode server inside WSL Debian'
$lnk.Save()

$pairContent = @'
$ErrorActionPreference = 'Stop'
Write-Host "Generating a one-time OpenCode remote pairing link..." -ForegroundColor Cyan
& wsl.exe -d __DISTRO__ -u __USER__ -e bash -lc 'cd ~ && opencode pair --remote'
Write-Host ''
Read-Host 'Scan the QR code with OpenCode Mobile, then press Enter'
'@
$pairContent = $pairContent.Replace('__DISTRO__', $distroName).Replace('__USER__', $linuxUser)
$pairScript = Join-Path $opencodeConfigDir 'pair-opencode.ps1'
$pairContent | Set-Content -LiteralPath $pairScript -Encoding utf8

$pairLnk = $ws.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Programs')) 'OpenCode Pair.lnk'))
$pairLnk.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$pairLnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$pairScript`""
$pairLnk.WorkingDirectory = $env:USERPROFILE
$pairLnk.Description = 'Pair OpenCode Desktop or a phone with the WSL server'
$pairLnk.Save()

# Restart the WSL OpenCode service if it dies while the user is logged on.
try {
    $watchdogName = 'OpenCode WSL Server Watchdog'
    $watchdogAction = New-ScheduledTaskAction `
        -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$startWslScript`""
    $watchdogTrigger = New-ScheduledTaskTrigger `
        -Once `
        -At (Get-Date).AddMinutes(1) `
        -RepetitionInterval (New-TimeSpan -Minutes 5) `
        -RepetitionDuration (New-TimeSpan -Days 3650)
    $watchdogPrincipal = New-ScheduledTaskPrincipal `
        -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) `
        -LogonType Interactive `
        -RunLevel Limited
    $watchdogSettings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -MultipleInstances IgnoreNew `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

    Register-ScheduledTask `
        -TaskName $watchdogName `
        -Action $watchdogAction `
        -Trigger $watchdogTrigger `
        -Principal $watchdogPrincipal `
        -Settings $watchdogSettings `
        -Description 'Check the WSL-hosted OpenCode server every five minutes' `
        -Force | Out-Null
    Write-Host " -> OpenCode watchdog task installed." -ForegroundColor Cyan
}
catch {
    Write-Warning "Could not register the OpenCode watchdog task: $($_.Exception.Message)"
}

Write-Host " -> OpenCode server: http://localhost:4097 (WSL), autostart enabled." -ForegroundColor Cyan

Write-Host " -> Applying dotfiles with chezmoi..." -ForegroundColor Cyan
Invoke-WslScriptFile -Path (Join-Path $PSScriptRoot "scripts\install_dotfiles.sh")

Write-Host "[STEP 9] Restarting Debian to apply wsl.conf..." -ForegroundColor Cyan

& wsl.exe --terminate $distroName

if ($LASTEXITCODE -ne 0) {
    Write-Host " [WARNING] Could not terminate Debian automatically." -ForegroundColor Yellow
}

Start-Sleep -Seconds 3

Write-Host "[STEP 10] Waiting for systemd, Docker, Portainer and OpenCode..." -ForegroundColor Cyan

Invoke-WslBash -Command @'
set -euo pipefail

for i in $(seq 1 30); do
    state=$(systemctl is-system-running 2>/dev/null || true)
    case "$state" in
        running|degraded) break ;;
    esac
    sleep 2
done

systemctl enable --now docker

for i in $(seq 1 60); do
    if docker info >/dev/null 2>&1; then
        break
    fi
    sleep 2
done
docker info >/dev/null

docker start portainer >/dev/null 2>&1 || true
for i in $(seq 1 30); do
    if curl -fsS --max-time 5 http://127.0.0.1:9000 >/dev/null 2>&1; then
        break
    fi
    sleep 2
done
curl -fsS --max-time 5 http://127.0.0.1:9000 >/dev/null
'@

# Start the OpenCode service after the WSL restart as well.
Invoke-WslBash -User $linuxUser -Command '"$HOME/.local/bin/opencode-service-start"'

# Verify that Debian starts, the default user exists, and Windows can reach
# the WSL-hosted OpenCode server through localhost forwarding.
Invoke-Wsl -Arguments @(
    "--distribution", $distroName,
    "--cd", "/home/$linuxUser",
    "--exec", "id", $linuxUser
)

$opencodeReachable = $false
for ($i = 1; $i -le 10; $i++) {
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.Connect("127.0.0.1", 4097)
        $tcp.Close()
        $opencodeReachable = $true
        break
    }
    catch {
        Start-Sleep -Seconds 1
    }
}

if ($opencodeReachable) {
    Write-Host " -> OpenCode is reachable from Windows at http://localhost:4097" -ForegroundColor Green
}
else {
    Write-Warning "OpenCode is not reachable from Windows on port 4097. Check WSL localhostForwarding or use the WSL IP."
}

Write-Host "`n[OK] Phase 2 completed successfully!" -ForegroundColor Green