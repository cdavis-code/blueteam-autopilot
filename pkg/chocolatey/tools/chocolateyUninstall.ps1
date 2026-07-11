$ErrorActionPreference = 'Stop'

$packageName = 'blueteam-autopilot'
$packageVersion = $env:chocolateyPackageVersion

Write-Host "Uninstalling $packageName v$packageVersion..." -ForegroundColor Cyan

# Uninstall Python package via pip
try {
    & python -m pip uninstall -y $packageName
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "$packageName uninstalled successfully" -ForegroundColor Green
    } else {
        Write-Warning "pip uninstall returned non-zero exit code"
    }
} catch {
    Write-Warning "Failed to uninstall via pip: $_"
}

# Remove shim batch file
$shimPath = "$(Get-BinRoot)\blueteam.bat"
if (Test-Path $shimPath) {
    Remove-Item $shimPath -Force
    Write-Host "Removed shim: $shimPath" -ForegroundColor Gray
}

# Remove installation directory
$installDir = "$(Get-ToolsLocation)\$packageName-$packageVersion"
if (Test-Path $installDir) {
    Remove-Item -Recurse -Force $installDir
    Write-Host "Removed installation directory: $installDir" -ForegroundColor Gray
}
