# Trigger Workflow Synchronously
# This will show you exactly what's happening

$packageId = "7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8"
$token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1laWQiOiIwNWIwNGRhZi04MWE3LTRjMDYtOTJkNS03NGUwZDFlMzVhNGQiLCJlbWFpbCI6ImFnZW5jeUBiYWphai5jb20iLCJyb2xlIjoiQWdlbmN5IiwianRpIjoiOGQ4OWViOWItOWY1Ni00ZDNiLTg0MTktZTc2NzcxMmQwZDVmIiwibmJmIjoxNzcyNjk0OTQ1LCJleHAiOjE3NzI2OTY3NDUsImlhdCI6MTc3MjY5NDk0NSwiaXNzIjoiQmFqYWpEb2N1bWVudFByb2Nlc3NpbmciLCJhdWQiOiJCYWphakRvY3VtZW50UHJvY2Vzc2luZyJ9.9f8ZuDTDInLyuqmhRMOL-9qcy3Kdhuzb78kSQfcIHQs"

Write-Host "Triggering workflow for package: $packageId" -ForegroundColor Cyan
Write-Host "This will run synchronously - watch the API console for logs!" -ForegroundColor Yellow
Write-Host ""

$headers = @{
    "Authorization" = "Bearer $token"
    "Accept" = "application/json"
}

try {
    Write-Host "Calling /process-now endpoint..." -ForegroundColor Cyan
    $response = Invoke-RestMethod -Uri "http://localhost:5000/api/Submissions/$packageId/process-now" -Method Post -Headers $headers
    
    Write-Host ""
    Write-Host "Response:" -ForegroundColor Green
    Write-Host "  Success: $($response.success)" -ForegroundColor $(if ($response.success) { "Green" } else { "Red" })
    Write-Host "  Package ID: $($response.packageId)" -ForegroundColor White
    Write-Host "  Current State: $($response.currentState)" -ForegroundColor Yellow
    Write-Host "  Message: $($response.message)" -ForegroundColor White
    
    if ($response.success) {
        Write-Host ""
        Write-Host "✅ Workflow completed successfully!" -ForegroundColor Green
        Write-Host "Now check the package details to see the extracted data." -ForegroundColor Cyan
    } else {
        Write-Host ""
        Write-Host "❌ Workflow failed!" -ForegroundColor Red
        Write-Host "Check the API console logs above for error details." -ForegroundColor Yellow
    }
    
} catch {
    Write-Host ""
    Write-Host "❌ ERROR calling endpoint:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    
    if ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Host "Status Code: $statusCode" -ForegroundColor Red
        
        if ($statusCode -eq 401) {
            Write-Host ""
            Write-Host "Token expired! Login again to get a new token:" -ForegroundColor Yellow
            Write-Host "POST http://localhost:5000/api/auth/login" -ForegroundColor White
        }
    }
}

Write-Host ""
