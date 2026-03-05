# Run API in Development Mode
# This ensures appsettings.Development.json is used (with real API keys)

Write-Host "Starting API in Development mode..." -ForegroundColor Cyan
Write-Host "This will use appsettings.Development.json with your real API keys" -ForegroundColor Yellow
Write-Host ""

# Set environment to Development
$env:ASPNETCORE_ENVIRONMENT = "Development"

# Navigate to backend and run
Set-Location backend
dotnet run --project src/BajajDocumentProcessing.API

Write-Host ""
Write-Host "API stopped" -ForegroundColor Yellow
