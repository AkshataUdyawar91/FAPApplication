# Quick Start: Testing All Validations

## 🚀 Fastest Way to Test All Validations

### Option 1: Using Swagger UI (5 minutes)

1. **Start the backend** (if not already running):
```bash
cd backend/src/BajajDocumentProcessing.API
dotnet run
```

2. **Open Swagger UI**: http://localhost:5000/swagger

3. **Login and get token**:
   - Expand `POST /api/auth/login`
   - Click "Try it out"
   - Use body:
   ```json
   {
     "email": "agency@bajaj.com",
     "password": "Password123!"
   }
   ```
   - Click "Execute"
   - Copy the token from response
   - Click "Authorize" button (top right)
   - Enter: `Bearer YOUR_TOKEN_HERE`
   - Click "Authorize"

4. **Test validation directly**:
   - Scroll to `POST /api/test/validate-package` (if available)
   - OR create a package and submit it

### Option 2: Using PowerShell Script (Automated)

Save this as `test-validations.ps1`:

```powershell
# Test All Validations Script
$baseUrl = "http://localhost:5000/api"

# Login
$loginBody = @{
    email = "agency@bajaj.com"
    password = "Password123!"
} | ConvertTo-Json

$loginResponse = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
$token = $loginResponse.token

$headers = @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
}

Write-Host "✅ Logged in successfully" -ForegroundColor Green

# Test Scenario 1: Valid Package (All Pass)
Write-Host "`n📋 Test 1: Valid Package (All Validations Should Pass)" -ForegroundColor Cyan

$validPackage = @{
    poData = @{
        poNumber = "PO-2024-001"
        poDate = "2024-01-15T00:00:00Z"
        vendorName = "ABC Suppliers"
        agencyCode = "AG001"
        totalAmount = 100000
        lineItems = @(
            @{
                itemCode = "ITEM001"
                description = "Product A"
                quantity = 10
                unitPrice = 5000
            }
        )
    }
    invoiceData = @{
        invoiceNumber = "INV-2024-001"
        invoiceDate = "2024-01-20T00:00:00Z"
        vendorName = "ABC Suppliers"
        vendorCode = "V001"
        agencyName = "XYZ Agency"
        agencyCode = "AG001"
        agencyAddress = "123 Main St, Mumbai"
        billingName = "XYZ Agency"
        billingAddress = "123 Main St, Mumbai"
        stateName = "Maharashtra"
        stateCode = "27"
        gstNumber = "27AAAAA0000A1Z5"
        gstPercentage = 18
        hsnSacCode = "8703"
        poNumber = "PO-2024-001"
        totalAmount = 95000
        lineItems = @(
            @{
                itemCode = "ITEM001"
                description = "Product A"
                quantity = 10
                unitPrice = 5000
            }
        )
    }
    costSummaryData = @{
        placeOfSupply = "27"
        state = "Maharashtra"
        numberOfDays = 5
        totalCost = 95000
        costBreakdowns = @(
            @{
                elementName = "Venue Rental"
                category = "Fixed"
                amount = 5000
                quantity = 1
                unit = "venue"
                isFixedCost = $true
                isVariableCost = $false
            }
        )
    }
    activityData = @{
        dealerName = "ABC Motors"
        dealerCode = "D001"
        totalDays = 5
        locationActivities = @(
            @{
                locationName = "Mumbai Central"
                district = "Mumbai"
                pincode = "400001"
                numberOfDays = 5
            }
        )
    }
    photoCount = 5
} | ConvertTo-Json -Depth 10

# Note: You'll need to create an endpoint to test this directly
# For now, this shows the structure

Write-Host "Package structure created" -ForegroundColor Yellow
Write-Host "Note: You need to implement a test endpoint or use the full upload flow" -ForegroundColor Yellow

# Test Scenario 2: Invoice Field Missing
Write-Host "`n📋 Test 2: Invoice Missing Fields (Should Fail)" -ForegroundColor Cyan

$invalidInvoice = @{
    invoiceNumber = "INV-2024-002"
    invoiceDate = "2024-01-20T00:00:00Z"
    # Missing: agencyName, gstNumber, hsnSacCode, etc.
    totalAmount = 50000
} | ConvertTo-Json

Write-Host "Invalid invoice structure created" -ForegroundColor Yellow

# Test Scenario 3: GST State Mismatch
Write-Host "`n📋 Test 3: GST State Mismatch (Should Fail)" -ForegroundColor Cyan

$gstMismatch = @{
    gstNumber = "29AAAAA0000A1Z5"  # Karnataka (29)
    stateCode = "27"                # Maharashtra (27)
} | ConvertTo-Json

Write-Host "GST mismatch test data created" -ForegroundColor Yellow

Write-Host "`n✅ Test data prepared. Use Swagger UI to test manually." -ForegroundColor Green
Write-Host "Or implement a test endpoint: POST /api/test/validate-package" -ForegroundColor Yellow
```

Run it:
```powershell
.\test-validations.ps1
```

### Option 3: Using cURL (Command Line)

```bash
# 1. Login
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"agency@bajaj.com","password":"Password123!"}'

# Copy the token from response

# 2. Test validation (replace YOUR_TOKEN)
curl -X POST http://localhost:5000/api/submissions/{packageId}/submit \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json"
```

---

## 📊 What to Check in Results

### ✅ All Validations Pass
```json
{
  "allPassed": true,
  "invoiceFieldPresence": { "allFieldsPresent": true },
  "invoiceCrossDocument": { "allChecksPass": true },
  "costSummaryFieldPresence": { "allFieldsPresent": true },
  "costSummaryCrossDocument": { "allChecksPass": true },
  "activityFieldPresence": { "allFieldsPresent": true },
  "activityCrossDocument": { "allChecksPass": true },
  "photoFieldPresence": { "allFieldsPresent": true },
  "photoCrossDocument": { "allChecksPass": true },
  "issues": []
}
```

### ❌ Validation Failures
```json
{
  "allPassed": false,
  "invoiceFieldPresence": {
    "allFieldsPresent": false,
    "missingFields": ["Agency Name", "GST Number"]
  },
  "issues": [
    {
      "field": "Invoice Fields",
      "issue": "Missing required fields: Agency Name, GST Number",
      "severity": "Error"
    }
  ]
}
```

---

## 🧪 Running Unit Tests

```bash
cd backend

# Run all tests
dotnet test

# Run only validation tests
dotnet test --filter "FullyQualifiedName~ValidationAgent"

# Run with detailed output
dotnet test --logger "console;verbosity=detailed"

# Generate coverage report
dotnet test /p:CollectCoverage=true /p:CoverageReportFormat=html
```

---

## 📝 Test Checklist

Use this checklist to verify all validations:

### Invoice Validations (15)
- [ ] TC-INV-FP-001: Agency Name Missing
- [ ] TC-INV-FP-002: Agency Address Missing
- [ ] TC-INV-FP-003: Billing Name Missing
- [ ] TC-INV-FP-004: Billing Address Missing
- [ ] TC-INV-FP-005: State Name/Code Missing
- [ ] TC-INV-FP-006: Invoice Number Missing
- [ ] TC-INV-FP-007: Invoice Date Missing
- [ ] TC-INV-FP-008: Vendor Code Missing
- [ ] TC-INV-FP-009: GST Number Missing
- [ ] TC-INV-FP-010: GST Percentage Missing
- [ ] TC-INV-FP-011: HSN/SAC Code Missing
- [ ] TC-INV-FP-012: Invoice Amount Missing
- [ ] TC-INV-CD-001: Agency Code Mismatch
- [ ] TC-INV-CD-002: PO Number Mismatch
- [ ] TC-INV-CD-003: GST State Mapping Invalid
- [ ] TC-INV-CD-004: HSN/SAC Code Invalid
- [ ] TC-INV-CD-005: Invoice Amount Exceeds PO
- [ ] TC-INV-CD-006: GST Percentage Invalid

### Cost Summary Validations (9)
- [ ] TC-CS-FP-001: Place of Supply Missing
- [ ] TC-CS-FP-002: Element wise Cost Missing
- [ ] TC-CS-FP-003: Number of Days Missing
- [ ] TC-CS-FP-004: Element wise Quantity Missing
- [ ] TC-CS-FP-005: Total Cost Missing
- [ ] TC-CS-CD-001: Total Cost Exceeds Invoice
- [ ] TC-CS-CD-002: Element Cost Doesn't Match Rate
- [ ] TC-CS-CD-003: Fixed Cost Exceeds Limit
- [ ] TC-CS-CD-004: Variable Cost Exceeds Limit

### Activity Summary Validations (3)
- [ ] TC-ACT-FP-001: Dealer/Location Missing
- [ ] TC-ACT-FP-002: All Fields Present
- [ ] TC-ACT-CD-001: Days Mismatch

### Photo Proofs Validations (6)
- [ ] TC-PHOTO-FP-001: Date/Timestamp Missing
- [ ] TC-PHOTO-FP-002: Location Missing
- [ ] TC-PHOTO-FP-003: Blue T-shirt Not Detected
- [ ] TC-PHOTO-FP-004: Vehicle Not Detected
- [ ] TC-PHOTO-CD-001: Photo Count Mismatch
- [ ] TC-PHOTO-CD-002: Man-Days Exceeds Days

---

## 🎯 Quick Validation Test

**Fastest way to see validation in action:**

1. Open Swagger: http://localhost:5000/swagger
2. Login with agency@bajaj.com / Password123!
3. Look for any existing packages in the database
4. Call the validation endpoint with a package ID
5. Review the detailed validation results

**Expected time:** 2-3 minutes

---

## 📚 Additional Resources

- **Detailed Test Cases**: See `VALIDATION_TEST_CASES.md`
- **Testing Guide**: See `VALIDATION_TESTING_GUIDE.md`
- **Implementation Summary**: See `VALIDATION_IMPLEMENTATION_SUMMARY.md`

---

## 🆘 Troubleshooting

### Backend not running?
```bash
cd backend/src/BajajDocumentProcessing.API
dotnet run
```

### Can't login?
- Check database is running
- Verify users are seeded
- Check connection string in appsettings.json

### Validation not working?
- Check package has all required documents
- Verify extracted data is in correct JSON format
- Review logs for detailed error messages

---

## ✅ Success Criteria

You've successfully tested all validations when:
1. ✅ All 33 validation requirements have been tested
2. ✅ Valid packages pass all validations
3. ✅ Invalid packages fail with correct error messages
4. ✅ Validation results are saved to database
5. ✅ Package state updates correctly (Validated/ValidationFailed)

**Total Testing Time:** 15-30 minutes for complete validation testing
