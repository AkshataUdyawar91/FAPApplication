# Test Enhanced Validation Report Feature
# This script tests the validation report endpoint with real data

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Enhanced Validation Report Test Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$baseUrl = "http://localhost:5000/api"
$loginUrl = "$baseUrl/auth/login"

# Test users
$asmUser = @{
    email = "asm@bajaj.com"
    password = "ASM@123"
}

$hqUser = @{
    email = "hq@bajaj.com"
    password = "HQ@123"
}

# Function to login and get token
function Get-AuthToken {
    param($user)
    
    Write-Host "Logging in as $($user.email)..." -ForegroundColor Yellow
    
    try {
        $response = Invoke-RestMethod -Uri $loginUrl -Method Post -Body ($user | ConvertTo-Json) -ContentType "application/json"
        Write-Host "✓ Login successful" -ForegroundColor Green
        return $response.token
    }
    catch {
        Write-Host "✗ Login failed: $_" -ForegroundColor Red
        return $null
    }
}

# Function to get submissions
function Get-Submissions {
    param($token)
    
    Write-Host "Fetching submissions..." -ForegroundColor Yellow
    
    try {
        $headers = @{
            "Authorization" = "Bearer $token"
        }
        
        $response = Invoke-RestMethod -Uri "$baseUrl/submissions" -Method Get -Headers $headers
        
        if ($response.items -and $response.items.Count -gt 0) {
            Write-Host "✓ Found $($response.items.Count) submissions" -ForegroundColor Green
            return $response.items
        }
        else {
            Write-Host "✗ No submissions found" -ForegroundColor Red
            return @()
        }
    }
    catch {
        Write-Host "✗ Failed to fetch submissions: $_" -ForegroundColor Red
        return @()
    }
}

# Function to test validation report
function Test-ValidationReport {
    param($token, $submissionId)
    
    Write-Host ""
    Write-Host "Testing validation report for submission: $submissionId" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    
    try {
        $headers = @{
            "Authorization" = "Bearer $token"
        }
        
        $url = "$baseUrl/submissions/$submissionId/validation-report"
        Write-Host "URL: $url" -ForegroundColor Gray
        
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
        
        Write-Host "✓ Validation report retrieved successfully" -ForegroundColor Green
        Write-Host ""
        
        # Display summary
        Write-Host "VALIDATION SUMMARY:" -ForegroundColor Yellow
        Write-Host "  Overall Confidence: $($response.summary.overallConfidence)%" -ForegroundColor White
        Write-Host "  Recommendation: $($response.summary.recommendationType)" -ForegroundColor White
        Write-Host "  Risk Level: $($response.summary.riskLevel)" -ForegroundColor White
        Write-Host "  Total Validations: $($response.summary.totalValidations)" -ForegroundColor White
        Write-Host "  Passed: $($response.summary.passedValidations)" -ForegroundColor Green
        Write-Host "  Failed: $($response.summary.failedValidations)" -ForegroundColor Red
        Write-Host "  Critical Issues: $($response.summary.criticalIssues)" -ForegroundColor Red
        Write-Host "  High Priority: $($response.summary.highPriorityIssues)" -ForegroundColor Yellow
        Write-Host "  Medium Priority: $($response.summary.mediumPriorityIssues)" -ForegroundColor Yellow
        Write-Host ""
        
        # Display validation categories
        Write-Host "VALIDATION CATEGORIES:" -ForegroundColor Yellow
        foreach ($category in $response.categories) {
            $icon = if ($category.passed) { "✓" } else { "✗" }
            $color = if ($category.passed) { "Green" } else { "Red" }
            Write-Host "  $icon $($category.categoryName) [$($category.severity)]" -ForegroundColor $color
            Write-Host "    $($category.shortDescription)" -ForegroundColor Gray
            
            if ($category.details) {
                Write-Host "    Expected: $($category.details.expectedValue)" -ForegroundColor Gray
                Write-Host "    Actual: $($category.details.actualValue)" -ForegroundColor Gray
            }
        }
        Write-Host ""
        
        # Display recommendation
        Write-Host "AI RECOMMENDATION:" -ForegroundColor Yellow
        Write-Host "  Action: $($response.recommendation.action)" -ForegroundColor White
        Write-Host "  Reasoning: $($response.recommendation.reasoning)" -ForegroundColor Gray
        Write-Host ""
        
        # Display confidence breakdown
        Write-Host "CONFIDENCE BREAKDOWN:" -ForegroundColor Yellow
        foreach ($doc in $response.confidenceBreakdown.documents) {
            Write-Host "  $($doc.documentType): $($doc.confidence)% (weight: $($doc.weight))" -ForegroundColor White
        }
        Write-Host ""
        
        return $true
    }
    catch {
        Write-Host "✗ Failed to get validation report: $_" -ForegroundColor Red
        Write-Host "Error Details: $($_.Exception.Message)" -ForegroundColor Red
        
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            Write-Host "Response Body: $responseBody" -ForegroundColor Red
        }
        
        return $false
    }
}

# Main execution
Write-Host "Step 1: Testing with ASM User" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""

$asmToken = Get-AuthToken -user $asmUser

if ($asmToken) {
    $submissions = Get-Submissions -token $asmToken
    
    if ($submissions.Count -gt 0) {
        Write-Host ""
        Write-Host "Testing validation reports for first 3 submissions..." -ForegroundColor Cyan
        Write-Host ""
        
        $count = [Math]::Min(3, $submissions.Count)
        for ($i = 0; $i -lt $count; $i++) {
            $submission = $submissions[$i]
            Write-Host "Submission $($i + 1):" -ForegroundColor White
            Write-Host "  ID: $($submission.id)" -ForegroundColor Gray
            Write-Host "  State: $($submission.state)" -ForegroundColor Gray
            Write-Host "  PO Number: $($submission.poNumber)" -ForegroundColor Gray
            
            $success = Test-ValidationReport -token $asmToken -submissionId $submission.id
            
            if ($success) {
                Write-Host "✓ Test passed for submission $($i + 1)" -ForegroundColor Green
            }
            else {
                Write-Host "✗ Test failed for submission $($i + 1)" -ForegroundColor Red
            }
            
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Gray
            Write-Host ""
        }
    }
}

Write-Host ""
Write-Host "Step 2: Testing with HQ User" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host ""

$hqToken = Get-AuthToken -user $hqUser

if ($hqToken) {
    $submissions = Get-Submissions -token $hqToken
    
    if ($submissions.Count -gt 0) {
        Write-Host ""
        Write-Host "Testing validation report for first submission..." -ForegroundColor Cyan
        Write-Host ""
        
        $submission = $submissions[0]
        Write-Host "Submission:" -ForegroundColor White
        Write-Host "  ID: $($submission.id)" -ForegroundColor Gray
        Write-Host "  State: $($submission.state)" -ForegroundColor Gray
        Write-Host "  PO Number: $($submission.poNumber)" -ForegroundColor Gray
        
        $success = Test-ValidationReport -token $hqToken -submissionId $submission.id
        
        if ($success) {
            Write-Host "✓ HQ test passed" -ForegroundColor Green
        }
        else {
            Write-Host "✗ HQ test failed" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Start the Flutter frontend: cd frontend && flutter run -d chrome" -ForegroundColor White
Write-Host "2. Login as ASM (asm@bajaj.com / ASM@123)" -ForegroundColor White
Write-Host "3. Click the 'View AI Report' button on any submission" -ForegroundColor White
Write-Host "4. Verify the validation report displays correctly" -ForegroundColor White
Write-Host ""
