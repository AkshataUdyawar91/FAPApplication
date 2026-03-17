# Invoice Validation Testing Guide

## System Status ✅

- **Backend API**: Running on http://localhost:5000
- **Frontend**: Running on Chrome
- **Swagger UI**: http://localhost:5000/swagger

## Authentication

Login credentials for testing:
```
Email: agency@bajaj.com
Password: Password123!
```

## Test the Invoice Validation

### Option 1: Using Swagger UI (Recommended)

1. Open http://localhost:5000/swagger in your browser
2. Click on "Authorize" button (top right)
3. Login with the credentials above to get a JWT token
4. Test the validation endpoints

### Option 2: Using PowerShell/curl

```powershell
# 1. Login
$loginBody = '{"email":"agency@bajaj.com","password":"Password123!"}'
$loginResponse = Invoke-RestMethod -Uri "http://localhost:5000/api/Auth/login" -Method Post -Body $loginBody -ContentType "application/json"
$token = $loginResponse.token

# 2. Create headers with token
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

# 3. Create a document package
$packageBody = '{"agencyCode":"AG001","submittedBy":"Test User"}'
$package = Invoke-RestMethod -Uri "http://localhost:5000/api/Submissions" -Method Post -Body $packageBody -Headers $headers

Write-Host "Package created: $($package.id)"
```

## Invoice Validation Test Cases

### Test Case 1: Valid Invoice ✅
**All fields present, all validations pass**

```json
{
  "invoiceNumber": "INV-2024-001",
  "invoiceDate": "2024-01-20T00:00:00Z",
  "agencyName": "Test Agency",
  "agencyAddress": "123 Agency Street, Mumbai",
  "agencyCode": "AG001",
  "billingName": "Bajaj Auto Limited",
  "billingAddress": "456 Bajaj Road, Pune",
  "vendorName": "Test Vendor Ltd",
  "vendorCode": "VEN001",
  "stateName": "Maharashtra",
  "stateCode": "MH",
  "gstNumber": "27AAAAA0000A1Z5",
  "gstPercentage": 18.0,
  "hsnSacCode": "8703",
  "poNumber": "PO-2024-001",
  "totalAmount": 100000.00
}
```

**Expected Result**: ✅ All validations pass

---

### Test Case 2: Missing Required Fields ❌

```json
{
  "invoiceNumber": "INV-2024-002",
  "invoiceDate": "2024-01-20T00:00:00Z",
  "agencyCode": "AG001",
  "vendorName": "Test Vendor Ltd",
  "stateName": "Maharashtra",
  "stateCode": "MH",
  "poNumber": "PO-2024-001",
  "totalAmount": 50000.00
}
```

**Missing Fields**:
- Agency Name & Address
- Billing Name & Address
- Vendor Code
- GST Number & Percentage
- HSN/SAC Code

**Expected Result**: ❌ Field presence validation fails

---

### Test Case 3: Agency Code Mismatch ❌

```json
{
  "invoiceNumber": "INV-2024-003",
  "agencyCode": "AG999",
  "poNumber": "PO-2024-001",
  ...
}
```

**Issue**: Invoice has `AG999` but PO has `AG001`

**Expected Result**: ❌ Agency Code mismatch error

---

### Test Case 4: Invalid GST-State Mapping ❌

```json
{
  "gstNumber": "07AAAAA0000A1Z5",
  "stateCode": "MH",
  ...
}
```

**Issue**: 
- GST starts with `07` (Delhi)
- State Code is `MH` (Maharashtra = 27)

**Expected Result**: ❌ GST-State mismatch error

---

### Test Case 5: Invoice Amount Exceeds PO ❌

```json
{
  "totalAmount": 150000.00,
  "poNumber": "PO-2024-001",
  ...
}
```

**Issue**: Invoice amount (₹150,000) > PO amount (₹100,000)

**Expected Result**: ❌ Amount validation fails

---

### Test Case 6: Invalid HSN/SAC Code ❌

```json
{
  "hsnSacCode": "9999",
  ...
}
```

**Issue**: Code `9999` not in reference data

**Expected Result**: ❌ Invalid HSN/SAC code error

---

### Test Case 7: Incorrect GST Percentage ❌

```json
{
  "gstPercentage": 12.0,
  "stateCode": "MH",
  ...
}
```

**Issue**: GST is 12% but expected 18% (default)

**Expected Result**: ❌ GST percentage mismatch

---

## Validation Implementation Details

### Presence Checks (9 fields)
1. ✅ Agency Name
2. ✅ Agency Address
3. ✅ Billing Name
4. ✅ Billing Address
5. ✅ State Name/Code
6. ✅ Invoice Number & Date
7. ✅ Vendor Code
8. ✅ GST Number & Percentage
9. ✅ HSN/SAC Code

### Cross-Document Validations (6 checks)
1. ✅ Agency Code matches PO
2. ✅ PO Number matches PO document
3. ✅ GST Number matches State (first 2 digits)
4. ✅ HSN/SAC Code exists in reference data
5. ✅ Invoice Amount ≤ PO Amount
6. ✅ GST Percentage matches expected (18%)

## GST State Code Reference

The system validates GST numbers against Indian state codes:

| GST Code | State | Code |
|----------|-------|------|
| 01 | Jammu and Kashmir | JK |
| 07 | Delhi | DL |
| 27 | Maharashtra | MH |
| 29 | Karnataka | KA |
| 33 | Tamil Nadu | TN |
| ... | (38 states total) | ... |

## HSN/SAC Codes (Sample)

Valid codes in the system:
- **HSN**: 8703, 8704, 8711, 8708, 8714, 8716 (automotive)
- **SAC**: 995411-995415, 996511-996515, 998511-998515 (services)

## API Endpoints

### Validation Endpoints
- `POST /api/Submissions` - Create package
- `POST /api/Submissions/{id}/documents` - Upload document
- `POST /api/Submissions/{id}/validate` - Trigger validation
- `GET /api/Submissions/{id}/validation` - Get validation results

### Authentication
- `POST /api/Auth/login` - Get JWT token

## Verification Steps

1. ✅ Backend API is running
2. ✅ Authentication works
3. ✅ All validation code is implemented
4. ✅ Reference data service configured
5. ✅ DTOs updated with required fields
6. ✅ Tests updated and passing

## Next Steps

To fully test the validation:

1. **Use Swagger UI** to interact with the API
2. **Create a document package** using the Submissions endpoint
3. **Upload documents** with the test data above
4. **Trigger validation** and observe the results
5. **Check validation details** in the response

The validation will return detailed information about:
- Which fields are missing
- Which cross-document checks failed
- Specific error messages for each validation

---

**Status**: ✅ Implementation Complete and Running
**Backend**: http://localhost:5000
**Swagger**: http://localhost:5000/swagger
