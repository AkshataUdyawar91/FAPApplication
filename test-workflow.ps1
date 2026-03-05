# Test Workflow Execution
# This script tests if the workflow is actually running

$packageId = "7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8"
$token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1laWQiOiIwNWIwNGRhZi04MWE3LTRjMDYtOTJkNS03NGUwZDFlMzVhNGQiLCJlbWFpbCI6ImFnZW5jeUBiYWphai5jb20iLCJyb2xlIjoiQWdlbmN5IiwianRpIjoiOGQ4OWViOWItOWY1Ni00ZDNiLTg0MTktZTc2NzcxMmQwZDVmIiwibmJmIjoxNzcyNjk0OTQ1LCJleHAiOjE3NzI2OTY3NDUsImlhdCI6MTc3MjY5NDk0NSwiaXNzIjoiQmFqYWpEb2N1bWVudFByb2Nlc3NpbmciLCJhdWQiOiJCYWphakRvY3VtZW50UHJvY2Vzc2luZyJ9.9f8ZuDTDInLyuqmhRMOL-9qcy3Kdhuzb78kSQfcIHQs"

Write-Host "Checking package status..." -ForegroundColor Cyan

$headers = @{
    "Authorization" = "Bearer $token"
    "Accept" = "application/json"
}

try {
    $response = Invoke-RestMethod -Uri "http://localhost:5000/api/Submissions/$packageId" -Method Get -Headers $headers
    
    Write-Host "`nPackage ID: $($response.id)" -ForegroundColor Yellow
    Write-Host "State: $($response.state)" -ForegroundColor Yellow
    Write-Host "Created: $($response.createdAt)" -ForegroundColor Yellow
    Write-Host "Updated: $($response.updatedAt)" -ForegroundColor Yellow
    Write-Host "Document Count: $($response.documents.Count)" -ForegroundColor Yellow
    
    Write-Host "`nDocuments:" -ForegroundColor Cyan
    foreach ($doc in $response.documents) {
        Write-Host "  - Type: $($doc.type)" -ForegroundColor White
        Write-Host "    Filename: $($doc.filename)" -ForegroundColor White
        Write-Host "    Confidence: $($doc.extractionConfidence)" -ForegroundColor White
        Write-Host "    Has Data: $($null -ne $doc.extractedData -and $doc.extractedData -ne '{}')" -ForegroundColor White
    }
    
    if ($response.confidenceScore) {
        Write-Host "`nConfidence Score:" -ForegroundColor Cyan
        Write-Host "  Overall: $($response.confidenceScore.overallConfidence)" -ForegroundColor Green
        Write-Host "  PO: $($response.confidenceScore.poConfidence)" -ForegroundColor White
        Write-Host "  Invoice: $($response.confidenceScore.invoiceConfidence)" -ForegroundColor White
    } else {
        Write-Host "`nNo confidence score yet" -ForegroundColor Red
    }
    
    if ($response.recommendation) {
        Write-Host "`nRecommendation:" -ForegroundColor Cyan
        Write-Host "  Type: $($response.recommendation.type)" -ForegroundColor White
        Write-Host "  Evidence: $($response.recommendation.evidence)" -ForegroundColor White
    } else {
        Write-Host "`nNo recommendation yet" -ForegroundColor Red
    }
    
    # Check if workflow has run
    if ($response.state -eq "Uploaded") {
        Write-Host "`n⚠️  WARNING: Package is still in 'Uploaded' state!" -ForegroundColor Red
        Write-Host "The workflow has NOT started yet." -ForegroundColor Red
        Write-Host "`nPossible reasons:" -ForegroundColor Yellow
        Write-Host "1. Background task (Task.Run) is not executing" -ForegroundColor White
        Write-Host "2. Workflow orchestrator is failing silently" -ForegroundColor White
        Write-Host "3. Check API console logs for errors" -ForegroundColor White
    } elseif ($response.state -eq "PendingApproval") {
        Write-Host "`n✅ SUCCESS: Workflow completed!" -ForegroundColor Green
    } else {
        Write-Host "`n⏳ IN PROGRESS: Workflow is running (State: $($response.state))" -ForegroundColor Yellow
        Write-Host "Wait a few more seconds and run this script again." -ForegroundColor White
    }
    
} catch {
    Write-Host "`n❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.Exception.Response.StatusCode -ForegroundColor Red
}

Write-Host "`n" -NoNewline
