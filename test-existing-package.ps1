# Test existing package workflow
$packageId = "d43513eb-1d36-4532-a381-e5a7a887e565"

Write-Host "Testing workflow for existing package: $packageId" -ForegroundColor Cyan
Write-Host ""

# Login first
Write-Host "Step 1: Login to get fresh token..." -ForegroundColor Yellow
$loginBody = @{
    email = "agency@example.com"
    password = "Agency@123"
} | ConvertTo-Json

try {
    $loginResponse = Invoke-RestMethod -Uri "http://localhost:5000/api/Auth/login" -Method Post -Body $loginBody -ContentType "application/json"
    $token = $loginResponse.token
    Write-Host "✓ Login successful" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "✗ Login failed: $_" -ForegroundColor Red
    exit 1
}

# Process the package
Write-Host "Step 2: Processing package..." -ForegroundColor Yellow
$headers = @{
    "Authorization" = "Bearer $token"
}

try {
    $processResponse = Invoke-RestMethod -Uri "http://localhost:5000/api/Submissions/$packageId/process-now" -Method Post -Headers $headers
    Write-Host "✓ Process request completed" -ForegroundColor Green
    Write-Host ""
    Write-Host "Response:" -ForegroundColor Cyan
    $processResponse | ConvertTo-Json -Depth 5
    Write-Host ""
} catch {
    Write-Host "✗ Process failed: $_" -ForegroundColor Red
    Write-Host ""
}

# Get package details
Write-Host "Step 3: Getting package details..." -ForegroundColor Yellow
try {
    $packageDetails = Invoke-RestMethod -Uri "http://localhost:5000/api/Submissions/$packageId" -Method Get -Headers $headers
    Write-Host "✓ Package details retrieved" -ForegroundColor Green
    Write-Host ""
    Write-Host "Package State: $($packageDetails.state)" -ForegroundColor Cyan
    Write-Host "Validation Passed: $($packageDetails.validationResult.allValidationsPassed)" -ForegroundColor Cyan
    Write-Host "Overall Confidence: $([math]::Round($packageDetails.confidenceScore.overallConfidence, 2))%" -ForegroundColor Cyan
    Write-Host "Recommendation: $($packageDetails.recommendation.type)" -ForegroundColor Cyan
    Write-Host ""
} catch {
    Write-Host "✗ Failed to get package details: $_" -ForegroundColor Red
}
