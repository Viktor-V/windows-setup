# setup.ps1 - Main Dev Environment Setup Orchestrator
param(
    [switch]$SkipPhase1,
    [switch]$SkipPhase2
)

$ErrorActionPreference = "Stop"
$taskName = "ResumeDevSetup"
$stageDir = Join-Path $env:USERPROFILE "WSL_Stage"

Clear-Host
Write-Host @"
========================================
   AUTOMATIC SOFTWARE & DEV ENVIRONMENT SETUP
========================================
"@ -ForegroundColor Cyan

# Check for administrator privileges
$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$windowsPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
$isAdmin = $windowsPrincipal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdmin) {
    Write-Host "[ERROR] This script requires Administrator privileges!" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator." -ForegroundColor Yellow
    Read-Host "Press Enter to exit..."
    exit 1
}

# Create staging directory
New-Item -Path $stageDir -ItemType Directory -Force | Out-Null

# Ask for password only on the first run, or when the saved password is missing
$passwordFile = Join-Path $stageDir "password.sec"

if (-not $SkipPhase1 -or -not (Test-Path $passwordFile)) {
    Write-Host "`n[SECURITY] Creating WSL user account" -ForegroundColor Yellow
    Write-Host "Enter password for user 'viktorv':" -ForegroundColor White

    $securePassword = Read-Host -AsSecureString
    $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    )

    if ([string]::IsNullOrWhiteSpace($password)) {
        Write-Host "[ERROR] Password cannot be empty!" -ForegroundColor Red
        Read-Host "Press Enter to exit..."
        exit 1
    }

    # The encrypted value can be decrypted only by the same Windows user
    $securePassword |
        ConvertFrom-SecureString |
        Out-File -FilePath $passwordFile -Force

    Write-Host "[OK] Password saved for Phase 2" -ForegroundColor Green
}

# PHASE 1: Windows Setup
if (-not $SkipPhase1) {
    Write-Host "`n====================================================" -ForegroundColor Cyan
    Write-Host "   PHASE 1: Windows Configuration & Applications" -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan

    & "$PSScriptRoot\phase1-windows.ps1"

    if (-not $?) {
        Write-Host "[ERROR] Phase 1 failed!" -ForegroundColor Red
        Read-Host "Press Enter to exit..."
        exit 1
    }

    Write-Host "`n====================================================" -ForegroundColor Yellow
    Write-Host " MANDATORY REBOOT REQUIRED TO INITIALIZE WSL2 LAYERS" -ForegroundColor Yellow
    Write-Host "====================================================" -ForegroundColor Yellow

    $choice = Read-Host "Restart now? (Y/n)"

    if ($choice -ne "n" -and $choice -ne "N") {
        # Mark Phase 1 as completed
        "Phase 1 completed at $(Get-Date)" |
            Out-File -FilePath (Join-Path $stageDir "phase1_done.txt") -Encoding ascii

        # Register an elevated scheduled task for Phase 2
        $scriptPath = $MyInvocation.MyCommand.Path
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name

        $action = New-ScheduledTaskAction `
            -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -SkipPhase1" `
            -WorkingDirectory $PSScriptRoot

        $trigger = New-ScheduledTaskTrigger `
            -AtLogOn `
            -User $currentUser

        # Small delay gives Windows and WSL services time to initialize
        $trigger.Delay = "PT20S"

        $principal = New-ScheduledTaskPrincipal `
            -UserId $currentUser `
            -LogonType Interactive `
            -RunLevel Highest

        $settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -StartWhenAvailable `
            -ExecutionTimeLimit (New-TimeSpan -Hours 6)

        Register-ScheduledTask `
            -TaskName $taskName `
            -Action $action `
            -Trigger $trigger `
            -Principal $principal `
            -Settings $settings `
            -Description "Continue automatic development environment setup after reboot" `
            -Force | Out-Null

        # Remove old Run-key entry if it exists
        $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        Remove-ItemProperty `
            -Path $runKey `
            -Name $taskName `
            -Force `
            -ErrorAction SilentlyContinue

        Write-Host "[OK] Elevated auto-start task created." -ForegroundColor Green
        Write-Host "Your PC will restart automatically in 10 seconds." -ForegroundColor Yellow

        Start-Sleep -Seconds 10
        Restart-Computer -Force
        exit
    }
    else {
        Write-Host "Please restart manually and run PowerShell as Administrator:" -ForegroundColor Cyan
        Write-Host ".\setup.ps1 -SkipPhase1" -ForegroundColor White
        Read-Host "Press Enter to close..."
        exit
    }
}

# PHASE 2: WSL & Dev Tools
$phase1Marker = Join-Path $stageDir "phase1_done.txt"

if (-not $SkipPhase2 -or (Test-Path $phase1Marker)) {
    Write-Host "`n====================================================" -ForegroundColor Cyan
    Write-Host "   PHASE 2: WSL Environment & Development Tools" -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan

    # Read saved password
    if (Test-Path $passwordFile) {
        $encryptedPassword = Get-Content $passwordFile | ConvertTo-SecureString
        $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($encryptedPassword)
        )
    }
    elseif (-not $password) {
        Write-Host "Enter password for user 'viktorv':" -ForegroundColor White
        $securePassword = Read-Host -AsSecureString
        $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        )
    }

    try {
        & "$PSScriptRoot\phase2-wsl.ps1" -Password $password

        if (-not $?) {
            throw "Phase 2 script returned an error."
        }

        # Cleanup only after Phase 2 succeeds
        Unregister-ScheduledTask `
            -TaskName $taskName `
            -Confirm:$false `
            -ErrorAction SilentlyContinue

        $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        Remove-ItemProperty `
            -Path $runKey `
            -Name $taskName `
            -Force `
            -ErrorAction SilentlyContinue

        Remove-Item `
            -Path $stageDir `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue

        Write-Host "`n====================================================" -ForegroundColor Green
        Write-Host " SUCCESS! Everything is fully installed and configured." -ForegroundColor Green
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host " 1. Portainer UI is live at http://localhost:9000" -ForegroundColor Cyan
        Write-Host " 2. Open Debian terminal to see Fish + Inconsolata Font!" -ForegroundColor Cyan
        Write-Host " 3. Login: viktorv" -ForegroundColor Cyan
        Write-Host "====================================================" -ForegroundColor Green
    }
    catch {
        Write-Host "`n[ERROR] Phase 2 failed:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host "The scheduled task was kept, so setup can be retried after the next login." -ForegroundColor Yellow
        Read-Host "Press Enter to close..."
        exit 1
    }
}

Read-Host "Press Enter to close..."