# Check PO Document Details
$packageId = "5e5c8feb-beca-46e0-9dcb-458836eaa519"
$token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1laWQiOiIwNWIwNGRhZi04MWE3LTRjMDYtOTJkNS03NGUwZDFlMzVhNGQiLCJlbWFpbCI6ImFnZW5jeUBiYWphai5jb20iLCJyb2xlIjoiQWdlbmN5IiwianRpIjoiNTBjMWY4MGItYjEyYi00ZmJiLWEwM2UtZGE3ZmI3ZWI5MjNjIiwibmJmIjoxNzcyNjk4NjU1LCJleHAiOjE3NzI3MDA0NTUsImlhdCI6MTc3MjY5ODY1NSwiaXNzIjoiQmFqYWpEb2N1bWVudFByb2Nlc3NpbmciLCJhdWQiOiJCYWphakRvY3VtZW50UHJvY2Vzc2luZyJ9.xssrW3B1Hlv6kfMreA--nmm9N_1CsTo4WfALbbVUzAQ"

Write-Host "Checking PO document details..." -ForegroundColor Cyan
Write-Host ""

$headers = @{
    "Authorization" = "Bearer $token"
}

try {
    $response = Invoke-RestMethod -Uri "http://localhost:5000/api/Submissions/$packageId" -Method Get -Headers $headers
    
    Write-Host "Package State: $($response.state)" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Documents:" -ForegroundColor Cyan
    foreach ($doc in $response.documents) {
        Write-Host "  Type: $($doc.type)" -ForegroundColor White
        Write-Host "  Filename: $($doc.filename)" -ForegroundColor Gray
        Write-Host "  Confidence: $($doc.extractionConfidence)" -ForegroundColor Gray
        
        if ($doc.type -eq "PO") {
            Write-Host "  PO Extracted Data:" -ForegroundColor Yellow
            if ($doc.extractedData) {
                $doc.extractedData | ConvertTo-Json -Depth 5 | Write-Host -ForegroundColor White
            } else {
                Write-Host "    No data extracted!" -ForegroundColor Red
            }
        }
        Write-Host ""
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
