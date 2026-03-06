# Test Chat API with Real Azure OpenAI
Write-Host "=== Testing Chat API ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Login to get token
Write-Host "Step 1: Logging in as agency@bajaj.com..." -ForegroundColor Yellow
$loginBody = @{
    email = "agency@bajaj.com"
    password = "Password123!"
} | ConvertTo-Json

try {
    $loginResponse = Invoke-RestMethod -Uri "http://localhost:5000/api/auth/login" `
        -Method Post `
        -ContentType "application/json" `
        -Body $loginBody
    
    $token = $loginResponse.token
    Write-Host "✓ Login successful!" -ForegroundColor Green
    Write-Host "Token: $($token.Substring(0, 20))..." -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host "✗ Login failed: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Send chat message
Write-Host "Step 2: Sending chat message..." -ForegroundColor Yellow
$chatBody = @{
    message = "Show me pending submissions"
} | ConvertTo-Json

try {
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    }
    
    Write-Host "Calling: POST http://localhost:5000/api/chat/message" -ForegroundColor Gray
    Write-Host "Message: 'Show me pending submissions'" -ForegroundColor Gray
    Write-Host ""
    
    $chatResponse = Invoke-RestMethod -Uri "http://localhost:5000/api/chat/message" `
        -Method Post `
        -Headers $headers `
        -Body $chatBody
    
    Write-Host "✓ Chat API call successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== RESPONSE ===" -ForegroundColor Cyan
    Write-Host "Message: $($chatResponse.message)" -ForegroundColor White
    Write-Host ""
    Write-Host "ConversationId: $($chatResponse.conversationId)" -ForegroundColor Gray
    Write-Host "Citations: $($chatResponse.citations.Count)" -ForegroundColor Gray
    Write-Host ""
    
    # Check if response contains mock text
    if ($chatResponse.message -like "*AI chat service will be available*" -or 
        $chatResponse.message -like "*Azure OpenAI*configured*") {
        Write-Host "⚠ WARNING: Response appears to be a mock/error message!" -ForegroundColor Red
        Write-Host "This means the ChatService is not properly initialized." -ForegroundColor Red
    } else {
        Write-Host "✓ Response appears to be from real Azure OpenAI!" -ForegroundColor Green
    }
    
} catch {
    Write-Host "✗ Chat API call failed!" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    
    if ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Host "Status Code: $statusCode" -ForegroundColor Yellow
        
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            Write-Host "Response Body: $responseBody" -ForegroundColor Yellow
        } catch {
            Write-Host "Could not read response body" -ForegroundColor Gray
        }
    }
    exit 1
}

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan
