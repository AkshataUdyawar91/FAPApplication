# Quick Test Reference - All 33 Validations

## 📋 Your Package ID
```
ae879107-ba25-48dc-8347-e9bc4cab332e
```

---

## 🎯 Invoice Validations (15 total)

### Field Presence (12 checks)

| # | Field | Test | Expected Error |
|---|-------|------|----------------|
| 1 | Agency Name | Set to "" | "Missing required fields: Agency Name" |
| 2 | Agency Address | Set to "" | "Missing required fields: Agency Address" |
| 3 | Billing Name | Set to "" | "Missing required fields: Billing Name" |
| 4 | Billing Address | Set to "" | "Missing required fields: Billing Address" |
| 5 | State Name/Code | Both "" | "Missing required fields: State Name/Code" |
| 6 | Invoice Number | Set to "" | "Missing required fields: Invoice Number" |
| 7 | Invoice Date | Set to default | "Missing required fields: Invoice Date" |
| 8 | Vendor Code | Set to "" | "Missing required fields: Vendor Code" |
| 9 | GST Number | Set to "" | "Missing required fields: GST Number" |
| 10 | GST Percentage | Set to 0 | "Missing required fields: GST Percentage" |
| 11 | HSN/SAC Code | Set to "" | "Missing required fields: HSN/SAC Code" |
| 12 | Invoice Amount | Set to 0 | "Missing required fields: Invoice Amount" |

### Cross-Document (6 checks)

| # | Validation | Test Data | Expected Error |
|---|------------|-----------|----------------|
| 13 | Agency Code Match | Invoice: AG002, PO: AG001 | "Agency Code mismatch: Invoice has 'AG002', PO has 'AG001'" |
| 14 | PO Number Match | Invoice: PO-999, PO: PO-001 | "PO Number mismatch" |
| 15 | GST State Mapping | GST: 29..., State: 27 | "GST Number '29AAAAA0000A1Z5' does not match State Code '27'" |
| 16 | HSN/SAC Valid | HSN: 9999 | "Invalid or unknown HSN/SAC Code: '9999'" |
| 17 | Invoice ≤ PO Amount | Invoice: 120000, PO: 100000 | "Invoice amount (120000.00) exceeds PO amount (100000.00)" |
| 18 | GST % Valid | GST: 12% | "GST Percentage mismatch: Invoice has 12%, expected 18%" |

---

## 🎯 Cost Summary Validations (9 total)

### Field Presence (5 checks)

| # | Field | Test | Expected Error |
|---|-------|------|----------------|
| 19 | Place of Supply | Set to "" | "Missing required fields: Place of Supply / State" |
| 20 | Element wise Cost | costBreakdowns: [] | "Missing required fields: Element wise Cost" |
| 21 | Number of Days | Set to 0 | "Missing required fields: Number of Days" |
| 22 | Element Quantity | All quantities: 0 | "Missing required fields: Element wise Quantity" |
| 23 | Total Cost | Set to 0 | "Missing required fields: Total Cost" |

### Cross-Document (4 checks)

| # | Validation | Test Data | Expected Error |
|---|------------|-----------|----------------|
| 24 | Total ≤ Invoice | Cost: 120000, Invoice: 95000 | "Cost Summary total (120000.00) exceeds Invoice amount (95000.00)" |
| 25 | Element Cost Match | Venue: 8000 (expected 5000±10%) | "Element 'Venue Rental' cost (8000.00) does not match state rate" |
| 26 | Fixed Cost Limit | Setup: 15000 (limit 10000) | "Fixed cost 'Setup Cost' (15000.00) exceeds state limit" |
| 27 | Variable Cost Limit | Per Day: 3000 (limit 2000) | "Variable cost 'Per Day Cost' (3000.00) exceeds state limit" |

---

## 🎯 Activity Summary Validations (3 total)

### Field Presence (2 checks)

| # | Field | Test | Expected Error |
|---|-------|------|----------------|
| 28 | Dealer/Location | dealerName: "", locationActivities: [] | "Missing required fields: Dealer Name/Code, Location Activities" |
| 29 | Days in Locations | All numberOfDays: 0 | "Missing required fields: Number of days in locations" |

### Cross-Document (1 check)

| # | Validation | Test Data | Expected Error |
|---|------------|-----------|----------------|
| 30 | Days Match | Activity: 7, Cost: 5 | "Number of days mismatch: Activity Summary has 7 days, Cost Summary has 5 days" |

---

## 🎯 Photo Proofs Validations (6 total)

### Field Presence (4 checks)

| # | Field | Test | Expected Error |
|---|-------|------|----------------|
| 31 | Date/Timestamp | 3 of 5 photos with timestamp | "Date present on 3 out of 5 photos" |
| 32 | Location | 4 of 5 photos with lat/long | "Location coordinates present on 4 out of 5 photos" |
| 33 | Blue T-shirt | 0 photos with detection | "No photos with person in blue t-shirt detected" |
| 34 | Bajaj Vehicle | 0 photos with detection | "No photos with Bajaj vehicle detected" |

### Cross-Document (2 checks - 3-way validation)

| # | Validation | Test Data | Expected Error |
|---|------------|-----------|----------------|
| 35 | Photo = Man-days | Photos: 3, Man-days: 5 | "Photo count (3) does not match man-days in Activity Summary (5)" |
| 36 | Man-days ≤ Cost Days | Man-days: 7, Cost: 5 | "Man-days in Activity Summary (7) exceeds days in Cost Summary (5)" |

---

## 🚀 Quick Test Commands

### 1. Upload Documents to Your Package

```bash
# Using Swagger UI
POST /api/documents/upload
packageId: ae879107-ba25-48dc-8347-e9bc4cab332e
file: [select file]
```

### 2. Submit Package for Validation

```bash
POST /api/submissions/ae879107-ba25-48dc-8347-e9bc4cab332e/submit
```

### 3. Check Results

Look for these in the response:
- `allPassed`: true/false
- `invoiceFieldPresence.missingFields`: []
- `invoiceCrossDocument.issues`: []
- `costSummaryFieldPresence.missingFields`: []
- `costSummaryCrossDocument.issues`: []
- `activityFieldPresence.missingFields`: []
- `activityCrossDocument.issues`: []
- `photoFieldPresence.missingFields`: []
- `photoCrossDocument.issues`: []
- `issues`: [all validation errors]

---

## 📊 State-Specific Reference Data

### GST State Codes (for validation #15)

| State | Code | GST Prefix |
|-------|------|------------|
| Maharashtra | 27 | 27XXXXX... |
| Karnataka | 29 | 29XXXXX... |
| Delhi | 07 | 07XXXXX... |

### Valid HSN/SAC Codes (for validation #16)

| Code | Description |
|------|-------------|
| 8703 | Motor cars |
| 8704 | Transport vehicles |
| 8711 | Motorcycles |
| 8708 | Vehicle parts |
| 995411-995415 | Service codes |

### Maharashtra State Rates (for validation #25)

| Element | Expected Rate | Tolerance |
|---------|---------------|-----------|
| Venue Rental | 5000 | 4500-5500 |
| Staff Cost | 500 | 450-550 |
| Marketing Material | 200 | 180-220 |
| Transportation | 1000 | 900-1100 |
| Equipment Rental | 3000 | 2700-3300 |

### Maharashtra Cost Limits (for validations #26, #27)

**Fixed Costs:**
- Setup Cost: 10000 max
- License Fee: 5000 max
- Insurance: 3000 max

**Variable Costs:**
- Per Day Cost: 2000 max
- Per Person Cost: 500 max
- Per Unit Cost: 100 max

---

## ✅ Testing Checklist

### Must Test (Core Validations)
- [ ] Invoice field missing (any field)
- [ ] GST state mismatch
- [ ] Invoice > PO amount
- [ ] Cost > Invoice amount
- [ ] Activity days ≠ Cost days
- [ ] Photo count ≠ Man-days
- [ ] All validations pass (baseline)

### Should Test (Edge Cases)
- [ ] Invalid HSN/SAC code
- [ ] Wrong GST percentage
- [ ] Element cost exceeds rate
- [ ] Fixed cost exceeds limit
- [ ] Man-days > Cost days
- [ ] Photos missing metadata

### Optional Test (Comprehensive)
- [ ] All 12 invoice fields individually
- [ ] All 5 cost summary fields individually
- [ ] Multiple validation failures at once
- [ ] Different state codes (Karnataka, Delhi)

---

## 🎯 Expected Test Duration

- **Quick Test** (7 scenarios): 15-20 minutes
- **Comprehensive Test** (all 36 validations): 45-60 minutes
- **Full Regression** (all scenarios + edge cases): 2-3 hours

---

## 📝 Test Result Template

```
Test: [Validation Name]
Package ID: ae879107-ba25-48dc-8347-e9bc4cab332e
Test Data: [Brief description]
Expected: [Expected error/success]
Actual: [What you got]
Status: ✅ PASS / ❌ FAIL
Notes: [Any observations]
```

---

## 🆘 Troubleshooting

### Issue: No validation errors shown
**Solution**: Check that documents have extracted data in JSON format

### Issue: Unexpected validation pass
**Solution**: Verify test data matches the failure scenario exactly

### Issue: SAP verification failed
**Solution**: This is expected if SAP is not configured - validation continues

### Issue: Photo validations show warnings only
**Solution**: Photo content validations (blue t-shirt, vehicle) are informational

---

## 📚 Full Documentation

- **START_HERE_TESTING.md** - Overview and getting started
- **COMPLETE_VALIDATION_TEST_DATA.md** - All test data with JSON
- **VALIDATION_TEST_CASES.md** - Detailed test specifications
- **VALIDATION_TESTING_GUIDE.md** - Comprehensive testing manual

**Start testing now with your package: ae879107-ba25-48dc-8347-e9bc4cab332e** 🚀
