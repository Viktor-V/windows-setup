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
while (-not (Test-Connection -ComputerName 1.1.1.1 -Count 1 -Quiet)) { 
    Write-Host " -> Waiting for network connection..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5 
}

Write-Host "[STEP 4] Downloading and processing app manifests via WinGet..." -ForegroundColor Cyan
$exeApps = @(
    "DuongDieuPhap.ImageGlass", 
    "VideoLAN.VLC", 
    "Valve.Steam", 
    "Flow-Launcher.Flow-Launcher", 
    "glzr-io.glazewm", 
    "Git.Git", 
    "wez.wezterm"
)

foreach ($app in $exeApps) { 
    Write-Host " -> Installing $app..." -ForegroundColor Yellow
    winget install --id $app -e --accept-source-agreements --accept-package-agreements --silent --no-upgrade 
}

Write-Host "[STEP 5] Deploying Inconsolata Nerd Font for WezTerm..." -ForegroundColor Cyan

# Download and install Inconsolata Nerd Font
$fontTempDir = "$env:TEMP\InconsolataNerdFont"
$fontZip = "$fontTempDir\InconsolataNerdFont.zip"
$fontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Inconsolata.zip"

Write-Host " -> Creating temporary directory..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $fontTempDir -Force | Out-Null

Write-Host " -> Downloading Inconsolata Nerd Font..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $fontUrl -OutFile $fontZip -UseBasicParsing

Write-Host " -> Extracting font files..." -ForegroundColor Yellow
Expand-Archive -Path $fontZip -DestinationPath $fontTempDir -Force

Write-Host " -> Installing font files..." -ForegroundColor Yellow
# Copy all .ttf font files to the fonts directory
$fontFiles = Get-ChildItem -Path $fontTempDir -Filter "*.ttf" -Recurse
foreach ($fontFile in $fontFiles) {
    Copy-Item -Path $fontFile.FullName -Destination "$env:SystemRoot\Fonts" -Force
}

# Also copy to user fonts directory for current user
Copy-Item -Path $fontFiles.FullName -Destination "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" -Force

# Notify applications of the font change
[Win32.Win32Fonts]::SendMessage(0xffff, 0x001D, 0, 0) | Out-Null

Write-Host " -> Cleaning up temporary files..." -ForegroundColor Yellow
Remove-Item -Path $fontTempDir -Recurse -Force

Write-Host "[STEP 6] Configuring WezTerm..." -ForegroundColor Cyan

# Configure WezTerm to use Inconsolata Nerd Font
$wezConfigDir = "$env:APPDATA\wezterm"
$wezConfigFile = "$wezConfigDir\wezterm.lua"

if (-not (Test-Path $wezConfigDir)) {
    New-Item -ItemType Directory -Path $wezConfigDir -Force | Out-Null
}

$wezConfig = @"
-- WezTerm configuration
-- Automatically generated by dev environment setup
return {
  font = wez.font("Inconsolata Nerd Font"),
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

Write-Host "[STEP 8] Enabling WSL subsystem for Phase 2..." -ForegroundColor Cyan
wsl --install --no-distribution

Write-Host "`n[OK] Phase 1 completed successfully!" -ForegroundColor Green