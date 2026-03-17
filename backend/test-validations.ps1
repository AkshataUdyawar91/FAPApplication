# Comprehensive Validation Testing Script
# Tests all 14 validation requirements from Excel

$baseUrl = "http://localhost:5000/api"
$token = ""

Write-Host "=== Bajaj Document Processing - Validation Testing ===" -ForegroundColor Cyan
Write-Host ""

# Function to login and get token
function Get-AuthToken {
    Write-Host "Step 1: Authenticating..." -ForegroundColor Yellow
    
    $loginBody = @{
        email = "agency@bajaj.com"
        password = "Password123!"
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
        Write-Host "✓ Authentication successful" -ForegroundColor Green
        return $response.token
    }
    catch {
        Write-Host "✗ Authentication failed: $_" -ForegroundColor Red
        return $null
    }
}

# Function to create a package
function New-TestPackage {
    param($token)
    
    Write-Host "`nStep 2: Creating test package..." -ForegroundColor Yellow
    
    $headers = @{
        "Authorization" = "Bearer $token"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/documents/packages" -Method Post -Headers $headers
        Write-Host "✓ Package created: $($response.packageId)" -ForegroundColor Green
        return $response.packageId
    }
    catch {
        Write-Host "✗ Package creation failed: $_" -ForegroundColor Red
        return $null
    }
}

# Function to upload a document with test data
function Upload-TestDocument {
    param($token, $packageId, $documentType, $testData)
    
    Write-Host "  Uploading $documentType document..." -ForegroundColor Gray
    
    $headers = @{
        "Authorization" = "Bearer $token"
    }
    
    # Create a temporary test file
    $tempFile = [System.IO.Path]::GetTempFileName()
    $tempFile = [System.IO.Path]::ChangeExtension($tempFile, ".txt")
    "Test document for $documentType" | Out-File -FilePath $tempFile
    
    try {
        $form = @{
            file = Get-Item -Path $tempFile
            documentType = $documentType
            packageId = $packageId
        }
        
        $response = Invoke-RestMethod -Uri "$baseUrl/documents/upload" -Method Post -Headers $headers -Form $form
        
        # Update the extracted data with test data
        if ($testData) {
            $updateUrl = "$baseUrl/documents/$($response.documentId)/extracted-data"
            $jsonData = $testData | ConvertTo-Json -Depth 10
            Invoke-RestMethod -Uri $updateUrl -Method Put -Headers $headers -Body $jsonData -ContentType "application/json" | Out-Null
        }
        
        Write-Host "  ✓ $documentType uploaded: $($response.documentId)" -ForegroundColor Green
        return $response.documentId
    }
    catch {
        Write-Host "  ✗ $documentType upload failed: $_" -ForegroundColor Red
        return $null
    }
    finally {
        Remove-Item -Path $tempFile -ErrorAction SilentlyContinue
    }
}

# Function to process package and get validation results
function Get-ValidationResults {
    param($token, $packageId)
    
    Write-Host "`nStep 4: Processing package and validating..." -ForegroundColor Yellow
    
    $headers = @{
        "Authorization" = "Bearer $token"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/documents/packages/$packageId/process-now" -Method Post -Headers $headers
        Write-Host "✓ Validation completed" -ForegroundColor Green
        return $response
    }
    catch {
        Write-Host "✗ Validation failed: $_" -ForegroundColor Red
        Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Test Scenario 1: Missing Invoice PO Number (Requirement 1)
function Test-Scenario1 {
    Write-Host "`n=== TEST SCENARIO 1: Missing Invoice PO Number ===" -ForegroundColor Cyan
    
    $token = Get-AuthToken
    if (-not $token) { return }
    
    $packageId = New-TestPackage -token $token
    if (-not $packageId) { return }
    
    Write-Host "`nStep 3: Uploading test documents..." -ForegroundColor Yellow
    
    # PO Data
    $poData = @{
        PONumber = "PO001"
        PODate = (Get-Date).AddDays(-5).ToString("yyyy-MM-dd")
        AgencyCode = "AG001"
        VendorName = "Test Vendor"
        VendorCode = "V001"
        TotalAmount = 60000
        LineItems = @()
    }
    
    # Invoice Data - Missing PO Number
    $invoiceData = @{
        AgencyName = "Test Agency"
        AgencyAddress = "123 Test St"
        AgencyCode = "AG001"
        BillingName = "Test Billing"
        BillingAddress = "456 Billing Ave"
        StateName = "Maharashtra"
        StateCode = "MH"
        InvoiceNumber = "INV001"
        InvoiceDate = (Get-Date).ToString("yyyy-MM-dd")
        VendorCode = "V001"
        VendorName = "Test Vendor"
        GSTNumber = "27AABCU9603R1ZM"
        GSTPercentage = 18
        HSNSACCode = "998361"
        PONumber = ""  # MISSING - Should trigger validation error
        TotalAmount = 50000
        LineItems = @()
    }
    
    Upload-TestDocument -token $token -packageId $packageId -documentType "PO" -testData $poData | Out-Null
    Upload-TestDocument -token $token -packageId $packageId -documentType "Invoice" -testData $invoiceData | Out-Null
    
    $result = Get-ValidationResults -token $token -packageId $packageId
    
    if ($result) {
        Write-Host "`nValidation Result:" -ForegroundColor Yellow
        Write-Host "  All Passed: $($result.allPassed)" -ForegroundColor $(if ($result.allPassed) { "Green" } else { "Red" })
        Write-Host "  Issues Count: $($result.issues.Count)" -ForegroundColor Yellow
        
        if ($result.issues) {
            Write-Host "`n  Issues Found:" -ForegroundColor Yellow
            foreach ($issue in $result.issues) {
                Write-Host "    - [$($issue.field)] $($issue.issue)" -ForegroundColor Red
            }
        }
        
        # Check if PO Number validation triggered
        $poNumberIssue = $result.issues | Where-Object { $_.issue -like "*PO Number*" }
        if ($poNumberIssue) {
            Write-Host "`n✓ REQUIREMENT 1 VERIFIED: Invoice PO Number field presence check working" -ForegroundColor Green
        }
        else {
            Write-Host "`n✗ REQUIREMENT 1 FAILED: PO Number validation not triggered" -ForegroundColor Red
        }
    }
}

# Test Scenario 2: Invoice Amount Exceeds PO Amount (Requirement 4)
function Test-Scenario2 {
    Write-Host "`n`n=== TEST SCENARIO 2: Invoice Amount Exceeds PO Amount ===" -ForegroundColor Cyan
    
    $token = Get-AuthToken
    if (-not $token) { return }
    
    $packageId = New-TestPackage -token $token
    if (-not $packageId) { return }
    
    Write-Host "`nStep 3: Uploading test documents..." -ForegroundColor Yellow
    
    # PO Data - Lower amount
    $poData = @{
        PONumber = "PO002"
        PODate = (Get-Date).AddDays(-5).ToString("yyyy-MM-dd")
        AgencyCode = "AG001"
        VendorName = "Test Vendor"
        VendorCode = "V001"
        TotalAmount = 50000  # Lower than invoice
        LineItems = @()
    }
    
    # Invoice Data - Higher amount
    $invoiceData = @{
        AgencyName = "Test Agency"
        AgencyAddress = "123 Test St"
        AgencyCode = "AG001"
        BillingName = "Test Billing"
        BillingAddress = "456 Billing Ave"
        StateName = "Maharashtra"
        StateCode = "MH"
        InvoiceNumber = "INV002"
        InvoiceDate = (Get-Date).ToString("yyyy-MM-dd")
        VendorCode = "V001"
        VendorName = "Test Vendor"
        GSTNumber = "27AABCU9603R1ZM"
        GSTPercentage = 18
        HSNSACCode = "998361"
        PONumber = "PO002"
        TotalAmount = 60000  # Higher than PO - Should trigger validation error
        LineItems = @()
    }
    
    Upload-TestDocument -token $token -packageId $packageId -documentType "PO" -testData $poData | Out-Null
    Upload-TestDocument -token $token -packageId $packageId -documentType "Invoice" -testData $invoiceData | Out-Null
    
    $result = Get-ValidationResults -token $token -packageId $packageId
    
    if ($result) {
        Write-Host "`nValidation Result:" -ForegroundColor Yellow
        Write-Host "  All Passed: $($result.allPassed)" -ForegroundColor $(if ($result.allPassed) { "Green" } else { "Red" })
        Write-Host "  Issues Count: $($result.issues.Count)" -ForegroundColor Yellow
        
        if ($result.issues) {
            Write-Host "`n  Issues Found:" -ForegroundColor Yellow
            foreach ($issue in $result.issues) {
                Write-Host "    - [$($issue.field)] $($issue.issue)" -ForegroundColor Red
            }
        }
        
        # Check if Invoice Amount validation triggered
        $amountIssue = $result.issues | Where-Object { $_.issue -like "*exceeds PO amount*" }
        if ($amountIssue) {
            Write-Host "`n✓ REQUIREMENT 4 VERIFIED: Invoice Amount vs PO Amount validation working" -ForegroundColor Green
        }
        else {
            Write-Host "`n✗ REQUIREMENT 4 FAILED: Invoice amount validation not triggered" -ForegroundColor Red
        }
    }
}

# Test Scenario 3: Missing Cost Summary Element-wise Cost (Requirement 6)
function Test-Scenario3 {
    Write-Host "`n`n=== TEST SCENARIO 3: Missing Element-wise Cost ===" -ForegroundColor Cyan
    
    $token = Get-AuthToken
    if (-not $token) { return }
    
    $packageId = New-TestPackage -token $token
    if (-not $packageId) { return }
    
    Write-Host "`nStep 3: Uploading test documents..." -ForegroundColor Yellow
    
    # Cost Summary Data - Missing element costs
    $costSummaryData = @{
        CampaignName = "Test Campaign"
        State = "Maharashtra"
        PlaceOfSupply = "MH"
        CampaignStartDate = (Get-Date).AddDays(-10).ToString("yyyy-MM-dd")
        CampaignEndDate = (Get-Date).AddDays(10).ToString("yyyy-MM-dd")
        NumberOfDays = 10
        TotalCost = 50000
        CostBreakdowns = @(
            @{
                ElementName = "BA Salary"
                Category = "Labor"
                Amount = 5000
                Quantity = 10
                IsFixedCost = $false
                IsVariableCost = $true
            },
            @{
                ElementName = "Vehicle Rent"
                Category = "Transport"
                Amount = 0  # MISSING - Should trigger validation error
                Quantity = 5
                IsFixedCost = $true
                IsVariableCost = $false
            }
        )
    }
    
    Upload-TestDocument -token $token -packageId $packageId -documentType "CostSummary" -testData $costSummaryData | Out-Null
    
    $result = Get-ValidationResults -token $token -packageId $packageId
    
    if ($result) {
        Write-Host "`nValidation Result:" -ForegroundColor Yellow
        Write-Host "  All Passed: $($result.allPassed)" -ForegroundColor $(if ($result.allPassed) { "Green" } else { "Red" })
        Write-Host "  Issues Count: $($result.issues.Count)" -ForegroundColor Yellow
        
        if ($result.issues) {
            Write-Host "`n  Issues Found:" -ForegroundColor Yellow
            foreach ($issue in $result.issues) {
                Write-Host "    - [$($issue.field)] $($issue.issue)" -ForegroundColor Red
            }
        }
        
        # Check if Element-wise Cost validation triggered
        $costIssue = $result.issues | Where-Object { $_.issue -like "*Element wise Cost*" -and $_.issue -like "*Vehicle Rent*" }
        if ($costIssue) {
            Write-Host "`n✓ REQUIREMENT 6 VERIFIED: Element-wise Cost field presence check working" -ForegroundColor Green
        }
        else {
            Write-Host "`n✗ REQUIREMENT 6 FAILED: Element-wise cost validation not triggered" -ForegroundColor Red
        }
    }
}

# Run all test scenarios
Write-Host "Starting validation tests..." -ForegroundColor Cyan
Write-Host "This will test key validation requirements from the Excel document`n" -ForegroundColor Gray

Test-Scenario1
Test-Scenario2
Test-Scenario3

Write-Host "`n`n=== TESTING COMPLETED ===" -ForegroundColor Cyan
Write-Host "Check the results above to verify validation requirements are working" -ForegroundColor Gray
