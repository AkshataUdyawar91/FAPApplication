# Package Status Checker
# This script helps diagnose why data extraction isn't working

param(
    [Parameter(Mandatory=$true)]
    [string]$PackageId,
    
    [Parameter(Mandatory=$true)]
    [string]$Token
)

$baseUrl = "http://localhost:5000"

Write-Host "=== Checking Package Status ===" -ForegroundColor Cyan
Write-Host "Package ID: $PackageId" -ForegroundColor Yellow
Write-Host ""

# Check package details
Write-Host "1. Fetching package details..." -ForegroundColor Green
try {
    $headers = @{
        "Authorization" = "Bearer $Token"
        "Content-Type" = "application/json"
    }
    
    $response = Invoke-RestMethod -Uri "$baseUrl/api/Submissions/$PackageId" -Method Get -Headers $headers
    
    Write-Host "   State: $($response.state)" -ForegroundColor $(if ($response.state -eq "PendingApproval") { "Green" } elseif ($response.state -eq "Uploaded") { "Red" } else { "Yellow" })
    Write-Host "   Created: $($response.createdAt)"
    Write-Host "   Updated: $($response.updatedAt)"
    Write-Host "   Documents: $($response.documents.Count)"
    Write-Host ""
    
    # Check if data is extracted
    Write-Host "2. Checking extracted data..." -ForegroundColor Green
    
    $poDoc = $response.documents | Where-Object { $_.type -eq "PO" } | Select-Object -First 1
    $invoiceDoc = $response.documents | Where-Object { $_.type -eq "Invoice" } | Select-Object -First 1
    
    if ($poDoc) {
        Write-Host "   PO Document:" -ForegroundColor Cyan
        Write-Host "     - Filename: $($poDoc.filename)"
        Write-Host "     - Confidence: $($poDoc.extractionConfidence)"
        
        if ($poDoc.extractedData) {
            $poData = $poDoc.extractedData | ConvertFrom-Json
            Write-Host "     - PO Number: $($poData.PONumber -or $poData.poNumber)" -ForegroundColor $(if ($poData.PONumber -or $poData.poNumber) { "Green" } else { "Red" })
            Write-Host "     - Total Amount: $($poData.TotalAmount -or $poData.totalAmount)" -ForegroundColor $(if ($poData.TotalAmount -or $poData.totalAmount) { "Green" } else { "Red" })
        } else {
            Write-Host "     - Extracted Data: EMPTY" -ForegroundColor Red
        }
    }
    
    if ($invoiceDoc) {
        Write-Host "   Invoice Document:" -ForegroundColor Cyan
        Write-Host "     - Filename: $($invoiceDoc.filename)"
        Write-Host "     - Confidence: $($invoiceDoc.extractionConfidence)"
        
        if ($invoiceDoc.extractedData) {
            $invData = $invoiceDoc.extractedData | ConvertFrom-Json
            Write-Host "     - Invoice Number: $($invData.InvoiceNumber -or $invData.invoiceNumber)" -ForegroundColor $(if ($invData.InvoiceNumber -or $invData.invoiceNumber) { "Green" } else { "Red" })
            Write-Host "     - Total Amount: $($invData.TotalAmount -or $invData.totalAmount)" -ForegroundColor $(if ($invData.TotalAmount -or $invData.totalAmount) { "Green" } else { "Red" })
        } else {
            Write-Host "     - Extracted Data: EMPTY" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    
    # Check confidence score
    Write-Host "3. Checking confidence score..." -ForegroundColor Green
    if ($response.confidenceScore) {
        Write-Host "   Overall Confidence: $($response.confidenceScore.overallConfidence)" -ForegroundColor Green
        Write-Host "   PO Confidence: $($response.confidenceScore.poConfidence)"
        Write-Host "   Invoice Confidence: $($response.confidenceScore.invoiceConfidence)"
    } else {
        Write-Host "   Confidence Score: NOT CALCULATED" -ForegroundColor Red
    }
    
    Write-Host ""
    
    # Diagnosis
    Write-Host "=== DIAGNOSIS ===" -ForegroundColor Cyan
    
    if ($response.state -eq "Uploaded") {
        Write-Host "❌ PROBLEM: Package is still in 'Uploaded' state" -ForegroundColor Red
        Write-Host "   This means the workflow was NEVER triggered." -ForegroundColor Red
        Write-Host ""
        Write-Host "   SOLUTION: Call the submit endpoint:" -ForegroundColor Yellow
        Write-Host "   POST $baseUrl/api/Submissions/$PackageId/submit" -ForegroundColor White
        Write-Host "   Authorization: Bearer $Token" -ForegroundColor White
        Write-Host ""
        Write-Host "   Run this command:" -ForegroundColor Yellow
        Write-Host "   Invoke-RestMethod -Uri '$baseUrl/api/Submissions/$PackageId/submit' -Method Post -Headers @{'Authorization'='Bearer $Token'}" -ForegroundColor White
    }
    elseif ($response.state -eq "Extracting" -or $response.state -eq "Validating" -or $response.state -eq "Scoring" -or $response.state -eq "Recommending") {
        Write-Host "⏳ PROCESSING: Package is being processed" -ForegroundColor Yellow
        Write-Host "   Current state: $($response.state)" -ForegroundColor Yellow
        Write-Host "   Wait 30-60 seconds and check again." -ForegroundColor Yellow
    }
    elseif ($response.state -eq "PendingApproval") {
        if ($response.confidenceScore) {
            Write-Host "✅ SUCCESS: Package processed successfully" -ForegroundColor Green
            Write-Host "   Data should be visible in the dashboard." -ForegroundColor Green
        } else {
            Write-Host "⚠️ WARNING: Package is in PendingApproval but no confidence score" -ForegroundColor Yellow
            Write-Host "   This is unusual. Check API logs for errors." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "⚠️ UNKNOWN STATE: $($response.state)" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ ERROR: Failed to fetch package details" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Message -like "*401*" -or $_.Exception.Message -like "*Unauthorized*") {
        Write-Host ""
        Write-Host "   Your token may be invalid or expired." -ForegroundColor Yellow
        Write-Host "   Login again to get a new token:" -ForegroundColor Yellow
        Write-Host "   POST $baseUrl/api/auth/login" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "=== END ===" -ForegroundColor Cyan
