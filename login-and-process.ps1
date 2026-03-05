# Login and Process Package
# This script will login, get a new token, and trigger the workflow

$packageId = "7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8"

Write-Host "Step 1: Logging in..." -ForegroundColor Cyan

$loginBody = @{
    email = "agency@bajaj.com"
    password = "Password123!"
} | ConvertTo-Json

try {
    $loginResponse = Invoke-RestMethod -Uri "http://localhost:5000/api/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
    
    Write-Host "✅ Login successful!" -ForegroundColor Green
    Write-Host "  User: $($loginResponse.email)" -ForegroundColor White
    Write-Host "  Role: $($loginResponse.role)" -ForegroundColor White
    Write-Host ""
    
    $token = $loginResponse.token
    
    Write-Host "Step 2: Triggering workflow..." -ForegroundColor Cyan
    Write-Host "Package ID: $packageId" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "⏳ This may take 30-60 seconds..." -ForegroundColor Yellow
    Write-Host "Watch the API console for detailed logs!" -ForegroundColor Cyan
    Write-Host ""
    
    $headers = @{
        "Authorization" = "Bearer $token"
        "Accept" = "application/json"
    }
    
    $processResponse = Invoke-RestMethod -Uri "http://localhost:5000/api/Submissions/$packageId/process-now" -Method Post -Headers $headers
    
    Write-Host "Response:" -ForegroundColor Green
    Write-Host "  Success: $($processResponse.success)" -ForegroundColor $(if ($processResponse.success) { "Green" } else { "Red" })
    Write-Host "  Current State: $($processResponse.currentState)" -ForegroundColor Yellow
    Write-Host "  Message: $($processResponse.message)" -ForegroundColor White
    Write-Host ""
    
    if ($processResponse.success) {
        Write-Host "✅ Workflow completed successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Step 3: Checking extracted data..." -ForegroundColor Cyan
        
        $packageResponse = Invoke-RestMethod -Uri "http://localhost:5000/api/Submissions/$packageId" -Method Get -Headers $headers
        
        Write-Host ""
        Write-Host "Package Details:" -ForegroundColor Green
        Write-Host "  State: $($packageResponse.state)" -ForegroundColor Yellow
        Write-Host "  Documents: $($packageResponse.documents.Count)" -ForegroundColor White
        
        if ($packageResponse.confidenceScore) {
            Write-Host ""
            Write-Host "Confidence Score:" -ForegroundColor Green
            Write-Host "  Overall: $($packageResponse.confidenceScore.overallConfidence)" -ForegroundColor Cyan
            Write-Host "  PO: $($packageResponse.confidenceScore.poConfidence)" -ForegroundColor White
            Write-Host "  Invoice: $($packageResponse.confidenceScore.invoiceConfidence)" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "Extracted Data:" -ForegroundColor Green
        foreach ($doc in $packageResponse.documents) {
            Write-Host "  Document Type: $($doc.type)" -ForegroundColor Yellow
            if ($doc.extractedData) {
                $data = $doc.extractedData | ConvertTo-Json -Depth 5
                Write-Host "    Data: $data" -ForegroundColor White
            }
        }
        
    } else {
        Write-Host "❌ Workflow failed!" -ForegroundColor Red
        Write-Host "Check the API console logs for error details." -ForegroundColor Yellow
    }
    
} catch {
    Write-Host ""
    Write-Host "❌ ERROR:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host ""
