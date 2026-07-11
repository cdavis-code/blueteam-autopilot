$ErrorActionPreference = 'Stop'

$packageName = 'blueteam-autopilot'
$packageVersion = $env:chocolateyPackageVersion
$githubUser = 'cdavis-code'
$githubRepo = 'blueteam-autopilot'

# Construct the download URL for the release tarball
$tagVersion = $packageVersion -replace '\.0$', '.0'  # Ensure consistent version format
$downloadUrl = "https://github.com/$githubUser/$githubRepo/archive/refs/tags/v$packageVersion.tar.gz"

Write-Host "Installing $packageName v$packageVersion..." -ForegroundColor Cyan
Write-Host "Download URL: $downloadUrl" -ForegroundColor Gray

# Create installation directory
$installDir = "$(Get-ToolsLocation)\$packageName-$packageVersion"
if (Test-Path $installDir) {
    Remove-Item -Recurse -Force $installDir
}
New-Item -ItemType Directory -Path $installDir -Force | Out-Null

# Download and extract the release tarball
$tarballPath = "$env:TEMP\$packageName-$packageVersion.tar.gz"
try {
    Write-Host "Downloading release tarball..." -ForegroundColor Yellow
    Get-ChocolateyWebFile -PackageName $packageName -FileFullPath $tarballPath -Url $downloadUrl -ChecksumType64 'sha256'
    
    Write-Host "Extracting tarball..." -ForegroundColor Yellow
    # Extract .tar.gz
    $tarPath = "$env:TEMP\$packageName-$packageVersion.tar"
    & gzip -d -c $tarballPath | Out-File $tarPath -Encoding byte
    & tar -xf $tarPath -C $installDir --strip-components=1
    
    Remove-Item $tarballPath -Force -ErrorAction SilentlyContinue
    Remove-Item $tarPath -Force -ErrorAction SilentlyContinue
} catch {
    Write-Warning "Failed to download/extract tarball. Falling back to pip install from GitHub..."
    
    # Fallback: pip install directly from GitHub
    $pipUrl = "git+https://github.com/$githubUser/$githubRepo.git@v$packageVersion"
    & python -m pip install --upgrade $pipUrl
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install $packageName"
    }
    
    Write-Host "$packageName v$packageVersion installed successfully via pip" -ForegroundColor Green
    return
}

# Install via pip from the extracted source
Write-Host "Installing Python package from source..." -ForegroundColor Yellow
Push-Location $installDir
try {
    & python -m pip install --upgrade .
    
    if ($LASTEXITCODE -ne 0) {
        throw "pip install failed"
    }
    
    # Create shim batch file in Chocolatey bin directory
    $shimPath = "$(Get-BinRoot)\blueteam.bat"
    $shimContent = @"
@echo off
python -m blueteam %*
"@
    Set-Content -Path $shimPath -Value $shimContent -Encoding ASCII
    
    Write-Host "$packageName v$packageVersion installed successfully" -ForegroundColor Green
    Write-Host "Run 'blueteam' to start the interactive TUI" -ForegroundColor Cyan
} finally {
    Pop-Location
}
