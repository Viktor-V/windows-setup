$ErrorActionPreference = 'Stop'

$dir = Join-Path $env:LOCALAPPDATA 'Programs\VirtualDesktop'
$exe = Join-Path $dir 'VirtualDesktop.exe'

$build = [Environment]::OSVersion.Version.Build
if ($build -ge 26100) {
    $asset = 'VirtualDesktop11-24H2.exe'
    $expectedHash = '8334b529d19e71662950821c91ed996a0e92df41c8d0a077e95151aa7041cb35'
}
elseif ($build -ge 22000) {
    $asset = 'VirtualDesktop11.exe'
    $expectedHash = 'f6532db79f6f0e4018ce77f08805d3fd3f7bb076cbfbac0ac8189fe5376d9e82'
}
else {
    Write-Warning "VirtualDesktop.exe supports Windows 11 only; current build is $build. Skipping."
    return $false
}

if (Test-Path -LiteralPath $exe) {
    Write-Host ' -> VirtualDesktop.exe is already installed.' -ForegroundColor Green
    return $true
}

$url = "https://github.com/MScholtes/VirtualDesktop/releases/download/V1.21/$asset"

try {
    Write-Host " -> Downloading $asset..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Invoke-WebRequest -Uri $url -OutFile $exe -UseBasicParsing

    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $exe).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash) {
        Remove-Item -LiteralPath $exe -Force -ErrorAction SilentlyContinue
        throw "VirtualDesktop.exe checksum verification failed."
    }

    Write-Host ' -> VirtualDesktop.exe installed.' -ForegroundColor Green
    return $true
}
catch {
    Write-Warning "Could not install VirtualDesktop.exe: $($_.Exception.Message)"
    return $false
}
