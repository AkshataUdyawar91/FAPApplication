# Packages the Teams app manifest and icons into a ZIP for sideloading.
# Usage: .\package.ps1
# Output: manifest.zip in the current directory

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputZip = Join-Path $scriptDir "manifest.zip"

# Remove old zip if exists
if (Test-Path $outputZip) {
    Remove-Item $outputZip -Force
}

# Validate required files exist
$requiredFiles = @("manifest.json", "color.png", "outline.png")
foreach ($file in $requiredFiles) {
    $filePath = Join-Path $scriptDir $file
    if (-not (Test-Path $filePath)) {
        Write-Error "Missing required file: $file"
        Write-Host "Ensure color.png (192x192) and outline.png (32x32) exist in this directory."
        exit 1
    }
}

# Create zip
Compress-Archive -Path (Join-Path $scriptDir "manifest.json"), (Join-Path $scriptDir "color.png"), (Join-Path $scriptDir "outline.png") -DestinationPath $outputZip -Force

Write-Host "Created $outputZip"
Write-Host "Sideload this ZIP in Teams Admin Center or Teams Developer Portal."
