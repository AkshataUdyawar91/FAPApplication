# Complete Validation Test Data

## 📦 Test Package: ae879107-ba25-48dc-8347-e9bc4cab332e

You already have a PO document uploaded. Now upload the remaining documents with the test data below.

---

## 🎯 Test Scenario 1: ALL VALIDATIONS PASS ✅

### Invoice Data (All Fields Present, All Cross-Checks Pass)

**File**: Create `Invoice_Valid_Complete.json` and upload as PDF

```json
{
  "invoiceNumber": "INV-2024-001",
  "invoiceDate": "2024-01-20T00:00:00Z",
  "vendorName": "ABC Suppliers",
  "vendorCode": "V001",
  "agencyName": "XYZ Marketing Agency",
  "agencyCode": "AG001",
  "agencyAddress": "123 Main Street, Andheri West, Mumbai, Maharashtra 400053",
  "billingName": "XYZ Marketing Agency",
  "billingAddress": "123 Main Street, Andheri West, Mumbai, Maharashtra 400053",
  "stateName": "Maharashtra",
  "stateCode": "27",
  "gstNumber": "27AAAAA0000A1Z5",
  "gstPercentage": 18,
  "hsnSacCode": "8703",
  "poNumber": "PO-2024-001",
  "totalAmount": 95000,
  "lineItems": [
    {
      "itemCode": "ITEM001",
      "description": "Marketing Campaign Materials",
      "quantity": 10,
      "unitPrice": 5000,
      "amount": 50000
    },
    {
      "itemCode": "ITEM002",
      "description": "Event Setup Equipment",
      "quantity": 20,
      "unitPrice": 2250,
      "amount": 45000
    }
  ]
}
```

**Expected Result**: 
- ✅ All 12 invoice field presence checks PASS
- ✅ All 6 invoice cross-document checks PASS

---

### Cost Summary Data (All Fields Present, All Cross-Checks Pass)

**File**: Create `CostSummary_Valid_Complete.json` and upload as PDF

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
      "category": "Fixed Cost",
      "amount": 5000,
      "quantity": 1,
      "unit": "venue",
      "isFixedCost": true,
      "isVariableCost": false
    },
    {
      "elementName": "Staff Cost",
      "category": "Variable Cost",
      "amount": 500,
      "quantity": 50,
      "unit": "person-day",
      "isFixedCost": false,
      "isVariableCost": true
    },
    {
      "elementName": "Marketing Material",
      "category": "Variable Cost",
      "amount": 200,
      "quantity": 100,
      "unit": "piece",
      "isFixedCost": false,
      "isVariableCost": true
    },
    {
      "elementName": "Transportation",
      "category": "Variable Cost",
      "amount": 1000,
      "quantity": 30,
      "unit": "trip",
      "isFixedCost": false,
      "isVariableCost": true
    },
    {
      "elementName": "Equipment Rental",
      "category": "Fixed Cost",
      "amount": 3000,
      "quantity": 5,
      "unit": "day",
      "isFixedCost": true,
      "isVariableCost": false
    }
  ]
}
```

**Expected Result**:
- ✅ All 5 cost summary field presence checks PASS
- ✅ Total Cost (95000) ≤ Invoice Amount (95000) ✅
- ✅ Element costs match state rates (within 10% tolerance) ✅
- ✅ Fixed costs within limits ✅
- ✅ Variable costs within limits ✅

---

### Activity Summary Data (All Fields Present, Days Match)

**File**: Create `Activity_Valid_Complete.json` and upload as PDF

```json
{
  "dealerName": "ABC Bajaj Motors",
  "dealerCode": "D001",
  "totalDays": 5,
  "locationActivities": [
    {
      "locationName": "Mumbai Central",
      "district": "Mumbai",
      "pincode": "400001",
      "numberOfDays": 3,
      "activities": [
        "Product Display",
        "Test Rides",
        "Customer Engagement"
      ]
    },
    {
      "locationName": "Andheri West",
      "district": "Mumbai",
      "pincode": "400053",
      "numberOfDays": 2,
      "activities": [
        "Product Display",
        "Test Rides"
      ]
    }
  ]
}
```

**Expected Result**:
- ✅ Dealer and Location details present ✅
- ✅ Number of days (5) matches Cost Summary (5) ✅

---

### Photo Proofs Data (5 Photos to Match Man-Days)

**Files**: Upload 5 photo files with this metadata embedded

**Photo 1-5 Metadata**:
```json
{
  "timestamp": "2024-01-20T10:00:00Z",
  "latitude": 19.0760,
  "longitude": 72.8777,
  "location": "Mumbai Central",
  "hasBlueTshirtPerson": true,
  "hasBajajVehicle": true,
  "blueTshirtConfidence": 0.95,
  "vehicleConfidence": 0.92
}
```

**Expected Result**:
- ✅ All 5 photos have date/timestamp ✅
- ✅ All 5 photos have location coordinates ✅
- ✅ Blue t-shirt person detected in all photos ✅
- ✅ Bajaj vehicle detected in all photos ✅
- ✅ Photo count (5) matches man-days (5) ✅
- ✅ Man-days (5) ≤ Cost Summary days (5) ✅

---

## 🎯 Test Scenario 2: INVOICE FIELD MISSING ❌

### Invoice Data (Missing Agency Name, GST Number, HSN/SAC Code)

```json
{
  "invoiceNumber": "INV-2024-002",
  "invoiceDate": "2024-01-20T00:00:00Z",
  "vendorName": "ABC Suppliers",
  "vendorCode": "V001",
  "agencyName": "",  // ❌ MISSING
  "agencyCode": "AG001",
  "agencyAddress": "123 Main Street, Mumbai",
  "billingName": "XYZ Agency",
  "billingAddress": "123 Main Street, Mumbai",
  "stateName": "Maharashtra",
  "stateCode": "27",
  "gstNumber": "",  // ❌ MISSING
  "gstPercentage": 18,
  "hsnSacCode": "",  // ❌ MISSING
  "poNumber": "PO-2024-001",
  "totalAmount": 50000
}
```

**Expected Result**:
```json
{
  "invoiceFieldPresence": {
    "allFieldsPresent": false,
    "missingFields": [
      "Agency Name",
      "GST Number",
      "HSN/SAC Code"
    ]
  },
  "issues": [
    {
      "field": "Invoice Fields",
      "issue": "Missing required fields: Agency Name, GST Number, HSN/SAC Code",
      "severity": "Error"
    }
  ]
}
```

---

## 🎯 Test Scenario 3: GST STATE MISMATCH ❌

### Invoice Data (GST Number from Karnataka but State is Maharashtra)

```json
{
  "invoiceNumber": "INV-2024-003",
  "invoiceDate": "2024-01-20T00:00:00Z",
  "vendorName": "ABC Suppliers",
  "vendorCode": "V001",
  "agencyName": "XYZ Agency",
  "agencyCode": "AG001",
  "agencyAddress": "123 Main Street, Mumbai",
  "billingName": "XYZ Agency",
  "billingAddress": "123 Main Street, Mumbai",
  "stateName": "Maharashtra",
  "stateCode": "27",
  "gstNumber": "29AAAAA0000A1Z5",  // ❌ Karnataka (29) but state is Maharashtra (27)
  "gstPercentage": 18,
  "hsnSacCode": "8703",
  "poNumber": "PO-2024-001",
  "totalAmount": 50000
}
```

**Expected Result**:
```json
{
  "invoiceCrossDocument": {
    "allChecksPass": false,
    "gstStateMatches": false,
    "issues": [
      "GST Number '29AAAAA0000A1Z5' does not match State Code '27'. Expected state: KA"
    ]
  }
}
```

---

## 🎯 Test Scenario 4: AGENCY CODE MISMATCH ❌

### Invoice Data (Agency Code doesn't match PO)

```json
{
  "invoiceNumber": "INV-2024-004",
  "agencyCode": "AG002",  // ❌ PO has AG001
  // ... other fields valid
}
```

**Expected Result**:
```json
{
  "invoiceCrossDocument": {
    "agencyCodeMatches": false,
    "issues": [
      "Agency Code mismatch: Invoice has 'AG002', PO has 'AG001'"
    ]
  }
}
```

---

## 🎯 Test Scenario 5: INVOICE AMOUNT EXCEEDS PO ❌

### Invoice Data (Amount higher than PO)

```json
{
  "invoiceNumber": "INV-2024-005",
  "totalAmount": 120000,  // ❌ PO has 100000
  // ... other fields valid
}
```

**Expected Result**:
```json
{
  "invoiceCrossDocument": {
    "invoiceAmountValid": false,
    "issues": [
      "Invoice amount (120000.00) exceeds PO amount (100000.00)"
    ]
  }
}
```

---

## 🎯 Test Scenario 6: INVALID HSN/SAC CODE ❌

### Invoice Data (Invalid HSN/SAC Code)

```json
{
  "invoiceNumber": "INV-2024-006",
  "hsnSacCode": "9999",  // ❌ Invalid code
  // ... other fields valid
}
```

**Expected Result**:
```json
{
  "invoiceCrossDocument": {
    "hsnSacCodeValid": false,
    "issues": [
      "Invalid or unknown HSN/SAC Code: '9999'"
    ]
  }
}
```

---

## 🎯 Test Scenario 7: GST PERCENTAGE MISMATCH ❌

### Invoice Data (Wrong GST percentage)

```json
{
  "invoiceNumber": "INV-2024-007",
  "gstPercentage": 12,  // ❌ Should be 18
  // ... other fields valid
}
```

**Expected Result**:
```json
{
  "invoiceCrossDocument": {
    "gstPercentageValid": false,
    "issues": [
      "GST Percentage mismatch: Invoice has 12%, expected 18%"
    ]
  }
}
```

---

## 🎯 Test Scenario 8: COST SUMMARY MISSING FIELDS ❌

### Cost Summary Data (Missing Place of Supply and Number of Days)

```json
{
  "placeOfSupply": "",  // ❌ MISSING
  "state": "",  // ❌ MISSING
  "numberOfDays": 0,  // ❌ MISSING
  "totalCost": 50000,
  "costBreakdowns": []  // ❌ MISSING
}
```

**Expected Result**:
```json
{
  "costSummaryFieldPresence": {
    "allFieldsPresent": false,
    "missingFields": [
      "Place of Supply / State",
      "Element wise Cost",
      "Number of Days"
    ]
  }
}
```

---

## 🎯 Test Scenario 9: TOTAL COST EXCEEDS INVOICE ❌

### Cost Summary Data (Total cost higher than invoice)

```json
{
  "placeOfSupply": "27",
  "state": "Maharashtra",
  "numberOfDays": 5,
  "totalCost": 120000,  // ❌ Invoice has 95000
  "costBreakdowns": [
    {
      "elementName": "Venue Rental",
      "amount": 120000,
      "quantity": 1
    }
  ]
}
```

**Expected Result**:
```json
{
  "costSummaryCrossDocument": {
    "totalCostValid": false,
    "issues": [
      "Cost Summary total (120000.00) exceeds Invoice amount (95000.00)"
    ]
  }
}
```

---

## 🎯 Test Scenario 10: ELEMENT COST EXCEEDS STATE RATE ❌

### Cost Summary Data (Venue rental too high for Maharashtra)

```json
{
  "placeOfSupply": "27",
  "state": "Maharashtra",
  "costBreakdowns": [
    {
      "elementName": "Venue Rental",
      "amount": 8000,  // ❌ Expected: 5000 ±10% (4500-5500)
      "quantity": 1
    }
  ]
}
```

**Expected Result**:
```json
{
  "costSummaryCrossDocument": {
    "elementCostsValid": false,
    "issues": [
      "Element 'Venue Rental' cost (8000.00) does not match state rate (expected: 5000.00)"
    ]
  }
}
```

---

## 🎯 Test Scenario 11: ACTIVITY DAYS MISMATCH ❌

### Activity Data (Days don't match cost summary)

```json
{
  "dealerName": "ABC Motors",
  "dealerCode": "D001",
  "totalDays": 7,  // ❌ Cost Summary has 5
  "locationActivities": [
    {
      "locationName": "Mumbai",
      "numberOfDays": 7
    }
  ]
}
```

**Expected Result**:
```json
{
  "activityCrossDocument": {
    "numberOfDaysMatches": false,
    "issues": [
      "Number of days mismatch: Activity Summary has 7 days, Cost Summary has 5 days"
    ]
  }
}
```

---

## 🎯 Test Scenario 12: PHOTO COUNT MISMATCH ❌

### Photo Data (Only 3 photos but 5 man-days)

Upload only 3 photos when activity shows 5 man-days.

**Expected Result**:
```json
{
  "photoCrossDocument": {
    "photoCountMatchesManDays": false,
    "photoCount": 3,
    "manDays": 5,
    "issues": [
      "Photo count (3) does not match man-days in Activity Summary (5)"
    ]
  }
}
```

---

## 🎯 Test Scenario 13: MAN-DAYS EXCEEDS COST SUMMARY DAYS ❌

### Activity Data (Man-days more than cost summary days)

```json
{
  "totalDays": 7,  // ❌ Cost Summary has 5
  "locationActivities": [
    {
      "locationName": "Mumbai",
      "numberOfDays": 7
    }
  ]
}
```

Upload 7 photos to match man-days.

**Expected Result**:
```json
{
  "photoCrossDocument": {
    "manDaysWithinCostSummaryDays": false,
    "manDays": 7,
    "costSummaryDays": 5,
    "issues": [
      "Man-days in Activity Summary (7) exceeds days in Cost Summary (5)"
    ]
  }
}
```

---

## 🎯 Test Scenario 14: PHOTOS MISSING METADATA ❌

### Photo Data (Missing timestamp and location)

Upload 5 photos with incomplete metadata:
- 3 photos with timestamp, 2 without
- 4 photos with location, 1 without
- 0 photos with blue t-shirt detection
- 0 photos with vehicle detection

**Expected Result**:
```json
{
  "photoFieldPresence": {
    "allFieldsPresent": false,
    "totalPhotos": 5,
    "photosWithDate": 3,
    "photosWithLocation": 4,
    "photosWithBlueTshirt": 0,
    "photosWithVehicle": 0,
    "missingFields": [
      "Date present on 3 out of 5 photos",
      "Location coordinates present on 4 out of 5 photos",
      "No photos with person in blue t-shirt detected (AI validation)",
      "No photos with Bajaj vehicle detected (AI validation)"
    ]
  }
}
```

---

## 📊 Summary of All Test Scenarios

| Scenario | What It Tests | Expected Result |
|----------|---------------|-----------------|
| 1 | All validations pass | ✅ allPassed: true |
| 2 | Invoice missing fields | ❌ 3 fields missing |
| 3 | GST state mismatch | ❌ State code doesn't match GST |
| 4 | Agency code mismatch | ❌ Invoice ≠ PO agency code |
| 5 | Invoice > PO amount | ❌ Amount validation fails |
| 6 | Invalid HSN/SAC code | ❌ Code not in reference data |
| 7 | Wrong GST percentage | ❌ Should be 18% |
| 8 | Cost summary missing fields | ❌ 3 fields missing |
| 9 | Cost > Invoice amount | ❌ Total cost too high |
| 10 | Element cost too high | ❌ Exceeds state rate |
| 11 | Activity days mismatch | ❌ Days don't match |
| 12 | Photo count mismatch | ❌ 3 photos, 5 man-days |
| 13 | Man-days > cost days | ❌ 7 man-days, 5 cost days |
| 14 | Photos missing metadata | ❌ Incomplete EXIF/AI data |

---

## 🚀 How to Test

### For Your Current Package (ae879107-ba25-48dc-8347-e9bc4cab332e)

1. **Upload Invoice** (choose a scenario from above)
2. **Upload Cost Summary** (choose a scenario)
3. **Upload Activity Summary** (choose a scenario)
4. **Upload Photos** (5 photos for valid, 3 for mismatch test)

5. **Submit Package**:
```bash
POST /api/submissions/ae879107-ba25-48dc-8347-e9bc4cab332e/submit
```

6. **Review Results** - You'll see all 33 validation results

---

## ✅ Quick Test Checklist

- [ ] Scenario 1: All pass (baseline)
- [ ] Scenario 2: Invoice fields missing
- [ ] Scenario 3: GST state mismatch
- [ ] Scenario 5: Invoice > PO amount
- [ ] Scenario 9: Cost > Invoice amount
- [ ] Scenario 11: Activity days mismatch
- [ ] Scenario 12: Photo count mismatch

**Test at least these 7 scenarios to cover all validation types!**
