#!/bin/bash

# Script to create PowerShell admin shortcut on Windows desktop
# This is run from within the Windows Phase 1 to create a convenient admin launch

echo "Creating PowerShell administrator shortcut..."

# Get the current user's desktop path
DESKTOP="$env:USERPROFILE\Desktop"

# Create the shortcut using PowerShell (this must run with admin to set up properly)
$target = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\admin_profile.ps1`""
$workingDir = $env:USERPROFILE
$icon = "$env:SystemRoot\System32\shell32.dll,-176"
$description = "PowerShell with admin capabilities for dev environment setup"

# Create a shortcut (.lnk) - we'll use the .lnk creation method or PowerShell CreateShortcut
# Actually, let's create a .ps1 wrapper that requests elevation

$shortcutPath = Join-Path $DESKTOP "DevSetup PowerShell Admin.lnk"

# Check if we should use the Shell link creation approach
# For simplicity, we'll create a .ps1 file that can be right-clicked -> Run as Admin
# Or we can use the COM object to create the shortcut

try {
    # Use COM object to create proper Windows shortcut
    $WScriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $WScriptShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $target
    $shortcut.Arguments = $arguments
    $shortcut.WorkingDirectory = $workingDir
    $shortcut.IconLocation = $icon
    $shortcut.Description = $description
    $shortcut.Save()
    
    Write-Host "[OK] PowerShell admin shortcut created at: $shortcutPath" -ForegroundColor Green
}
catch {
    Write-Host "[WARN] Could not create shortcut automatically. Please create manually:" -ForegroundColor Yellow
    Write-Host "Right-click on PowerShell icon -> Properties -> Advanced -> Check 'Run as administrator'" -ForegroundColor Cyan
}