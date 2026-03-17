# Test API Status
Write-Host "Testing API Status..." -ForegroundColor Cyan

try {
    $response = Invoke-RestMethod -Uri "http://localhost:5000/swagger/v1/swagger.json" -Method Get
    Write-Host "✅ API is running successfully!" -ForegroundColor Green
    Write-Host "✅ Swagger is accessible at: http://localhost:5000/swagger" -ForegroundColor Green
    Write-Host "✅ Environment: Development (using real API keys)" -ForegroundColor Green
    Write-Host ""
    Write-Host "API Endpoints Available:" -ForegroundColor Yellow
    Write-Host "  - POST /api/auth/login" -ForegroundColor White
    Write-Host "  - POST /api/Documents/upload" -ForegroundColor White
    Write-Host "  - POST /api/submissions/{packageId}/submit" -ForegroundColor White
    Write-Host "  - POST /api/submissions/{packageId}/process-now" -ForegroundColor White
    Write-Host "  - GET  /api/submissions" -ForegroundColor White
    Write-Host "  - GET  /api/submissions/{id}" -ForegroundColor White
} catch {
    Write-Host "❌ API is not responding" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
