# Test workflow fix for package 48c7854b-fca6-41e7-84e8-3075c880d536
$packageId = "48c7854b-fca6-41e7-84e8-3075c880d536"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Testing Workflow Fix for Package: $packageId" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Login
Write-Host "[1/3] Logging in..." -ForegroundColor Yellow
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

# Step 2: Process the package
Write-Host "[2/3] Processing package (this may take 30-60 seconds)..." -ForegroundColor Yellow
$headers = @{
    "Authorization" = "Bearer $token"
}

try {
    $processResponse = Invoke-RestMethod -Uri "http://localhost:5000/api/Submissions/$packageId/process-now" -Method Post -Headers $headers
    Write-Host "✓ Process request completed" -ForegroundColor Green
    Write-Host ""
    Write-Host "Process Response:" -ForegroundColor Cyan
    Write-Host "  Success: $($processResponse.success)" -ForegroundColor $(if ($processResponse.success) { "Green" } else { "Red" })
    Write-Host "  State: $($processResponse.currentState)" -ForegroundColor Cyan
    Write-Host "  Message: $($processResponse.message)" -ForegroundColor Cyan
    Write-Host ""
} catch {
    Write-Host "✗ Process failed: $_" -ForegroundColor Red
    Write-Host ""
}

# Step 3: Get package details
Write-Host "[3/3] Getting package details..." -ForegroundColor Yellow
try {
    $packageDetails = Invoke-RestMethod -Uri "http://localhost:5000/api/Submissions/$packageId" -Method Get -Headers $headers
    Write-Host "✓ Package details retrieved" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "PACKAGE STATUS" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "Package ID: $($packageDetails.id)" -ForegroundColor White
    Write-Host "State: $($packageDetails.state)" -ForegroundColor $(if ($packageDetails.state -eq "PendingApproval") { "Green" } elseif ($packageDetails.state -eq "Rejected") { "Red" } else { "Yellow" })
    Write-Host ""
    
    Write-Host "Validation:" -ForegroundColor Cyan
    Write-Host "  All Passed: $($packageDetails.validationResult.allValidationsPassed)" -ForegroundColor $(if ($packageDetails.validationResult.allValidationsPassed) { "Green" } else { "Red" })
    if ($packageDetails.validationResult.failureReason) {
        Write-Host "  Failure Reason: $($packageDetails.validationResult.failureReason)" -ForegroundColor Red
    }
    Write-Host ""
    
    Write-Host "Confidence Scores:" -ForegroundColor Cyan
    Write-Host "  Overall: $([math]::Round($packageDetails.confidenceScore.overallConfidence, 2))%" -ForegroundColor White
    Write-Host "  PO: $([math]::Round($packageDetails.confidenceScore.poConfidence, 2))%" -ForegroundColor White
    Write-Host "  Invoice: $([math]::Round($packageDetails.confidenceScore.invoiceConfidence, 2))%" -ForegroundColor White
    Write-Host "  Cost Summary: $([math]::Round($packageDetails.confidenceScore.costSummaryConfidence, 2))%" -ForegroundColor White
    Write-Host "  Photos: $([math]::Round($packageDetails.confidenceScore.photosConfidence, 2))%" -ForegroundColor White
    Write-Host ""
    
    if ($packageDetails.recommendation) {
        Write-Host "Recommendation:" -ForegroundColor Cyan
        Write-Host "  Type: $($packageDetails.recommendation.type)" -ForegroundColor $(if ($packageDetails.recommendation.type -eq "Approve") { "Green" } elseif ($packageDetails.recommendation.type -eq "Reject") { "Red" } else { "Yellow" })
        Write-Host "  Confidence: $([math]::Round($packageDetails.recommendation.confidenceScore, 2))%" -ForegroundColor White
        Write-Host ""
        Write-Host "  Evidence:" -ForegroundColor Cyan
        $packageDetails.recommendation.evidence -split "`n" | ForEach-Object {
            if ($_.Trim()) {
                Write-Host "    $_" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "Recommendation: NULL (workflow failed at recommendation step)" -ForegroundColor Red
    }
    Write-Host ""
    
    Write-Host "==================================================" -ForegroundColor Cyan
    if ($packageDetails.state -eq "PendingApproval" -and $packageDetails.recommendation) {
        Write-Host "✓ SUCCESS: Workflow completed successfully!" -ForegroundColor Green
        Write-Host "  Package is ready for ASM review" -ForegroundColor Green
    } elseif ($packageDetails.state -eq "Rejected") {
        Write-Host "✗ FAILED: Package was rejected" -ForegroundColor Red
        Write-Host "  Check API logs for details" -ForegroundColor Red
    } else {
        Write-Host "⚠ INCOMPLETE: Workflow did not complete" -ForegroundColor Yellow
        Write-Host "  State: $($packageDetails.state)" -ForegroundColor Yellow
        Write-Host "  Recommendation: $(if ($packageDetails.recommendation) { 'Present' } else { 'Missing' })" -ForegroundColor Yellow
    }
    Write-Host "==================================================" -ForegroundColor Cyan
    
} catch {
    Write-Host "✗ Failed to get package details: $_" -ForegroundColor Red
}
