# Submit Package Script
# This script submits a package to trigger the workflow

param(
    [Parameter(Mandatory=$true)]
    [string]$PackageId,
    
    [Parameter(Mandatory=$true)]
    [string]$Token
)

$baseUrl = "http://localhost:5000"

Write-Host "=== Submitting Package ===" -ForegroundColor Cyan
Write-Host "Package ID: $PackageId" -ForegroundColor Yellow
Write-Host ""

try {
    $headers = @{
        "Authorization" = "Bearer $Token"
        "Content-Type" = "application/json"
    }
    
    Write-Host "Calling submit endpoint..." -ForegroundColor Green
    $response = Invoke-RestMethod -Uri "$baseUrl/api/Submissions/$PackageId/submit" -Method Post -Headers $headers
    
    Write-Host "✅ SUCCESS!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Response:" -ForegroundColor Cyan
    Write-Host "  Message: $($response.message)" -ForegroundColor White
    Write-Host "  Package ID: $($response.packageId)" -ForegroundColor White
    Write-Host "  Document Count: $($response.documentCount)" -ForegroundColor White
    Write-Host "  Status: $($response.status)" -ForegroundColor White
    Write-Host ""
    Write-Host "⏳ Processing started in background..." -ForegroundColor Yellow
    Write-Host "   Wait 30-60 seconds for extraction to complete." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Check status with:" -ForegroundColor Cyan
    Write-Host "  .\check-package-status.ps1 -PackageId '$PackageId' -Token '$Token'" -ForegroundColor White
    
} catch {
    Write-Host "❌ ERROR: Failed to submit package" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    
    if ($_.Exception.Message -like "*401*" -or $_.Exception.Message -like "*Unauthorized*") {
        Write-Host "   Your token is invalid or expired." -ForegroundColor Yellow
        Write-Host "   Login again to get a new token:" -ForegroundColor Yellow
        Write-Host "   POST $baseUrl/api/auth/login" -ForegroundColor White
    }
    elseif ($_.Exception.Message -like "*403*" -or $_.Exception.Message -like "*Forbidden*") {
        Write-Host "   Your token doesn't have the right permissions." -ForegroundColor Yellow
        Write-Host "   Make sure you're logged in as an Agency user." -ForegroundColor Yellow
        Write-Host "   Login again:" -ForegroundColor Yellow
        Write-Host "   POST $baseUrl/api/auth/login" -ForegroundColor White
    }
    elseif ($_.Exception.Message -like "*404*" -or $_.Exception.Message -like "*Not Found*") {
        Write-Host "   Package not found." -ForegroundColor Yellow
        Write-Host "   Check the package ID: $PackageId" -ForegroundColor Yellow
    }
    elseif ($_.Exception.Message -like "*400*" -or $_.Exception.Message -like "*Bad Request*") {
        Write-Host "   Package may already be submitted or missing required documents." -ForegroundColor Yellow
        Write-Host "   Check package status:" -ForegroundColor Yellow
        Write-Host "   .\check-package-status.ps1 -PackageId '$PackageId' -Token '$Token'" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "=== END ===" -ForegroundColor Cyan
