# phase1-windows.ps1 - Windows Configuration & Applications
param(
    [string]$WslUser = "user"
)

$script:setupWarnings = New-Object System.Collections.Generic.List[string]
$script:wingetFailures = New-Object System.Collections.Generic.List[string]

function Add-SetupWarning {
    param([string]$Message)
    Write-Warning $Message
    $script:setupWarnings.Add($Message) | Out-Null
}

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
    Add-SetupWarning "Network unavailable after $netTimeout attempts - continuing anyway"
}

Write-Host "[STEP 4] Downloading and processing app manifests via WinGet..." -ForegroundColor Cyan
$exeApps = @(
    "7zip.7zip",
    "DuongDieuPhap.ImageGlass.MSI",
    "VideoLAN.VLC",
    "Flow-Launcher.Flow-Launcher",
    "Git.Git",
    "wez.wezterm",
    "twpayne.chezmoi",
    "Anomaly.OpenCode",
    "Anomaly.OpenCode.Desktop"
)

$wingetAvailable = [bool](Get-Command winget.exe -ErrorAction SilentlyContinue)
if (-not $wingetAvailable) {
    Add-SetupWarning "WinGet is not available; applications were not installed."
}

foreach ($app in $exeApps) {
    if (-not $wingetAvailable) {
        break
    }
    Write-Host " -> Installing $app..." -ForegroundColor Yellow
    winget install --id $app -e --accept-source-agreements --accept-package-agreements --silent --no-upgrade
    if ($LASTEXITCODE -ne 0) {
        $message = "WinGet failed for $app (exit code $LASTEXITCODE)."
        $script:wingetFailures.Add($message) | Out-Null
        Add-SetupWarning $message
    }
}

if ($script:wingetFailures.Count -gt 0) {
    Write-Warning "Some applications could not be installed. Review the warnings above before continuing."
}

Write-Host " -> Disabling the Windows OpenCode background service..." -ForegroundColor Yellow
$windowsOpenCode = (Get-Command opencode.exe -ErrorAction SilentlyContinue).Path
if (-not $windowsOpenCode) {
    $windowsOpenCode = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" `
        -Filter "opencode.exe" `
        -Recurse `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}
if ($windowsOpenCode) {
    # The shared server lives in WSL. Leaving a Windows server running would
    # take over localhost and make Desktop talk to the wrong instance.
    & $windowsOpenCode service stop 2>$null | Out-Null
    & $windowsOpenCode service set disabled true 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Add-SetupWarning "Could not disable the Windows OpenCode background service."
    }
    else {
        Write-Host "   Windows OpenCode service disabled; WSL is the only server." -ForegroundColor Cyan
    }
}
else {
    Add-SetupWarning "opencode.exe not found; could not disable the Windows background service."
}

Write-Host " -> Enabling WezTerm autostart..." -ForegroundColor Yellow
$weztermExe = (Get-Command wezterm-gui.exe -ErrorAction SilentlyContinue).Path
if (-not $weztermExe) {
    $weztermExe = "$env:ProgramFiles\WezTerm\wezterm-gui.exe"
}
if (Test-Path -LiteralPath $weztermExe) {
    $startupDir = [Environment]::GetFolderPath('Startup')
    $weztermShortcut = Join-Path $startupDir 'WezTerm.lnk'
    $wshell = New-Object -ComObject WScript.Shell
    $shortcut = $wshell.CreateShortcut($weztermShortcut)
    $shortcut.TargetPath = $weztermExe
    $shortcut.WorkingDirectory = $env:USERPROFILE
    $shortcut.Description = 'Launch WezTerm on the console virtual desktop'
    $shortcut.Save()
    Write-Host "   WezTerm autostart enabled." -ForegroundColor Cyan
}
else {
    Add-SetupWarning "WezTerm executable not found at $weztermExe; autostart not configured."
}

Write-Host " -> Registering ImageGlass as image viewer..." -ForegroundColor Yellow
$imageGlassExe = @(
    "$env:LOCALAPPDATA\Programs\ImageGlass\ImageGlass.exe",
    "$env:ProgramFiles\ImageGlass\ImageGlass.exe",
    "$env:ProgramFiles\ImageGlass 10\ImageGlass.exe"
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if ($imageGlassExe) {
    $imageProgId = "ImageGlass.Viewer"
    $imageProgBase = "HKCU:\Software\Classes\$imageProgId"
    New-Item -Path "$imageProgBase\shell\open\command" -Force | Out-Null
    Set-ItemProperty -Path $imageProgBase -Name "(default)" -Value "ImageGlass image"
    Set-ItemProperty -Path "$imageProgBase\shell\open\command" -Name "(default)" -Value ('"' + $imageGlassExe + '" "%1"')

    $imageExts = ".jpg", ".jpeg", ".jpe", ".jfif", ".png", ".gif", ".bmp", ".webp", ".tif", ".tiff", ".ico", ".svg", ".avif", ".heic", ".jxl"
    foreach ($ext in $imageExts) {
        New-Item -Path "HKCU:\Software\Classes\$ext" -Force | Out-Null
        Set-ItemProperty -Path "HKCU:\Software\Classes\$ext" -Name "(default)" -Value $imageProgId
        $openWith = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("Software\Classes\$ext\OpenWithProgids")
        $openWith.SetValue($imageProgId, [byte[]]@(), [Microsoft.Win32.RegistryValueKind]::None)
        $openWith.Close()
    }
    Write-Host "   ImageGlass registered; setting it as the default image handler..." -ForegroundColor Cyan

    try {
        $userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $ucScriptPath = Join-Path $env:TEMP "set-image-assoc.ps1"
        $ucLines = @("`$ErrorActionPreference = 'SilentlyContinue'")
        foreach ($ext in $imageExts) {
            $ucLines += "Remove-Item -LiteralPath 'Registry::HKEY_USERS\$userSid\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\UserChoice' -Recurse -Force"
        }
        Set-Content -Path $ucScriptPath -Value ($ucLines -join "`r`n") -Encoding ascii

        $ucAction = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ucScriptPath`""
        $ucPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        Register-ScheduledTask -TaskName "SetImageAssoc" -Action $ucAction -Principal $ucPrincipal -Force | Out-Null
        Start-ScheduledTask -TaskName "SetImageAssoc"
        Start-Sleep -Seconds 5
        Unregister-ScheduledTask -TaskName "SetImageAssoc" -Confirm:$false
        Remove-Item -LiteralPath $ucScriptPath -Force -ErrorAction SilentlyContinue

        Add-Type @"
using System;
using System.Runtime.InteropServices;
public class SetImageAssocShNotify {
  [DllImport("shell32.dll")] public static extern void SHChangeNotify(int eventId, uint flags, IntPtr item1, IntPtr item2);
}
"@
        [SetImageAssocShNotify]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)

        $missingAssociations = @()
        foreach ($ext in $imageExts) {
            $key = Get-Item -LiteralPath "HKCU:\Software\Classes\$ext" -ErrorAction SilentlyContinue
            $defaultValue = if ($key) { $key.GetValue('') } else { $null }
            if ($defaultValue -ne $imageProgId) {
                $missingAssociations += $ext
            }
        }
        if ($missingAssociations.Count -gt 0) {
            Add-SetupWarning "ImageGlass association was not applied for: $($missingAssociations -join ', ')"
        }
        else {
            Write-Host "   ImageGlass is now the default image handler." -ForegroundColor Cyan
        }
    }
    catch {
        Add-SetupWarning "Could not set ImageGlass as default: $($_.Exception.Message)"
    }
}
else {
    Add-SetupWarning "ImageGlass executable not found; image association not configured."
}

Write-Host "[STEP 5] Deploying JetBrains Mono Nerd Font for WezTerm..." -ForegroundColor Cyan

$fontTempDir = "$env:TEMP\JetBrainsMonoNerdFont"
$fontZip = "$fontTempDir\JetBrainsMono.zip"
$fontVersion = "v3.5.1"
$fontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/$fontVersion/JetBrainsMono.zip"
$fontChecksumUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/$fontVersion/SHA-256.txt"
$previousEap = $ErrorActionPreference

try {
    $ErrorActionPreference = "Stop"

    Write-Host " -> Creating temporary directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $fontTempDir -Force | Out-Null

    Write-Host " -> Downloading JetBrains Mono Nerd Font..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $fontUrl -OutFile $fontZip -UseBasicParsing
    Invoke-WebRequest -Uri $fontChecksumUrl -OutFile "$fontTempDir\SHA-256.txt" -UseBasicParsing

    $checksumLine = Get-Content "$fontTempDir\SHA-256.txt" |
        Where-Object { $_ -match '\s+JetBrainsMono\.zip$' } |
        Select-Object -First 1
    $expectedHash = if ($checksumLine) { ($checksumLine -split '\s+')[0].ToLowerInvariant() } else { "" }
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $fontZip).Hash.ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($expectedHash) -or $actualHash -ne $expectedHash) {
        throw "JetBrainsMono.zip checksum verification failed."
    }

    Write-Host " -> Extracting font files..." -ForegroundColor Yellow
    Expand-Archive -Path $fontZip -DestinationPath $fontTempDir -Force

    $fontFiles = @(Get-ChildItem -Path $fontTempDir -Filter "*.ttf" -Recurse)
    if ($fontFiles.Count -eq 0) {
        throw "No .ttf files found in the downloaded archive."
    }

    Write-Host " -> Installing font files..." -ForegroundColor Yellow
    $userFontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    if (-not (Test-Path $userFontDir)) {
        New-Item -ItemType Directory -Path $userFontDir -Force | Out-Null
    }

    $fontRegPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

    foreach ($fontFile in $fontFiles) {
        $destination = Join-Path $userFontDir $fontFile.Name
        Copy-Item -LiteralPath $fontFile.FullName -Destination $destination -Force

        # One registry value per face. The value data must be the full font path
        # for per-user fonts; using the family name for every face overwrote
        # Bold/Italic entries with the last file.
        $registryName = "$($fontFile.BaseName) (TrueType)"
        New-ItemProperty -Path $fontRegPath -Name $registryName -Value $destination -PropertyType String -Force | Out-Null
    }

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
        Write-Warning " -> Failed to notify system of font change (can be ignored); font files are registered"
    }

    Write-Host "[OK] JetBrains Mono Nerd Font installed for the current user." -ForegroundColor Green
}
catch {
    Add-SetupWarning "JetBrains Mono Nerd Font installation failed: $($_.Exception.Message)"
}
finally {
    $ErrorActionPreference = $previousEap
    Write-Host " -> Cleaning up temporary files..." -ForegroundColor Yellow
    if (Test-Path $fontTempDir) {
        Remove-Item -Path $fontTempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "[STEP 6] Configuring PowerShell profile..." -ForegroundColor Cyan

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
    Start-Process -FilePath "powershell.exe" -Verb RunAs
    Exit
}

Write-Host "Running with administrator privileges" -ForegroundColor Green

function ll {
    Get-ChildItem -Force
}

function gs {
    git status @args
}

function gc {
    git commit @args
}

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

Write-Host "[STEP 7] Creating PowerShell administrator shortcut..." -ForegroundColor Cyan

$startMenuDir = [Environment]::GetFolderPath('CommonPrograms')
$shortcutPath = Join-Path $startMenuDir "PowerShell Admin.lnk"

$wshell = New-Object -ComObject WScript.Shell
$shortcut = $wshell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$shortcut.Arguments = "-ExecutionPolicy Bypass"
$shortcut.WorkingDirectory = "$env:USERPROFILE"
$shortcut.Description = "PowerShell with admin privileges for dev environment tasks"
$shortcut.IconLocation = "$env:SystemRoot\System32\shell32.dll,176"
$shortcut.Save()

# Mark the .lnk as "Run as administrator" (byte 21, bit 0x20)
$lnkBytes = [System.IO.File]::ReadAllBytes($shortcutPath)
$lnkBytes[0x15] = $lnkBytes[0x15] -bor 0x20
[System.IO.File]::WriteAllBytes($shortcutPath, $lnkBytes)

Write-Host "[OK] PowerShell admin shortcut created in Start Menu" -ForegroundColor Green

Write-Host "[STEP 8] Installing Windows-side helper and applying dotfiles..." -ForegroundColor Cyan

$virtualDesktopOk = & "$PSScriptRoot\scripts\install_virtualdesktop.ps1"
if (-not $virtualDesktopOk) {
    Add-SetupWarning "VirtualDesktop.exe is unavailable; WezTerm/OpenCode will not be moved to the «Разработка» desktop."
}

$env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
$chezmoiExe = (Get-Command chezmoi.exe -ErrorAction SilentlyContinue).Path
if (-not $chezmoiExe) {
    $chezmoiExe = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "chezmoi.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}

if ($chezmoiExe) {
    $chezmoiSource = & $chezmoiExe source-path 2>$null
    if (-not $chezmoiSource -or -not (Test-Path -LiteralPath $chezmoiSource)) {
        & $chezmoiExe init Viktor-V/dotfiles
        if ($LASTEXITCODE -ne 0) {
            throw "chezmoi init failed with exit code $LASTEXITCODE."
        }
    }

    & $chezmoiExe apply
    if ($LASTEXITCODE -ne 0) {
        throw "chezmoi apply failed with exit code $LASTEXITCODE."
    }

    Write-Host "[OK] Windows-side dotfiles applied" -ForegroundColor Green
}
else {
    Add-SetupWarning "chezmoi.exe not found; Windows-side dotfiles were not applied."
}

Write-Host "[STEP 9] Checking WSL2 prerequisites..." -ForegroundColor Cyan

Write-Host " -> Installing WSL2..." -ForegroundColor Yellow
wsl --install --no-distribution | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host " -> WSL2 is ready." -ForegroundColor Green
} else {
    Write-Host "[WARNING] WSL2 install returned exit code $LASTEXITCODE." -ForegroundColor Red
    Write-Host "  If you see a virtualization error, enable VT-x/AMD-V in your BIOS/UEFI settings." -ForegroundColor Yellow
}

Write-Host "[STEP 10] Configuring lid-close and lock behavior..." -ForegroundColor Cyan

$scheme = ([regex]::Match((powercfg /getactivescheme), '[0-9a-fA-F-]{36}')).Value
if (-not $scheme) {
    $scheme = 'SCHEME_CURRENT'
}

# The lid action is hidden by default on some laptops; unhide it before setting.
powercfg -attributes 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 -ATTRIB_HIDE

# Closing the lid should keep the system running.
# 0 = Do nothing for the lid action.
powercfg /setacvalueindex $scheme SUB_BUTTONS LIDACTION 0
powercfg /setdcvalueindex $scheme SUB_BUTTONS LIDACTION 0

# Keep the machine awake while it is plugged in or on battery.
powercfg /setacvalueindex $scheme SUB_SLEEP STANDBYIDLE 0
powercfg /setdcvalueindex $scheme SUB_SLEEP STANDBYIDLE 0
powercfg /setacvalueindex $scheme SUB_SLEEP HIBERNATEIDLE 0
powercfg /setdcvalueindex $scheme SUB_SLEEP HIBERNATEIDLE 0

# Turn the display off after one hour on AC and after 15 minutes on battery.
# The lid action stays "do nothing", so closing the lid only turns the panel
# off and OpenCode/WSL keep running.
powercfg /setacvalueindex $scheme SUB_VIDEO VIDEOIDLE 3600
powercfg /setdcvalueindex $scheme SUB_VIDEO VIDEOIDLE 900
powercfg /setactive $scheme

# Lock after one hour of inactivity. The display-off timeout above handles the
# monitor; this screensaver handles the lock screen.
$desktop = 'HKCU:\Control Panel\Desktop'
Set-ItemProperty -Path $desktop -Name ScreenSaveActive -Value '1' -Force
Set-ItemProperty -Path $desktop -Name ScreenSaverIsSecure -Value '1' -Force
Set-ItemProperty -Path $desktop -Name ScreenSaveTimeOut -Value '3600' -Force
Set-ItemProperty -Path $desktop -Name SCRNSAVE.EXE -Value 'C:\Windows\System32\scrnsave.scr' -Force

Write-Host " -> Lid close: do nothing; display off after 1h AC / 15m battery; lock after 1h." -ForegroundColor Cyan

Write-Host "[STEP 11] Setting time zone and syncing clock..." -ForegroundColor Cyan
tzutil /s "FLE Standard Time"
Set-Service w32time -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service w32time -ErrorAction SilentlyContinue
w32tm /resync /force | Out-Null
if ($LASTEXITCODE -ne 0) {
    Add-SetupWarning "Clock resync returned exit code $LASTEXITCODE."
}
Write-Host " -> Time zone: FLE Standard Time; clock resynced." -ForegroundColor Cyan

Write-Host "[STEP 12] Setting date/time display format..." -ForegroundColor Cyan

$intl = 'HKCU:\Control Panel\International'
Set-ItemProperty -Path $intl -Name 'sShortDate' -Value 'dd.MM.yyyy' -Force
Set-ItemProperty -Path $intl -Name 'sShortTime' -Value 'HH:mm' -Force
Set-ItemProperty -Path $intl -Name 'sTimeFormat' -Value 'HH:mm' -Force

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class IntlNotify {
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
}
"@
$result = [UIntPtr]::Zero
[IntlNotify]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, 'intl', 2, 1000, [ref]$result) | Out-Null

Write-Host " -> Date/time format: HH:mm and dd.MM.yyyy." -ForegroundColor Cyan

Write-Host "[STEP 13] Configuring OpenCode Desktop startup..." -ForegroundColor Cyan

$opencodeConfigDir = Join-Path $env:USERPROFILE ".config\opencode"
New-Item -ItemType Directory -Path $opencodeConfigDir -Force | Out-Null

# The shared OpenCode server now runs inside WSL (set up by Phase 2).
# Remove the old Windows-side background service shortcut if it exists.
$ws = New-Object -ComObject WScript.Shell
$startup = [Environment]::GetFolderPath('Startup')
$legacyServiceLnk = Join-Path $startup 'OpenCode Service.lnk'
if (Test-Path -LiteralPath $legacyServiceLnk) {
    Remove-Item -LiteralPath $legacyServiceLnk -Force -ErrorAction SilentlyContinue
}
$legacyStartService = Join-Path $opencodeConfigDir 'start-service.ps1'
if (Test-Path -LiteralPath $legacyStartService) {
    Remove-Item -LiteralPath $legacyStartService -Force -ErrorAction SilentlyContinue
}

# Remove the old Windows-server AGENTS.md if it was written by this setup.
$legacyAgents = Join-Path $opencodeConfigDir 'AGENTS.md'
if (Test-Path -LiteralPath $legacyAgents) {
    $legacyAgentsContent = Get-Content -LiteralPath $legacyAgents -Raw -ErrorAction SilentlyContinue
    if ($legacyAgentsContent -match 'The OpenCode server runs on Windows') {
        Remove-Item -LiteralPath $legacyAgents -Force -ErrorAction SilentlyContinue
    }
}

$desktopScript = Join-Path $opencodeConfigDir 'start-opencode-desktop.ps1'
$desktopContent = @'
$ErrorActionPreference = 'SilentlyContinue'
$app = Join-Path $env:LOCALAPPDATA 'Programs\@opencode-aidesktop\OpenCode.exe'
$helper = Join-Path $env:USERPROFILE '.config\wezterm\move-wezterm-to-desktop.ps1'
if (Test-Path -LiteralPath $app) {
    # Wait briefly for the WSL OpenCode server, but do not block the desktop forever.
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline) {
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $tcp.Connect('127.0.0.1', 4096)
            $tcp.Close()
            break
        }
        catch {
            Start-Sleep -Seconds 1
        }
    }
    $p = Start-Process -FilePath $app -PassThru
    if ($p) { & $helper -ProcessId $p.Id }
}
'@
$desktopContent | Set-Content -LiteralPath $desktopScript -Encoding utf8

$desktopLnkPath = Join-Path $startup 'OpenCode.lnk'
$desktopLnk = $ws.CreateShortcut($desktopLnkPath)
$desktopLnk.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$desktopLnk.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$desktopScript`""
$desktopLnk.WorkingDirectory = $env:USERPROFILE
$desktopLnk.Description = 'OpenCode Desktop on Разработка'
$desktopLnk.Save()
Write-Host " -> OpenCode Desktop startup configured (server runs in WSL)." -ForegroundColor Cyan

if ($script:setupWarnings.Count -gt 0) {
    Write-Host "`n[WARN] Phase 1 completed with $($script:setupWarnings.Count) warning(s):" -ForegroundColor Yellow
    foreach ($warning in $script:setupWarnings) {
        Write-Host " - $warning" -ForegroundColor Yellow
    }
    Write-Host "[OK] Phase 1 core steps completed; review the warnings above." -ForegroundColor Yellow
}
else {
    Write-Host "`n[OK] Phase 1 completed successfully!" -ForegroundColor Green
}
