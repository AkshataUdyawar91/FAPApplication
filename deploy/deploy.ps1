# =========================
# FAP Deployment Script
# =========================

Write-Host "Starting Deployment..." -ForegroundColor Green

# Resolve absolute paths relative to this script's location
$scriptDir       = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendProject  = Resolve-Path "$scriptDir\..\backend"
$frontendProject = Resolve-Path "$scriptDir\..\frontend"

# VM deployment directories
$apiDeployPath = "C:\deploy\FAPAPI"
$uiDeployPath  = "$apiDeployPath\wwwroot"

# -----------------------------
# Step 1 - Stop running API first
# -----------------------------
Write-Host "Stopping running API processes..."
Get-Process -Name "dotnet" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process -Name "BajajDocumentProcessing.API" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

# -----------------------------
# Step 2 - Build .NET API to temp folder, then copy
# -----------------------------
Write-Host "Publishing .NET API..."

$tempPublish = "$env:TEMP\FAPAPI_publish"
if (Test-Path $tempPublish) { Remove-Item $tempPublish -Recurse -Force }

Set-Location $backendProject
dotnet publish -c Release -o $tempPublish

if ($LASTEXITCODE -ne 0) {
    Write-Host "API Build Failed!" -ForegroundColor Red
    exit 1
}

# Copy from temp to deploy path (overwrite locked files after process is stopped)
Write-Host "Copying published files to $apiDeployPath..."
if (!(Test-Path $apiDeployPath)) { New-Item -ItemType Directory -Path $apiDeployPath -Force | Out-Null }
Copy-Item "$tempPublish\*" -Destination $apiDeployPath -Recurse -Force
Remove-Item $tempPublish -Recurse -Force

Write-Host "API Published"

# -----------------------------
# Step 2 - Build Flutter Web
# -----------------------------
Write-Host "Building Flutter Web..."

Set-Location $frontendProject
flutter build web --release --dart-define=API_BASE_URL=/api

if ($LASTEXITCODE -ne 0) {
    Write-Host "Flutter Build Failed!" -ForegroundColor Red
    exit 1
}

Write-Host "Flutter Build Successful"

# -----------------------------
# Step 3 - Deploy UI
# -----------------------------
Write-Host "Deploying Flutter UI..."

$flutterBuildSrc = "$frontendProject\build\web"

if (Test-Path $uiDeployPath) {
    Remove-Item $uiDeployPath -Recurse -Force
}
New-Item -ItemType Directory -Path $uiDeployPath -Force | Out-Null

Copy-Item "$flutterBuildSrc\*" -Destination $uiDeployPath -Recurse -Force

Write-Host "UI Deployment Completed"

# -----------------------------
# Step 4 - Restart API (Kestrel)
# -----------------------------
Write-Host "Restarting API..."

Get-Process -Name "dotnet" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

$apiExe = "$apiDeployPath\BajajDocumentProcessing.API.exe"
if (Test-Path $apiExe) {
    Start-Process -FilePath $apiExe -WorkingDirectory $apiDeployPath -WindowStyle Hidden
    Write-Host "API started. App available at http://localhost:5000" -ForegroundColor Cyan
} else {
    Write-Host "API exe not found. Start manually: dotnet $apiDeployPath\BajajDocumentProcessing.API.dll" -ForegroundColor Yellow
}

Write-Host "Deployment Completed Successfully!" -ForegroundColor Cyan
