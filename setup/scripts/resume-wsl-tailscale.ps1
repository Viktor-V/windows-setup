$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\windows-setup\resume.log'
New-Item -ItemType Directory -Path (Split-Path -Parent $log) -Force | Out-Null
function Log($m) { "$([datetime]::Now.ToString('s')) $m" | Add-Content -LiteralPath $log -Encoding UTF8 }

Log 'resume task start'
Start-Sleep -Seconds 5

$tailscale = Get-Service Tailscale -ErrorAction SilentlyContinue
if ($tailscale) {
    Restart-Service Tailscale -Force -ErrorAction SilentlyContinue
    Log 'Tailscale service restarted'
}

$wsl = "$env:SystemRoot\System32\wsl.exe"
& $wsl -d Debian --exec /bin/true 2>$null
Log "WSL boot exit=$LASTEXITCODE"
Start-Sleep -Seconds 2

& $wsl -d Debian --exec sudo systemctl restart tailscaled 2>$null
Log "WSL tailscaled restart exit=$LASTEXITCODE"

& $wsl -d Debian --exec sudo systemctl start ssh herdr 2>$null
Log "WSL services start exit=$LASTEXITCODE"

Log 'resume task done'
