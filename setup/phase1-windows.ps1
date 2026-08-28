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
    "voidtools.Everything", 
    "Flow-Launcher.Flow-Launcher", 
    "glzr-io.glazewm", 
    "Git.Git", 
    "DBeaver.DBeaver.Community", 
    "JanDeDobbeleer.OhMyPosh"
)

foreach ($app in $exeApps) { 
    Write-Host " -> Installing $app..." -ForegroundColor Yellow
    winget install --id $app -e --accept-source-agreements --accept-package-agreements --silent --no-upgrade 
}

Write-Host " -> Installing Windows Terminal..." -ForegroundColor Yellow
winget install --id "9NBLGGH4S0M5" -s msstore --accept-source-agreements --accept-package-agreements --silent

Write-Host " -> Configuring Oh My Posh for PowerShell..." -ForegroundColor Cyan
if (!(Test-Path $PROFILE)) {
    New-Item -ItemType File -Force -Path $PROFILE | Out-Null
}

$line = 'oh-my-posh init pwsh | Invoke-Expression'
if (!(Select-String -Path $PROFILE -Pattern 'oh-my-posh init pwsh' -Quiet)) {
    Add-Content -Path $PROFILE -Value "`r`n$line"
}

Write-Host "[STEP 5] Deploying Inconsolata Nerd Font typography profiles..." -ForegroundColor Cyan
oh-my-posh font install inconsolata

# Register font
$gdi = @"
[DllImport("gdi32.dll", EntryPoint="AddFontResourceW")] public static extern int AddFontResource(string f);
[DllImport("user32.dll")] public static extern int SendMessage(IntPtr w, uint m, IntPtr wp, IntPtr lp);
"@
$fType = Add-Type -MemberDefinition $gdi -Name "Win32Fonts" -Namespace "Win32" -PassThru
[Win32.Win32Fonts]::SendMessage(0xffff, 0x001D, 0, 0) | Out-Null

# Configure Windows Terminal font
$wt = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path $wt) {
    try {
        $cfg = Get-Content -Raw -Path $wt | ConvertFrom-Json
        if ($cfg.profiles.defaults) { 
            $cfg.profiles.defaults | Add-Member -NotePropertyName "font" -NotePropertyValue (@{"face"="Inconsolata Nerd Font"}) -Force 
        } else { 
            $cfg.profiles | Add-Member -NotePropertyName "defaults" -NotePropertyValue (@{"font"=@{"face"="Inconsolata Nerd Font"}}) -Force 
        }
        $cfg | ConvertTo-Json -Depth 100 | Out-File -FilePath $wt -Encoding utf8
    } catch {}
}

# PowerShell profile with Oh My Posh
$pDir = "$HOME\Documents\PowerShell"
if (-not (Test-Path $pDir)) { New-Item -Path $pDir -Type Directory -Force | Out-Null }
'oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json" | Invoke-Expression' | Out-File -FilePath "$pDir\Microsoft.PowerShell_profile.ps1" -Encoding utf8

Write-Host "[STEP 6] Enabling WSL subsystem for Phase 2..." -ForegroundColor Cyan
wsl --install --no-distribution

Write-Host "`n[OK] Phase 1 completed successfully!" -ForegroundColor Green