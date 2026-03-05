# Check Package Status
$packageId = "b075e5fd-4b7a-4d9f-940e-bf27cbc9e164"
$token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1laWQiOiIwNWIwNGRhZi04MWE3LTRjMDYtOTJkNS03NGUwZDFlMzVhNGQiLCJlbWFpbCI6ImFnZW5jeUBiYWphai5jb20iLCJyb2xlIjoiQWdlbmN5IiwianRpIjoiNTBjMWY4MGItYjEyYi00ZmJiLWEwM2UtZGE3ZmI3ZWI5MjNjIiwibmJmIjoxNzcyNjk4NjU1LCJleHAiOjE3NzI3MDA0NTUsImlhdCI6MTc3MjY5ODY1NSwiaXNzIjoiQmFqYWpEb2N1bWVudFByb2Nlc3NpbmciLCJhdWQiOiJCYWphakRvY3VtZW50UHJvY2Vzc2luZyJ9.xssrW3B1Hlv6kfMreA--nmm9N_1CsTo4WfALbbVUzAQ"

Write-Host "Checking package status..." -ForegroundColor Cyan
Write-Host "Package ID: $packageId" -ForegroundColor Yellow
Write-Host ""

$headers = @{
    "Authorization" = "Bearer $token"
}

try {
    $response = Invoke-RestMethod -Uri "http://localhost:5000/api/Submissions/$packageId" -Method Get -Headers $headers
    
    Write-Host "Current State: $($response.state)" -ForegroundColor $(
        switch ($response.state) {
            "Uploaded" { "Yellow" }
            "Extracting" { "Cyan" }
            "Validating" { "Cyan" }
            "Scoring" { "Cyan" }
            "Recommending" { "Cyan" }
            "PendingApproval" { "Green" }
            "Rejected" { "Red" }
            default { "White" }
        }
    )
    
    Write-Host "Created: $($response.createdAt)" -ForegroundColor Gray
    Write-Host "Updated: $($response.updatedAt)" -ForegroundColor Gray
    Write-Host ""
    
    if ($response.state -eq "Uploaded") {
        Write-Host "⚠️  Workflow has NOT started yet!" -ForegroundColor Red
        Write-Host "The background task may not be executing." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Try the synchronous endpoint instead:" -ForegroundColor Cyan
        Write-Host "  Invoke-RestMethod -Uri 'http://localhost:5000/api/Submissions/$packageId/process-now' -Method Post -Headers @{'Authorization'='Bearer $token'}" -ForegroundColor White
    }
    elseif ($response.state -eq "PendingApproval") {
        Write-Host "✅ Workflow completed successfully!" -ForegroundColor Green
        Write-Host ""
        
        if ($response.confidenceScore) {
            Write-Host "Confidence Score:" -ForegroundColor Green
            Write-Host "  Overall: $($response.confidenceScore.overallConfidence)%" -ForegroundColor Cyan
        }
        
        Write-Host ""
        Write-Host "Documents:" -ForegroundColor Green
        foreach ($doc in $response.documents) {
            Write-Host "  - $($doc.type): Confidence $($doc.extractionConfidence)" -ForegroundColor White
        }
    }
    elseif ($response.state -eq "Rejected") {
        Write-Host "❌ Workflow failed!" -ForegroundColor Red
        if ($response.validationResult) {
            Write-Host "Reason: $($response.validationResult.failureReason)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "⏳ Workflow is in progress..." -ForegroundColor Yellow
        Write-Host "Wait a few seconds and run this script again." -ForegroundColor White
    }
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
