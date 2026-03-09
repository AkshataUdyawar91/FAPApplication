# Get Fresh JWT Token
# Usage: .\get-fresh-token.ps1

$apiUrl = "http://localhost:5000/api/Auth/login"

# Test with different user roles
$users = @(
    @{ email = "agency@test.com"; password = "Test@123"; role = "Agency" }
    @{ email = "asm@test.com"; password = "Test@123"; role = "ASM" }
    @{ email = "hq@test.com"; password = "Test@123"; role = "HQ" }
)

Write-Host "=== Getting Fresh JWT Tokens ===" -ForegroundColor Cyan
Write-Host ""

foreach ($user in $users) {
    Write-Host "Logging in as: $($user.email) ($($user.role))" -ForegroundColor Yellow
    
    $body = @{
        email = $user.email
        password = $user.password
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $body -ContentType "application/json"
        
        Write-Host "✓ Login successful!" -ForegroundColor Green
        Write-Host "Token: $($response.token.Substring(0, 50))..." -ForegroundColor Gray
        Write-Host "User ID: $($response.userId)" -ForegroundColor Gray
        Write-Host "Role: $($response.role)" -ForegroundColor Gray
        Write-Host ""
        
        # Save token to file for easy access
        $tokenFile = "token_$($user.role.ToLower()).txt"
        $response.token | Out-File -FilePath $tokenFile -Encoding UTF8
        Write-Host "Token saved to: $tokenFile" -ForegroundColor Cyan
        Write-Host ""
    }
    catch {
        Write-Host "✗ Login failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
    }
}

Write-Host "=== Done ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "To use a token in Swagger:" -ForegroundColor Yellow
Write-Host "1. Copy the token from the file (e.g., token_agency.txt)"
Write-Host "2. Click 'Authorize' in Swagger UI"
Write-Host "3. Paste: Bearer <your-token>"
Write-Host ""
