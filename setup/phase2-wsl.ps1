# phase2-wsl.ps1 - WSL Environment & Development Tools
param(
    [Parameter(Mandatory = $true)]
    [string]$Password,
    [Parameter(Mandatory = $true)]
    [string]$Username
)

$ErrorActionPreference = "Stop"
$distroName = "Debian"
$linuxUser = $Username

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

    Invoke-Wsl -Arguments @(
        "--distribution", $distroName,
        "--user", $User,
        "--cd", "/root",
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

Write-Host "[STEP 7] Provisioning Linux environment layers..." -ForegroundColor Cyan

# Write a valid /etc/wsl.conf using a Base64-safe Bash command.
$wslConfig = @"
[boot]
systemd=true

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
echo '${linuxUser} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/${linuxUser}
chmod 440 /etc/sudoers.d/${linuxUser}
usermod -s /usr/bin/fish '${linuxUser}'
"@

Write-Host " -> Linking win32yank into WSL..." -ForegroundColor Cyan
$win32yankExe = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "win32yank.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if ($win32yankExe) {
    $wslWin32yank = "/mnt/" + $win32yankExe.Substring(0, 1).ToLower() + (($win32yankExe.Substring(2)) -replace '\\', '/')
    Invoke-WslBash -Command "ln -sf '$wslWin32yank' /usr/local/bin/win32yank && chmod 755 /usr/local/bin/win32yank"
    Write-Host "   win32yank available as 'win32yank' in WSL." -ForegroundColor Cyan
}
else {
    Write-Warning "   win32yank.exe not found; WSL link not created."
}

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

Write-Host " -> Installing OpenCode CLI..." -ForegroundColor Cyan
Invoke-WslScriptFile -Path (Join-Path $PSScriptRoot "scripts\install_opencode.sh")

Write-Host " -> OpenCode server password (optional)..." -ForegroundColor Cyan
$opencodeChoice = Read-Host "Set OPENCODE_SERVER_PASSWORD for 'opencode web/serve'? (Y/n)"
if ($opencodeChoice -ne "n" -and $opencodeChoice -ne "N") {
    $secureOpencode = Read-Host -AsSecureString "Enter OPENCODE_SERVER_PASSWORD"
    $plainOpencode = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureOpencode)
    )
    if (-not [string]::IsNullOrWhiteSpace($plainOpencode)) {
        [Environment]::SetEnvironmentVariable('OPENCODE_SERVER_PASSWORD', $plainOpencode, 'User')
        $escapedOpencode = $plainOpencode.Replace("\", "\\").Replace("'", "\'")
        $fishLine = "set -gx OPENCODE_SERVER_PASSWORD '" + $escapedOpencode + "'" + "`n"
        $opencodeLineB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($fishLine))
        Invoke-WslBash -User $linuxUser -Command @"
mkdir -p ~/.config/fish/conf.d
printf '%s' '$opencodeLineB64' | base64 -d > ~/.config/fish/conf.d/opencode.fish
chmod 600 ~/.config/fish/conf.d/opencode.fish
"@
        Write-Host "   OPENCODE_SERVER_PASSWORD saved to Windows User env and WSL fish env." -ForegroundColor Cyan
    }
    else {
        Write-Host "   Empty password, skipped." -ForegroundColor Green
    }
}
else {
    Write-Host "   Skipped OPENCODE_SERVER_PASSWORD." -ForegroundColor Green
}

Write-Host " -> Installing btop..." -ForegroundColor Cyan
Invoke-WslScriptFile -Path (Join-Path $PSScriptRoot "scripts\install_btop.sh")

Write-Host " -> Installing lazygit..." -ForegroundColor Cyan
Invoke-WslScriptFile -Path (Join-Path $PSScriptRoot "scripts\install_lazygit.sh")

Write-Host " -> Installing fastfetch..." -ForegroundColor Cyan
Invoke-WslScriptFile -Path (Join-Path $PSScriptRoot "scripts\install_fastfetch.sh")

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

Write-Host " -> Finalizing Fish shell configuration..." -ForegroundColor Cyan
Invoke-WslScriptFile -Path (Join-Path $PSScriptRoot "scripts\configure_fish.sh")

Write-Host " -> Applying dotfiles with chezmoi..." -ForegroundColor Cyan
Invoke-WslScriptFile -Path (Join-Path $PSScriptRoot "scripts\install_dotfiles.sh")

Write-Host "[STEP 9] Restarting Debian to apply wsl.conf..." -ForegroundColor Cyan

& wsl.exe --terminate $distroName

if ($LASTEXITCODE -ne 0) {
    Write-Host " [WARNING] Could not terminate Debian automatically." -ForegroundColor Yellow
}

Start-Sleep -Seconds 3

# Verify that Debian starts and that the configured default user exists.
Invoke-Wsl -Arguments @(
    "--distribution", $distroName,
    "--cd", "/home/$linuxUser",
    "--exec", "id", $linuxUser
)

Write-Host "`n[OK] Phase 2 completed successfully!" -ForegroundColor Green