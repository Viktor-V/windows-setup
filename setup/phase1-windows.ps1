# phase1-windows.ps1 - Windows Configuration & Applications

Write-Host "[STEP 2] Applying Windows 11 interface and black personalization tweaks..." -ForegroundColor Cyan

# Disable logon background and acrylic effects
$sysPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
if (-not (Test-Path $sysPath)) { New-Item -Path $sysPath -Force | Out-Null }
Set-ItemProperty -Path $sysPath -Name "DisableLogonBackgroundImage" -Type DWORD -Value 1 -Force
Set-ItemProperty -Path $sysPath -Name "DisableAcrylicOnIncline" -Type DWORD -Value 1 -Force

# Remove bloatware
Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*Getstarted*" -or $_.PackageName -like "*DevHome*" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
Get-AppxPackage -AllUsers "*Getstarted*" | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
Get-AppxPackage -AllUsers "*DevHome*" | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue

# Hide recommended section in Start
$pStart = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start"
if (-not (Test-Path $pStart)) { New-Item -Path $pStart -Force | Out-Null }
Set-ItemProperty -Path $pStart -Name "HideRecommendedSection" -Type DWORD -Value 1 -Force

# Education environment
$pEdu = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Education"
if (-not (Test-Path $pEdu)) { New-Item -Path $pEdu -Force | Out-Null }
Set-ItemProperty -Path $pEdu -Name "IsEducationEnvironment" -Type DWORD -Value 1 -Force

# Disable lock screen
$lockP = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
if (-not (Test-Path $lockP)) { New-Item -Path $lockP -Force | Out-Null }
Set-ItemProperty -Path $lockP -Name "NoLockScreen" -Type DWORD -Value 1 -Force

# Black background
Set-ItemProperty -Path "HKCU:\Control Panel\Colors" -Name "Background" -Value "0 0 0" -Force
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers" -Name "BackgroundType" -Type DWORD -Value 1 -Force

# Dark theme
$hTheme = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
Set-ItemProperty -Path $hTheme -Name "AppsUseLightTheme" -Type DWORD -Value 0 -Force
Set-ItemProperty -Path $hTheme -Name "SystemUsesLightTheme" -Type DWORD -Value 0 -Force

# Disable window snap features
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WindowArrangementActive" -Value "0" -Force
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "JointResize" -Value "0" -Force

$hAdv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $hAdv -Name "EnableSnapBar" -Type DWORD -Value 0 -Force
Set-ItemProperty -Path $hAdv -Name "SnapAssist" -Type DWORD -Value 0 -Force
Set-ItemProperty -Path $hAdv -Name "Start_TrackDocs" -Type DWORD -Value 0 -Force
Set-ItemProperty -Path $hAdv -Name "Start_TrackProgs" -Type DWORD -Value 0 -Force

# Black background for default user
Set-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\Colors" -Name "Background" -Value "0 0 0" -Force

Write-Host "[STEP 3] Verifying active network connection status..." -ForegroundColor Cyan

function Test-InternetConnection {
    # Prefer a TCP probe to a real HTTPS endpoint; Test-Connection uses WMI
    # (Win32_PingStatus) and throws "Generic failure" when the stack is not ready.
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $result = $client.BeginConnect("one.one.one.one", 443, $null, $null)
        $connected = $result.AsyncWaitHandle.WaitOne(3000)
        if ($connected -and $client.Connected) {
            $client.Close()
            return $true
        }
        $client.Close()
    }
    catch {
        # fall through to ping fallback
    }

    # Fallback: .NET ping (avoids WMI as well)
    try {
        $ping = New-Object System.Net.NetworkInformation.Ping
        $reply = $ping.Send("1.1.1.1", 1000)
        return ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success)
    }
    catch {
        return $false
    }
}

$netTimeout = 12   # attempts (5 s x 12 = 60 s)
$connected = $false
for ($i = 1; $i -le $netTimeout; $i++) {
    if (Test-InternetConnection) {
        $connected = $true
        break
    }
    Write-Host " -> Network check #$i/$netTimeout - waiting..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
}
if (-not $connected) {
    Write-Warning "Network unavailable after $netTimeout attempts - continuing anyway"
}

Write-Host "[STEP 4] Downloading and processing app manifests via WinGet..." -ForegroundColor Cyan
$exeApps = @(
    "7zip.7zip",
    "DuongDieuPhap.ImageGlass",
    "VideoLAN.VLC",
    "Flow-Launcher.Flow-Launcher",
    "glzr-io.glazewm",
    "Git.Git",
    "wez.wezterm"
)

foreach ($app in $exeApps) { 
    Write-Host " -> Installing $app..." -ForegroundColor Yellow
    winget install --id $app -e --accept-source-agreements --accept-package-agreements --silent --no-upgrade 
}

Write-Host "[STEP 5] Deploying JetBrains Mono Nerd Font for WezTerm..." -ForegroundColor Cyan

# Download and install JetBrains Mono Nerd Font
$fontTempDir = "$env:TEMP\JetBrainsMonoNerdFont"
$fontZip = "$fontTempDir\JetBrainsMono.zip"
$fontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"

Write-Host " -> Creating temporary directory..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $fontTempDir -Force | Out-Null

Write-Host " -> Downloading JetBrains Mono Nerd Font..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $fontUrl -OutFile $fontZip -UseBasicParsing

Write-Host " -> Extracting font files..." -ForegroundColor Yellow
Expand-Archive -Path $fontZip -DestinationPath $fontTempDir -Force

Write-Host " -> Installing font files..." -ForegroundColor Yellow
$fontFiles = Get-ChildItem -Path $fontTempDir -Filter "*.ttf" -Recurse
foreach ($fontFile in $fontFiles) {
    Copy-Item -Path $fontFile.FullName -Destination "$env:SystemRoot\Fonts" -Force
}

Copy-Item -Path $fontFiles.FullName -Destination "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" -Force

try {
    Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
[DllImport("user32.dll", SetLastError = true)]
public static extern int SendMessageTimeout(int hWnd, uint Msg, int wParam, int lParam, uint fuFlags, uint uTimeout, out int lpdwResult);
"@
    $result = 0
    [Win32.NativeMethods]::SendMessageTimeout(0xffff, 0x001D, 0, 0, 2, 1000, [ref] $result) | Out-Null
    Write-Host " -> System font message sent (legacy UI update)" -ForegroundColor Green
}
catch {
    Write-Warning " -> Failed to notify system of font change (can be ignored); font files already copied"
}

Write-Host " -> Cleaning up temporary files..." -ForegroundColor Yellow
Remove-Item -Path $fontTempDir -Recurse -Force

Write-Host "[STEP 6] Configuring WezTerm..." -ForegroundColor Cyan

$wezConfigDir = "$env:APPDATA\wezterm"
$wezConfigFile = "$wezConfigDir\wezterm.lua"

if (-not (Test-Path $wezConfigDir)) {
    New-Item -ItemType Directory -Path $wezConfigDir -Force | Out-Null
}

$wezConfig = @"
-- WezTerm configuration
-- Automatically generated by dev environment setup
return {
  default_domain = "WSL:Debian",
  font = wez.font("JetBrains Mono NF"),
  font_size = 11.0,
  color_scheme = "Dracula (Official)",
  window_background_opacity = 0.9,
  text_background_opacity = 0.8,
}
"@

Set-Content -Path $wezConfigFile -Value $wezConfig -Encoding UTF8

Write-Host "[STEP 7] Configuring PowerShell profile..." -ForegroundColor Cyan

# Configure PowerShell profile (without Oh My Posh)
$pDir = "$HOME\Documents\PowerShell"
if (-not (Test-Path $pDir)) {
    New-Item -Path $pDir -ItemType Directory -Force | Out-Null
}

# Create a clean PowerShell profile
$profileContent = @"
# PowerShell profile
# Customize your PowerShell experience here
Write-Host "Welcome to PowerShell!" -ForegroundColor Green
"@

Set-Content -Path "$pDir\Microsoft.PowerShell_profile.ps1" -Value $profileContent -Encoding utf8

# Create PowerShell admin profile for elevated tasks
$adminProfileContent = @"
# PowerShell Admin Profile
# For elevated dev environment tasks

# Check if running as admin, if not, relaunch as admin
`$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
`$windowsPrincipal = New-Object Security.Principal.WindowsPrincipal(`$currentIdentity)
`$isAdmin = `$windowsPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not `$isAdmin) {
    Write-Host "Relaunching PowerShell with administrator privileges..." -ForegroundColor Yellow
    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File "' + `$MyInvocation.MyCommand.Path + '"'
    Exit
}

Write-Host "Running with administrator privileges" -ForegroundColor Green

Set-Alias -Name ll -Value 'ls -lah' -Option AllScope
Set-Alias -Name gs -Value 'git status' -Option AllScope
Set-Alias -Name gc -Value 'git commit' -Option AllScope

function Restart-WSL {
    Write-Host "Restarting WSL..." -ForegroundColor Cyan
    wsl --shutdown
    Start-Sleep -Seconds 2
    wsl -d Debian
}

function WSL-IP {
    wsl hostname -I
}

Write-Host ""
Write-Host "=== Dev Environment Admin PowerShell ===" -ForegroundColor Cyan
Write-Host "Useful commands:" -ForegroundColor Yellow
Write-Host "  Restart-WSL     - Restart WSL subsystem" -ForegroundColor White
Write-Host "  WSL-IP          - Get WSL IP address" -ForegroundColor White
Write-Host "  gs              - Git status" -ForegroundColor White
Write-Host "  gc              - Git commit" -ForegroundColor White
Write-Host "  ll              - Detailed directory listing" -ForegroundColor White
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
"@

$adminProfileDir = Join-Path $HOME "Documents\Windows PowerShell"
if (-not (Test-Path $adminProfileDir)) {
    New-Item -ItemType Directory -Path $adminProfileDir -Force | Out-Null
}
Set-Content -Path (Join-Path $adminProfileDir "profile.ps1") -Value $adminProfileContent -Encoding utf8

Write-Host "[OK] PowerShell admin profile configured" -ForegroundColor Green

Write-Host "[STEP 8] Creating PowerShell administrator shortcut..." -ForegroundColor Cyan

$desktopPath = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktopPath "DevSetup PowerShell Admin.lnk"

$wshell = New-Object -ComObject WScript.Shell
$shortcut = $wshell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass"
$shortcut.WorkingDirectory = "$env:USERPROFILE"
$shortcut.Description = "PowerShell with admin privileges for dev environment tasks"
$shortcut.IconLocation = "$env:SystemRoot\System32\shell32.dll,176"
$shortcut.Save()

# Mark the .lnk as "Run as administrator" (byte 21, bit 0x20)
$lnkBytes = [System.IO.File]::ReadAllBytes($shortcutPath)
$lnkBytes[0x15] = $lnkBytes[0x15] -bor 0x20
[System.IO.File]::WriteAllBytes($shortcutPath, $lnkBytes)

Write-Host "[OK] PowerShell admin shortcut created on desktop" -ForegroundColor Green

Write-Host "[STEP 9] Creating WezTerm WSL2 shortcut with Fish..." -ForegroundColor Cyan

function New-WSLShortcut {
    param(
        [string]$ShortcutName,
        [string]$TargetPath,
        [string]$Arguments,
        [string]$WorkingDirectory,
        [string]$IconLocation,
        [bool]$AddToStartup = $false
    )

    $wshell = New-Object -ComObject WScript.Shell
    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktopPath "$ShortcutName.lnk"
    $shortcut = $wshell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $TargetPath
    $shortcut.Arguments = $Arguments
    $shortcut.WorkingDirectory = $WorkingDirectory
    $shortcut.IconLocation = $IconLocation
    $shortcut.Save()

    Write-Host " -> Created desktop shortcut: $ShortcutName.lnk" -ForegroundColor Green

    if ($AddToStartup) {
        $startupPath = [Environment]::GetFolderPath('Startup')
        $startupShortcutPath = Join-Path $startupPath "$ShortcutName.lnk"
        $startupShortcut = $wshell.CreateShortcut($startupShortcutPath)
        $startupShortcut.TargetPath = $TargetPath
        $startupShortcut.Arguments = $Arguments
        $startupShortcut.WorkingDirectory = $WorkingDirectory
        $startupShortcut.IconLocation = $IconLocation
        $startupShortcut.Save()
        Write-Host " -> Added to Startup folder: $ShortcutName.lnk" -ForegroundColor Green
    }
}

# Create WezTerm with WSL2 shortcut that launches Fish directly
$wezTermExe = @(
    "$env:LOCALAPPDATA\Programs\wezterm\wezterm.exe",
    "$env:ProgramFiles\WezTerm\wezterm.exe"
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if (-not $wezTermExe) {
    Write-Warning "WezTerm executable not found. Skipping shortcut creation."
}
else {
    New-WSLShortcut `
        -ShortcutName "WezTerm WSL2 (Fish)" `
        -TargetPath $wezTermExe `
        -Arguments "start" `
        -WorkingDirectory "$env:USERPROFILE" `
        -IconLocation "$env:SystemRoot\System32\shell32.dll,240" `
        -AddToStartup $false
}

Write-Host "[OK] WezTerm WSL2 shortcut with Fish created" -ForegroundColor Green

Write-Host "[STEP 10] Checking WSL2 prerequisites..." -ForegroundColor Cyan

Write-Host " -> Installing WSL2..." -ForegroundColor Yellow
wsl --install --no-distribution | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host " -> WSL2 is ready." -ForegroundColor Green
} else {
    Write-Host "[WARNING] WSL2 install returned exit code $LASTEXITCODE." -ForegroundColor Red
    Write-Host "  If you see a virtualization error, enable VT-x/AMD-V in your BIOS/UEFI settings." -ForegroundColor Yellow
}

Write-Host "`n[OK] Phase 1 completed successfully!" -ForegroundColor Green