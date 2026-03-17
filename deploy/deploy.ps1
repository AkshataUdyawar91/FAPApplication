# =========================
# FAP Deployment Script
# =========================

Write-Host "Starting Deployment..." -ForegroundColor Green

# Paths (adjust if needed)
$backendProject = "..\backend"
$frontendProject = "..\frontend"

# VM deployment directories
$apiDeployPath = "C:\deploy\FAPAPI"
$uiDeployPath = "C:\deploy\FAPUI"

# -----------------------------
# Step 1 - Build .NET API
# -----------------------------
Write-Host "Publishing .NET API..."

Set-Location $backendProject

dotnet publish -c Release -o $apiDeployPath

if ($LASTEXITCODE -ne 0) {
    Write-Host "API Build Failed!" -ForegroundColor Red
    exit
}

Write-Host "API Published"

# -----------------------------
# Step 2 - Build Flutter Web
# -----------------------------
Write-Host "Building Flutter Web..."

Set-Location $frontendProject

flutter build web

if ($LASTEXITCODE -ne 0) {
    Write-Host "Flutter Build Failed!" -ForegroundColor Red
    exit
}

Write-Host "Flutter Build Successful"

# -----------------------------
# Step 3 - Deploy UI
# -----------------------------
Write-Host "Deploying Flutter UI..."

$flutterBuild = "$frontendProject\build\web\*"

Remove-Item $uiDeployPath\* -Recurse -Force -ErrorAction SilentlyContinue

Copy-Item $flutterBuild -Destination $uiDeployPath -Recurse

Write-Host "UI Deployment Completed"

# -----------------------------
# Step 4 - Restart IIS
# -----------------------------
Write-Host "Restarting IIS..."

iisreset

Write-Host "Deployment Completed Successfully!" -ForegroundColor Cyan