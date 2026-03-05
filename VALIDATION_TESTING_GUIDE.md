# Validation Testing Guide

## Overview

This guide provides step-by-step instructions for testing all 33 validation requirements in the Bajaj Document Processing System.

## Prerequisites

- Backend API running on http://localhost:5000
- Frontend running in Chrome
- SQL Server Express with seeded data
- Swagger UI accessible at http://localhost:5000/swagger

## Test Credentials

```
Agency: agency@bajaj.com / Password123!
ASM: asm@bajaj.com / Password123!
HQ: hq@bajaj.com / Password123!
```

## Testing Approaches

### 1. Manual Testing via Swagger UI (Recommended for Quick Testing)
### 2. Automated Unit Tests (Comprehensive Coverage)
### 3. Integration Tests (End-to-End Workflows)

---

## Approach 1: Manual Testing via Swagger UI

### Step 1: Login and Get JWT Token

1. Open Swagger UI: http://localhost:5000/swagger
2. Navigate to **POST /api/auth/login**
3. Click "Try it out"
4. Use request body:
```json
{
  "email": "agency@bajaj.com",
  "password": "Password123!"
}
```
5. Click "Execute"
6. Copy the JWT token from the response
7. Click "Authorize" button at the top
8. Enter: `Bearer YOUR_JWT_TOKEN`
9. Click "Authorize"

### Step 2: Create a Test Document Package

1. Navigate to **POST /api/documents/upload**
2. Upload test documents (PO, Invoice, Cost Summary, Activity, Photos)
3. Note the `packageId` from the response

### Step 3: Trigger Validation

1. Navigate to **POST /api/submissions/{packageId}/submit**
2. Enter the `packageId` from Step 2
3. Click "Execute"
4. Review the validation results in the response

### Step 4: Review Validation Results

The response will contain:
- `allPassed`: Overall validation status
- `sapVerification`: SAP PO verification results
- `amountConsistency`: Invoice vs Cost Summary amount check
- `lineItemMatching`: PO vs Invoice line items
- `completeness`: Required documents check
- `dateValidation`: Date consistency checks
- `vendorMatching`: Vendor name matching
- `invoiceFieldPresence`: Invoice required fields (9 checks)
- `invoiceCrossDocument`: Invoice cross-validation (6 checks)
- `costSummaryFieldPresence`: Cost Summary required fields (5 checks)
- `costSummaryCrossDocument`: Cost Summary cross-validation (4 checks)
- `activityFieldPresence`: Activity required fields (2 checks)
- `activityCrossDocument`: Activity cross-validation (1 check)
- `photoFieldPresence`: Photo required fields (4 checks)
- `photoCrossDocument`: Photo cross-validation (2 checks)
- `issues`: List of all validation failures with details

---

## Approach 2: Automated Unit Tests

### Running Existing Tests

```bash
cd backend
dotnet test
```

### Test Coverage

The system includes property-based tests for:
- Amount Consistency Validation (Property 11)
- Line Item Matching (Property 12)
- Completeness Validation (Property 13)
- SAP Connection Failure Handling (Property 16)

---

## Approach 3: Creating Test Data

### Test Scenario 1: Valid Package (All Validations Pass)

**PO Data:**
```json
{
  "poNumber": "PO-2024-001",
  "poDate": "2024-01-15",
  "vendorName": "ABC Suppliers",
  "agencyCode": "AG001",
  "totalAmount": 100000,
  "lineItems": [
    { "itemCode": "ITEM001", "description": "Product A", "quantity": 10, "unitPrice": 5000 },
    { "itemCode": "ITEM002", "description": "Product B", "quantity": 20, "unitPrice": 2500 }
  ]
}
```

**Invoice Data:**
```json
{
  "invoiceNumber": "INV-2024-001",
  "invoiceDate": "2024-01-20",
  "vendorName": "ABC Suppliers",
  "vendorCode": "V001",
  "agencyName": "XYZ Agency",
  "agencyCode": "AG001",
  "agencyAddress": "123 Main St, Mumbai",
  "billingName": "XYZ Agency",
  "billingAddress": "123 Main St, Mumbai",
  "stateName": "Maharashtra",
  "stateCode": "27",
  "gstNumber": "27AAAAA0000A1Z5",
  "gstPercentage": 18,
  "hsnSacCode": "8703",
  "poNumber": "PO-2024-001",
  "totalAmount": 95000,
  "lineItems": [
    { "itemCode": "ITEM001", "description": "Product A", "quantity": 10, "unitPrice": 5000 },
    { "itemCode": "ITEM002", "description": "Product B", "quantity": 20, "unitPrice": 2500 }
  ]
}
```

**Cost Summary Data:**
```json
{
  "placeOfSupply": "27",
  "state": "Maharashtra",
  "numberOfDays": 5,
  "numberOfTeams": 2,
  "numberOfActivations": 10,
  "totalCost": 95000,
  "costBreakdowns": [
    {
      "elementName": "Venue Rental",
      "category": "Fixed",
      "amount": 5000,
      "quantity": 1,
      "unit": "venue",
      "isFixedCost": true,
      "isVariableCost": false
    },
    {
      "elementName": "Staff Cost",
      "category": "Variable",
      "amount": 2500,
      "quantity": 5,
      "unit": "person-day",
      "isFixedCost": false,
      "isVariableCost": true
    }
  ]
}
```

**Activity Data:**
```json
{
  "dealerName": "ABC Motors",
  "dealerCode": "D001",
  "totalDays": 5,
  "locationActivities": [
    {
      "locationName": "Mumbai Central",
      "district": "Mumbai",
      "pincode": "400001",
      "numberOfDays": 3
    },
    {
      "locationName": "Andheri",
      "district": "Mumbai",
      "pincode": "400053",
      "numberOfDays": 2
    }
  ]
}
```

**Photo Metadata (5 photos to match man-days):**
```json
{
  "timestamp": "2024-01-20T10:00:00Z",
  "latitude": 19.0760,
  "longitude": 72.8777,
  "hasBlueTshirtPerson": true,
  "hasBajajVehicle": true,
  "blueTshirtConfidence": 0.95,
  "vehicleConfidence": 0.92
}
```

### Test Scenario 2: Invoice Field Presence Failures

**Missing Fields Test:**
```json
{
  "invoiceNumber": "INV-2024-002",
  "invoiceDate": "2024-01-20",
  "vendorName": "ABC Suppliers",
  // Missing: vendorCode, agencyName, agencyAddress, billingName, billingAddress
  // Missing: stateName, stateCode, gstNumber, gstPercentage, hsnSacCode
  "totalAmount": 50000
}
```

**Expected Result:**
- `invoiceFieldPresence.allFieldsPresent`: false
- `issues`: Contains errors for all missing fields

### Test Scenario 3: Invoice Cross-Document Failures

**Agency Code Mismatch:**
```json
// PO has agencyCode: "AG001"
// Invoice has agencyCode: "AG002"
```

**Expected Result:**
- `invoiceCrossDocument.agencyCodeMatches`: false
- `issues`: "Agency Code mismatch: Invoice has 'AG002', PO has 'AG001'"

**GST State Mismatch:**
```json
{
  "gstNumber": "29AAAAA0000A1Z5",  // Karnataka (29)
  "stateCode": "27"                 // Maharashtra (27)
}
```

**Expected Result:**
- `invoiceCrossDocument.gstStateMatches`: false
- `issues`: "GST Number '29AAAAA0000A1Z5' does not match State Code '27'. Expected state: 29"

**Invoice Amount Exceeds PO:**
```json
// PO totalAmount: 50000
// Invoice totalAmount: 60000
```

**Expected Result:**
- `invoiceCrossDocument.invoiceAmountValid`: false
- `issues`: "Invoice amount (60000.00) exceeds PO amount (50000.00)"

### Test Scenario 4: Cost Summary Failures

**Total Cost Exceeds Invoice:**
```json
// Invoice totalAmount: 50000
// Cost Summary totalCost: 60000
```

**Expected Result:**
- `costSummaryCrossDocument.totalCostValid`: false
- `issues`: "Cost Summary total (60000.00) exceeds Invoice amount (50000.00)"

**Element Cost Doesn't Match State Rate:**
```json
{
  "placeOfSupply": "27",  // Maharashtra
  "costBreakdowns": [
    {
      "elementName": "Venue Rental",
      "amount": 8000  // Expected: 5000 ±10% (4500-5500)
    }
  ]
}
```

**Expected Result:**
- `costSummaryCrossDocument.elementCostsValid`: false
- `issues`: "Element 'Venue Rental' cost (8000.00) does not match state rate (expected: 5000.00)"

### Test Scenario 5: Activity Summary Failures

**Days Mismatch:**
```json
// Cost Summary numberOfDays: 5
// Activity totalDays: 7
```

**Expected Result:**
- `activityCrossDocument.numberOfDaysMatches`: false
- `issues`: "Number of days mismatch: Activity Summary has 7 days, Cost Summary has 5 days"

### Test Scenario 6: Photo Proofs Failures

**Photo Count Doesn't Match Man-Days:**
```json
// Photos uploaded: 3
// Activity man-days: 5
```

**Expected Result:**
- `photoCrossDocument.photoCountMatchesManDays`: false
- `issues`: "Photo count (3) does not match man-days in Activity Summary (5)"

**Man-Days Exceeds Cost Summary Days:**
```json
// Activity man-days: 7
// Cost Summary days: 5
```

**Expected Result:**
- `photoCrossDocument.manDaysWithinCostSummaryDays`: false
- `issues`: "Man-days in Activity Summary (7) exceeds days in Cost Summary (5)"

---

## Validation Checklist

### Invoice Validations (15 total)

#### Field Presence (9)
- [ ] Agency Name present
- [ ] Agency Address present
- [ ] Billing Name present
- [ ] Billing Address present
- [ ] State Name/Code present
- [ ] Invoice Number present
- [ ] Invoice Date present
- [ ] Vendor Code present
- [ ] GST Number present
- [ ] GST Percentage present
- [ ] HSN/SAC Code present
- [ ] Invoice Amount present

#### Cross-Document (6)
- [ ] Agency Code matches PO
- [ ] PO Number matches
- [ ] GST State mapping correct (first 2 digits match state code)
- [ ] HSN/SAC Code valid (in reference data)
- [ ] Invoice Amount ≤ PO Amount
- [ ] GST Percentage valid (18% default)

### Cost Summary Validations (9 total)

#### Field Presence (5)
- [ ] Place of Supply / State present
- [ ] Element wise Cost present
- [ ] Number of Days present
- [ ] Element wise Quantity present
- [ ] Total Cost present

#### Cross-Document (4)
- [ ] Total Cost ≤ Invoice Amount
- [ ] Element Costs match State Rates (±10% tolerance)
- [ ] Fixed Costs within State Limits
- [ ] Variable Costs within State Limits

### Activity Summary Validations (3 total)

#### Field Presence (2)
- [ ] Dealer and Location details present
- [ ] Number of days in locations present

#### Cross-Document (1)
- [ ] Number of days matches Cost Summary

### Photo Proofs Validations (6 total)

#### Field Presence (4)
- [ ] Date/Timestamp present (EXIF)
- [ ] Location Coordinates present (Lat/Long EXIF)
- [ ] Person with Blue T-shirt detected (AI)
- [ ] Bajaj Vehicle detected (AI)

#### Cross-Document (2 - 3-way validation)
- [ ] Photo count matches man-days in Activity Summary
- [ ] Man-days ≤ days in Cost Summary

---

## Expected Test Results

### All Validations Pass
```json
{
  "packageId": "guid",
  "allPassed": true,
  "sapVerification": { "isVerified": true },
  "amountConsistency": { "isConsistent": true },
  "lineItemMatching": { "allItemsMatched": true },
  "completeness": { "isComplete": true },
  "dateValidation": { "isValid": true },
  "vendorMatching": { "isMatched": true },
  "invoiceFieldPresence": { "allFieldsPresent": true },
  "invoiceCrossDocument": { "allChecksPass": true },
  "costSummaryFieldPresence": { "allFieldsPresent": true },
  "costSummaryCrossDocument": { "allChecksPass": true },
  "activityFieldPresence": { "allFieldsPresent": true },
  "activityCrossDocument": { "allChecksPass": true },
  "photoFieldPresence": { "allFieldsPresent": true },
  "photoCrossDocument": { "allChecksPass": true },
  "issues": [],
  "validatedAt": "2024-01-20T10:00:00Z"
}
```

### Validation Failures
```json
{
  "packageId": "guid",
  "allPassed": false,
  "invoiceFieldPresence": {
    "allFieldsPresent": false,
    "missingFields": ["Agency Name", "GST Number", "HSN/SAC Code"]
  },
  "invoiceCrossDocument": {
    "allChecksPass": false,
    "agencyCodeMatches": false,
    "gstStateMatches": false,
    "issues": [
      "Agency Code mismatch: Invoice has 'AG002', PO has 'AG001'",
      "GST Number '29AAAAA0000A1Z5' does not match State Code '27'. Expected state: 29"
    ]
  },
  "issues": [
    {
      "field": "Invoice Fields",
      "issue": "Missing required fields: Agency Name, GST Number, HSN/SAC Code",
      "severity": "Error"
    },
    {
      "field": "Invoice Cross-Validation",
      "issue": "Agency Code mismatch: Invoice has 'AG002', PO has 'AG001'",
      "severity": "Error"
    }
  ]
}
```

---

## Troubleshooting

### Issue: SAP Connection Failed
**Symptom:** `sapVerification.sapConnectionFailed: true`
**Solution:** This is expected if SAP is not configured. Validation will continue without blocking.

### Issue: All Validations Fail
**Symptom:** Multiple validation failures
**Solution:** Check that test data matches the expected format and all required fields are present.

### Issue: Photo Validations Show Warnings
**Symptom:** Photo field presence has issues but severity is "Warning"
**Solution:** Photo content validations (blue t-shirt, vehicle) are informational and don't block validation.

---

## Next Steps

1. Run manual tests with valid data to confirm all validations pass
2. Run manual tests with invalid data to confirm proper error detection
3. Review validation results in database (ValidationResults table)
4. Test with real documents once Azure OpenAI is configured
5. Implement automated integration tests for continuous validation

---

## Database Verification

To verify validation results are saved correctly:

```sql
-- View all validation results
SELECT 
    vr.Id,
    vr.PackageId,
    vr.AllValidationsPassed,
    vr.SapVerificationPassed,
    vr.AmountConsistencyPassed,
    vr.LineItemMatchingPassed,
    vr.CompletenessCheckPassed,
    vr.DateValidationPassed,
    vr.VendorMatchingPassed,
    vr.FailureReason,
    vr.CreatedAt
FROM ValidationResults vr
ORDER BY vr.CreatedAt DESC;

-- View detailed validation JSON
SELECT 
    PackageId,
    ValidationDetailsJson,
    CreatedAt
FROM ValidationResults
WHERE PackageId = 'YOUR_PACKAGE_ID';
```

---

## Summary

This guide covers:
- ✅ Manual testing via Swagger UI
- ✅ Automated unit test execution
- ✅ Test data scenarios for all 33 validations
- ✅ Expected results for pass/fail cases
- ✅ Validation checklist
- ✅ Troubleshooting guide
- ✅ Database verification queries

All validation requirements are implemented and ready for testing!
