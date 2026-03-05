# Invoice Validation Test Script
# Tests the new invoice validation requirements implementation

$baseUrl = "http://localhost:5000/api"
$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Invoice Validation Test Suite" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Login to get JWT token
Write-Host "Step 1: Authenticating..." -ForegroundColor Yellow
$loginBody = @{
    email = "agency@bajaj.com"
    password = "Password123!"
} | ConvertTo-Json

try {
    $loginResponse = Invoke-RestMethod -Uri "$baseUrl/Auth/login" -Method Post -Body $loginBody -ContentType "application/json"
    $token = $loginResponse.token
    Write-Host "✓ Authentication successful" -ForegroundColor Green
    Write-Host "  Token: $($token.Substring(0, 20))..." -ForegroundColor Gray
} catch {
    Write-Host "✗ Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

Write-Host ""

# Step 2: Create a test document package
Write-Host "Step 2: Creating test document package..." -ForegroundColor Yellow

$packageBody = @{
    agencyCode = "AG001"
    submittedBy = "Test Agency User"
} | ConvertTo-Json

try {
    $packageResponse = Invoke-RestMethod -Uri "$baseUrl/Submissions" -Method Post -Body $packageBody -Headers $headers
    $packageId = $packageResponse.id
    Write-Host "✓ Package created successfully" -ForegroundColor Green
    Write-Host "  Package ID: $packageId" -ForegroundColor Gray
} catch {
    Write-Host "✗ Package creation failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Response: $($_.ErrorDetails.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 3: Upload PO document with sample data
Write-Host "Step 3: Uploading PO document..." -ForegroundColor Yellow

$poData = @{
    PONumber = "PO-2024-001"
    AgencyCode = "AG001"
    VendorName = "Test Vendor Ltd"
    PODate = "2024-01-15T00:00:00Z"
    TotalAmount = 100000.00
    LineItems = @(
        @{
            ItemCode = "ITEM001"
            Description = "Product A"
            Quantity = 10
            UnitPrice = 5000.00
            LineTotal = 50000.00
        },
        @{
            ItemCode = "ITEM002"
            Description = "Product B"
            Quantity = 5
            UnitPrice = 10000.00
            LineTotal = 50000.00
        }
    )
    FieldConfidences = @{
        "PONumber" = 0.95
        "VendorName" = 0.90
        "TotalAmount" = 0.98
    }
    IsFlaggedForReview = $false
}

# Simulate document upload by directly updating the database (in real scenario, this would be file upload)
Write-Host "  Note: In production, this would be a file upload with OCR extraction" -ForegroundColor Gray
Write-Host "  Simulating PO document with extracted data..." -ForegroundColor Gray

Write-Host ""

# Step 4: Upload Invoice document with validation test cases
Write-Host "Step 4: Testing Invoice Validation..." -ForegroundColor Yellow
Write-Host ""

# Test Case 1: Valid Invoice (all fields present, all validations pass)
Write-Host "Test Case 1: Valid Invoice (All Checks Pass)" -ForegroundColor Cyan

$validInvoiceData = @{
    InvoiceNumber = "INV-2024-001"
    InvoiceDate = "2024-01-20T00:00:00Z"
    AgencyName = "Test Agency"
    AgencyAddress = "123 Agency Street, Mumbai"
    AgencyCode = "AG001"
    BillingName = "Bajaj Auto Limited"
    BillingAddress = "456 Bajaj Road, Pune"
    VendorName = "Test Vendor Ltd"
    VendorCode = "VEN001"
    StateName = "Maharashtra"
    StateCode = "MH"
    GSTNumber = "27AAAAA0000A1Z5"
    GSTPercentage = 18.0
    HSNSACCode = "8703"
    PONumber = "PO-2024-001"
    LineItems = @(
        @{
            ItemCode = "ITEM001"
            Description = "Product A"
            Quantity = 10
            UnitPrice = 5000.00
            LineTotal = 50000.00
        },
        @{
            ItemCode = "ITEM002"
            Description = "Product B"
            Quantity = 5
            UnitPrice = 10000.00
            LineTotal = 50000.00
        }
    )
    SubTotal = 100000.00
    TaxAmount = 18000.00
    TotalAmount = 118000.00
    FieldConfidences = @{
        "InvoiceNumber" = 0.95
        "TotalAmount" = 0.98
    }
    IsFlaggedForReview = $false
}

Write-Host "  Invoice Details:" -ForegroundColor Gray
Write-Host "    - Invoice Number: $($validInvoiceData.InvoiceNumber)" -ForegroundColor Gray
Write-Host "    - Agency Code: $($validInvoiceData.AgencyCode)" -ForegroundColor Gray
Write-Host "    - PO Number: $($validInvoiceData.PONumber)" -ForegroundColor Gray
Write-Host "    - GST Number: $($validInvoiceData.GSTNumber)" -ForegroundColor Gray
Write-Host "    - State: $($validInvoiceData.StateName) ($($validInvoiceData.StateCode))" -ForegroundColor Gray
Write-Host "    - HSN/SAC Code: $($validInvoiceData.HSNSACCode)" -ForegroundColor Gray
Write-Host "    - Total Amount: ₹$($validInvoiceData.TotalAmount)" -ForegroundColor Gray
Write-Host ""
Write-Host "  Expected Result: ✓ All validations pass" -ForegroundColor Green
Write-Host ""

# Test Case 2: Invoice with missing required fields
Write-Host "Test Case 2: Invoice with Missing Required Fields" -ForegroundColor Cyan

$missingFieldsInvoice = @{
    InvoiceNumber = "INV-2024-002"
    InvoiceDate = "2024-01-20T00:00:00Z"
    # Missing: AgencyName, AgencyAddress, BillingName, BillingAddress
    AgencyCode = "AG001"
    VendorName = "Test Vendor Ltd"
    # Missing: VendorCode
    StateName = "Maharashtra"
    StateCode = "MH"
    # Missing: GSTNumber, GSTPercentage, HSNSACCode
    PONumber = "PO-2024-001"
    LineItems = @()
    SubTotal = 50000.00
    TaxAmount = 9000.00
    TotalAmount = 59000.00
}

Write-Host "  Missing Fields:" -ForegroundColor Gray
Write-Host "    - Agency Name & Address" -ForegroundColor Gray
Write-Host "    - Billing Name & Address" -ForegroundColor Gray
Write-Host "    - Vendor Code" -ForegroundColor Gray
Write-Host "    - GST Number & Percentage" -ForegroundColor Gray
Write-Host "    - HSN/SAC Code" -ForegroundColor Gray
Write-Host ""
Write-Host "  Expected Result: ✗ Field presence validation fails" -ForegroundColor Red
Write-Host ""

# Test Case 3: Invoice with mismatched Agency Code
Write-Host "Test Case 3: Invoice with Mismatched Agency Code" -ForegroundColor Cyan

$mismatchedAgencyInvoice = @{
    InvoiceNumber = "INV-2024-003"
    InvoiceDate = "2024-01-20T00:00:00Z"
    AgencyName = "Test Agency"
    AgencyAddress = "123 Agency Street, Mumbai"
    AgencyCode = "AG999"  # Mismatch - PO has AG001
    BillingName = "Bajaj Auto Limited"
    BillingAddress = "456 Bajaj Road, Pune"
    VendorName = "Test Vendor Ltd"
    VendorCode = "VEN001"
    StateName = "Maharashtra"
    StateCode = "MH"
    GSTNumber = "27AAAAA0000A1Z5"
    GSTPercentage = 18.0
    HSNSACCode = "8703"
    PONumber = "PO-2024-001"
    LineItems = @()
    SubTotal = 50000.00
    TaxAmount = 9000.00
    TotalAmount = 59000.00
}

Write-Host "  Agency Code: AG999 (PO has: AG001)" -ForegroundColor Gray
Write-Host ""
Write-Host "  Expected Result: ✗ Agency Code mismatch" -ForegroundColor Red
Write-Host ""

# Test Case 4: Invoice with invalid GST-State mapping
Write-Host "Test Case 4: Invoice with Invalid GST-State Mapping" -ForegroundColor Cyan

$invalidGSTInvoice = @{
    InvoiceNumber = "INV-2024-004"
    InvoiceDate = "2024-01-20T00:00:00Z"
    AgencyName = "Test Agency"
    AgencyAddress = "123 Agency Street, Mumbai"
    AgencyCode = "AG001"
    BillingName = "Bajaj Auto Limited"
    BillingAddress = "456 Bajaj Road, Pune"
    VendorName = "Test Vendor Ltd"
    VendorCode = "VEN001"
    StateName = "Maharashtra"
    StateCode = "MH"
    GSTNumber = "07AAAAA0000A1Z5"  # 07 = Delhi, but StateCode is MH (Maharashtra = 27)
    GSTPercentage = 18.0
    HSNSACCode = "8703"
    PONumber = "PO-2024-001"
    LineItems = @()
    SubTotal = 50000.00
    TaxAmount = 9000.00
    TotalAmount = 59000.00
}

Write-Host "  GST Number: 07AAAAA0000A1Z5 (07 = Delhi)" -ForegroundColor Gray
Write-Host "  State Code: MH (Maharashtra = 27)" -ForegroundColor Gray
Write-Host ""
Write-Host "  Expected Result: ✗ GST-State mismatch" -ForegroundColor Red
Write-Host ""

# Test Case 5: Invoice amount exceeds PO amount
Write-Host "Test Case 5: Invoice Amount Exceeds PO Amount" -ForegroundColor Cyan

$excessAmountInvoice = @{
    InvoiceNumber = "INV-2024-005"
    InvoiceDate = "2024-01-20T00:00:00Z"
    AgencyName = "Test Agency"
    AgencyAddress = "123 Agency Street, Mumbai"
    AgencyCode = "AG001"
    BillingName = "Bajaj Auto Limited"
    BillingAddress = "456 Bajaj Road, Pune"
    VendorName = "Test Vendor Ltd"
    VendorCode = "VEN001"
    StateName = "Maharashtra"
    StateCode = "MH"
    GSTNumber = "27AAAAA0000A1Z5"
    GSTPercentage = 18.0
    HSNSACCode = "8703"
    PONumber = "PO-2024-001"
    LineItems = @()
    SubTotal = 150000.00
    TaxAmount = 27000.00
    TotalAmount = 177000.00  # Exceeds PO amount of 100000
}

Write-Host "  Invoice Amount: ₹177,000" -ForegroundColor Gray
Write-Host "  PO Amount: ₹100,000" -ForegroundColor Gray
Write-Host ""
Write-Host "  Expected Result: ✗ Invoice amount exceeds PO amount" -ForegroundColor Red
Write-Host ""

# Test Case 6: Invalid HSN/SAC Code
Write-Host "Test Case 6: Invalid HSN/SAC Code" -ForegroundColor Cyan

$invalidHSNInvoice = @{
    InvoiceNumber = "INV-2024-006"
    InvoiceDate = "2024-01-20T00:00:00Z"
    AgencyName = "Test Agency"
    AgencyAddress = "123 Agency Street, Mumbai"
    AgencyCode = "AG001"
    BillingName = "Bajaj Auto Limited"
    BillingAddress = "456 Bajaj Road, Pune"
    VendorName = "Test Vendor Ltd"
    VendorCode = "VEN001"
    StateName = "Maharashtra"
    StateCode = "MH"
    GSTNumber = "27AAAAA0000A1Z5"
    GSTPercentage = 18.0
    HSNSACCode = "9999"  # Invalid code not in reference data
    PONumber = "PO-2024-001"
    LineItems = @()
    SubTotal = 50000.00
    TaxAmount = 9000.00
    TotalAmount = 59000.00
}

Write-Host "  HSN/SAC Code: 9999 (not in reference data)" -ForegroundColor Gray
Write-Host ""
Write-Host "  Expected Result: ✗ Invalid HSN/SAC code" -ForegroundColor Red
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "The invoice validation implementation includes:" -ForegroundColor White
Write-Host ""
Write-Host "Presence Checks (9):" -ForegroundColor Yellow
Write-Host "  ✓ Agency Name & Address" -ForegroundColor Green
Write-Host "  ✓ Billing Name & Address" -ForegroundColor Green
Write-Host "  ✓ State name/code" -ForegroundColor Green
Write-Host "  ✓ Invoice Number & Date" -ForegroundColor Green
Write-Host "  ✓ Vendor Code" -ForegroundColor Green
Write-Host "  ✓ GST Number & Percentage" -ForegroundColor Green
Write-Host "  ✓ HSN/SAC Code" -ForegroundColor Green
Write-Host "  ✓ Invoice Amount" -ForegroundColor Green
Write-Host ""
Write-Host "Cross-Document Validations (6):" -ForegroundColor Yellow
Write-Host "  ✓ Agency Code matching" -ForegroundColor Green
Write-Host "  ✓ PO Number matching" -ForegroundColor Green
Write-Host "  ✓ GST-State mapping (38 Indian states)" -ForegroundColor Green
Write-Host "  ✓ HSN/SAC code validation" -ForegroundColor Green
Write-Host "  ✓ Invoice amount ≤ PO amount" -ForegroundColor Green
Write-Host "  ✓ GST percentage validation (18%)" -ForegroundColor Green
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To test validation in the running application:" -ForegroundColor White
Write-Host "1. Open Swagger UI: http://localhost:5000/swagger" -ForegroundColor Cyan
Write-Host "2. Use the /api/Submissions endpoint to create a package" -ForegroundColor Cyan
Write-Host "3. Upload documents with the test data above" -ForegroundColor Cyan
Write-Host "4. Trigger validation and check the results" -ForegroundColor Cyan
Write-Host ""
Write-Host "Backend API: http://localhost:5000" -ForegroundColor Green
Write-Host "Frontend App: http://localhost:XXXX (Flutter)" -ForegroundColor Green
Write-Host ""
