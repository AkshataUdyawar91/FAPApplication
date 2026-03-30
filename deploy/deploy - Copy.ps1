# =============================================================
# FAP Deployment Script
# Supports: HTTP (port 80) and HTTPS (port 7001)
# Works inside and outside the VM (binds to 0.0.0.0)
# =============================================================

param(
    [string]$ApiUrl = "http://0.0.0.0:5000;https://0.0.0.0:8000;https://0.0.0.0:7001",
    [string]$PublicBaseUrl = "http://localhost"   # Change to VM IP or domain for external access
)

$ErrorActionPreference = "Stop"

Write-Host "Starting FAP Deployment..." -ForegroundColor Green

# Resolve absolute paths relative to this script's location
$scriptDir      = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot       = Resolve-Path "$scriptDir\.."
$backendSln     = "$repoRoot\backend"
$frontendDir    = "$repoRoot\frontend"

# Deployment directories on VM
$apiDeployPath  = "C:\deploy\FAPAPI"
$uiDeployPath   = "$apiDeployPath\wwwroot"

# -----------------------------
# Step 1 - Stop running API
# -----------------------------
Write-Host "`n[Step 1] Stopping running API processes..." -ForegroundColor Yellow
Get-Process -Name "BajajDocumentProcessing.API" -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process -Name "dotnet" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3
Write-Host "Processes stopped." -ForegroundColor Green

# -----------------------------
# Step 2 - Publish .NET API
# -----------------------------
Write-Host "`n[Step 2] Publishing .NET API..." -ForegroundColor Yellow

$tempPublish = "$env:TEMP\FAPAPI_publish"
if (Test-Path $tempPublish) { Remove-Item $tempPublish -Recurse -Force }

Push-Location $backendSln
try {
    dotnet publish src\BajajDocumentProcessing.API -c Release -o $tempPublish
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed" }
} finally {
    Pop-Location
}

Write-Host "Copying published files to $apiDeployPath..." -ForegroundColor Yellow
if (!(Test-Path $apiDeployPath)) { New-Item -ItemType Directory -Path $apiDeployPath -Force | Out-Null }
Copy-Item "$tempPublish\*" -Destination $apiDeployPath -Recurse -Force
Remove-Item $tempPublish -Recurse -Force
Write-Host "API published." -ForegroundColor Green

# -----------------------------
# Step 3 - Build Flutter Web
# -----------------------------
Write-Host "`n[Step 3] Building Flutter Web..." -ForegroundColor Yellow

# API calls use relative /api path — works on same origin (VM internal + external via same IP/domain)
Push-Location $frontendDir
try {
    flutter build web --release --dart-define=API_BASE_URL=/api
    if ($LASTEXITCODE -ne 0) { throw "Flutter build failed" }
} finally {
    Pop-Location
}

Write-Host "Flutter build complete." -ForegroundColor Green

# -----------------------------
# Step 4 - Deploy Flutter UI to wwwroot
# -----------------------------
Write-Host "`n[Step 4] Deploying Flutter UI to wwwroot..." -ForegroundColor Yellow

$flutterBuildSrc = "$frontendDir\build\web"
if (!(Test-Path $flutterBuildSrc)) { throw "Flutter build output not found at $flutterBuildSrc" }

if (Test-Path $uiDeployPath) { Remove-Item $uiDeployPath -Recurse -Force }
New-Item -ItemType Directory -Path $uiDeployPath -Force | Out-Null
Copy-Item "$flutterBuildSrc\*" -Destination $uiDeployPath -Recurse -Force
Write-Host "UI deployed to $uiDeployPath." -ForegroundColor Green

# -----------------------------
# Step 5 - Open firewall ports (idempotent)
# -----------------------------
# Write-Host "`n[Step 5] Configuring firewall rules..." -ForegroundColor Yellow

# $ports = @(80, 443, 7001)
# foreach ($port in $ports) {
#     $ruleName = "FAP-API-Port-$port"
#     if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
#         New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow | Out-Null
#         Write-Host "Firewall rule added for port $port." -ForegroundColor Green
#     } else {
#         Write-Host "Firewall rule for port $port already exists." -ForegroundColor Gray
#     }
# }

# -----------------------------
# Step 6 - Start API (Kestrel)
# Binds to 0.0.0.0 so it's reachable inside and outside the VM
# -----------------------------
Write-Host "`n[Step 6] Starting API..." -ForegroundColor Yellow

$apiExe = "$apiDeployPath\BajajDocumentProcessing.API.exe"
$apiDll = "$apiDeployPath\BajajDocumentProcessing.API.dll"

# Start API from the deploy directory so it finds appsettings.json
# Using cmd /c with start to launch in background from correct working directory
if (Test-Path $apiDll) {
    Start-Process -FilePath "cmd.exe" `
        -ArgumentList "/c cd /d `"$apiDeployPath`" && start /B dotnet BajajDocumentProcessing.API.dll --urls `"$ApiUrl`" --contentRoot `"$apiDeployPath`" --environment Production" `
        -WindowStyle Hidden `
        -PassThru | Out-Null
} elseif (Test-Path $apiExe) {
    Start-Process -FilePath "cmd.exe" `
        -ArgumentList "/c cd /d `"$apiDeployPath`" && start /B BajajDocumentProcessing.API.exe --urls `"$ApiUrl`" --contentRoot `"$apiDeployPath`" --environment Production" `
        -WindowStyle Hidden `
        -PassThru | Out-Null
} else {
    throw "API executable not found in $apiDeployPath"
}

# -----------------------------
# Step 7 - Health check
# -----------------------------
Write-Host "`n[Step 7] Waiting for API to start..." -ForegroundColor Yellow
$healthUrl = "http://localhost:5000/swagger/index.html"
$maxAttempts = 10
$attempt = 0
$started = $false

while ($attempt -lt $maxAttempts) {
    Start-Sleep -Seconds 3
    $attempt++
    try {
        # Use -SkipCertificateCheck or ignore SSL errors for local health check
        $response = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $started = $true
            break
        }
    } catch {
        # Also try swagger as a fallback health indicator
        try {
            $swaggerResponse = Invoke-WebRequest -Uri "http://localhost:5000/swagger" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            if ($swaggerResponse.StatusCode -eq 200) {
                $started = $true
                break
            }
        } catch {
            Write-Host "  Attempt $attempt/$maxAttempts - not ready yet..." -ForegroundColor Gray
        }
    }
}

if ($started) {
    Write-Host "`nDeployment Completed Successfully!" -ForegroundColor Cyan
    Write-Host "  API HTTP:  http://0.0.0.0:5000"    -ForegroundColor Cyan
    Write-Host "  API HTTPS: https://0.0.0.0:8000"   -ForegroundColor Cyan
    Write-Host "  API HTTPS: https://0.0.0.0:7001"   -ForegroundColor Cyan
    Write-Host "  Swagger:   http://localhost:5000/swagger" -ForegroundColor Cyan
    Write-Host "  Nginx (port 80) serves Flutter UI and proxies /api to Kestrel" -ForegroundColor Cyan
} else {
    Write-Host "`nAPI did not respond to health check after $maxAttempts attempts." -ForegroundColor Red
    Write-Host "Check logs in $apiDeployPath or run: dotnet $apiDll" -ForegroundColor Yellow
    exit 1
}
