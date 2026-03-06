# Validation Test Cases - Complete Specification

## Overview

This document provides comprehensive test cases for all 33 validation requirements in the Bajaj Document Processing System.

## Test Organization

- **Invoice Validations**: 15 test cases (9 field presence + 6 cross-document)
- **Cost Summary Validations**: 9 test cases (5 field presence + 4 cross-document)
- **Activity Summary Validations**: 3 test cases (2 field presence + 1 cross-document)
- **Photo Proofs Validations**: 6 test cases (4 field presence + 2 cross-document)

---

## Invoice Validation Test Cases

### Test Category: Invoice Field Presence (9 tests)

#### TC-INV-FP-001: Agency Name Missing
**Test**: Validate invoice with missing Agency Name
**Input**:
```json
{
  "invoiceNumber": "INV001",
  "invoiceDate": "2024-01-20",
  "agencyName": "",  // Empty
  "totalAmount": 50000
}
```
**Expected Result**:
- `invoiceFieldPresence.allFieldsPresent`: false
- `invoiceFieldPresence.missingFields`: Contains "Agency Name"
- `allPassed`: false

#### TC-INV-FP-002: Agency Address Missing
**Test**: Validate invoice with missing Agency Address
**Input**: Invoice with `agencyAddress: ""`
**Expected Result**: Missing "Agency Address" in missingFields

#### TC-INV-FP-003: Billing Name Missing
**Test**: Validate invoice with missing Billing Name
**Input**: Invoice with `billingName: ""`
**Expected Result**: Missing "Billing Name" in missingFields

#### TC-INV-FP-004: Billing Address Missing
**Test**: Validate invoice with missing Billing Address
**Input**: Invoice with `billingAddress: ""`
**Expected Result**: Missing "Billing Address" in missingFields

#### TC-INV-FP-005: State Name/Code Missing
**Test**: Validate invoice with missing State Name and Code
**Input**: Invoice with `stateName: ""` and `stateCode: ""`
**Expected Result**: Missing "State Name/Code" in missingFields

#### TC-INV-FP-006: Invoice Number Missing
**Test**: Validate invoice with missing Invoice Number
**Input**: Invoice with `invoiceNumber: ""`
**Expected Result**: Missing "Invoice Number" in missingFields

#### TC-INV-FP-007: Invoice Date Missing
**Test**: Validate invoice with default/missing Invoice Date
**Input**: Invoice with `invoiceDate: default(DateTime)`
**Expected Result**: Missing "Invoice Date" in missingFields

#### TC-INV-FP-008: Vendor Code Missing
**Test**: Validate invoice with missing Vendor Code
**Input**: Invoice with `vendorCode: ""`
**Expected Result**: Missing "Vendor Code" in missingFields

#### TC-INV-FP-009: GST Number Missing
**Test**: Validate invoice with missing GST Number
**Input**: Invoice with `gstNumber: ""`
**Expected Result**: Missing "GST Number" in missingFields

#### TC-INV-FP-010: GST Percentage Missing or Zero
**Test**: Validate invoice with zero GST Percentage
**Input**: Invoice with `gstPercentage: 0`
**Expected Result**: Missing "GST Percentage" in missingFields

#### TC-INV-FP-011: HSN/SAC Code Missing
**Test**: Validate invoice with missing HSN/SAC Code
**Input**: Invoice with `hsnSacCode: ""`
**Expected Result**: Missing "HSN/SAC Code" in missingFields

#### TC-INV-FP-012: Invoice Amount Missing or Zero
**Test**: Validate invoice with zero amount
**Input**: Invoice with `totalAmount: 0`
**Expected Result**: Missing "Invoice Amount" in missingFields

#### TC-INV-FP-013: All Fields Present
**Test**: Validate invoice with all required fields
**Input**: Complete invoice with all fields populated
**Expected Result**:
- `invoiceFieldPresence.allFieldsPresent`: true
- `invoiceFieldPresence.missingFields`: Empty list

### Test Category: Invoice Cross-Document (6 tests)

#### TC-INV-CD-001: Agency Code Mismatch
**Test**: Validate invoice agency code matches PO
**Input**:
- PO: `agencyCode: "AG001"`
- Invoice: `agencyCode: "AG002"`
**Expected Result**:
- `invoiceCrossDocument.agencyCodeMatches`: false
- `issues`: "Agency Code mismatch: Invoice has 'AG002', PO has 'AG001'"

#### TC-INV-CD-002: PO Number Mismatch
**Test**: Validate invoice PO number matches actual PO
**Input**:
- PO: `poNumber: "PO-2024-001"`
- Invoice: `poNumber: "PO-2024-999"`
**Expected Result**:
- `invoiceCrossDocument.poNumberMatches`: false
- `issues`: "PO Number mismatch"

#### TC-INV-CD-003: GST State Mapping Invalid
**Test**: Validate GST number first 2 digits match state code
**Input**:
- Invoice: `gstNumber: "29AAAAA0000A1Z5"` (Karnataka = 29)
- Invoice: `stateCode: "27"` (Maharashtra = 27)
**Expected Result**:
- `invoiceCrossDocument.gstStateMatches`: false
- `issues`: "GST Number '29AAAAA0000A1Z5' does not match State Code '27'. Expected state: 29"

#### TC-INV-CD-004: HSN/SAC Code Invalid
**Test**: Validate HSN/SAC code exists in reference data
**Input**: Invoice with `hsnSacCode: "9999"` (invalid code)
**Expected Result**:
- `invoiceCrossDocument.hsnSacCodeValid`: false
- `issues`: "Invalid or unknown HSN/SAC Code: '9999'"

#### TC-INV-CD-005: Invoice Amount Exceeds PO Amount
**Test**: Validate invoice amount is less than or equal to PO amount
**Input**:
- PO: `totalAmount: 50000`
- Invoice: `totalAmount: 60000`
**Expected Result**:
- `invoiceCrossDocument.invoiceAmountValid`: false
- `issues`: "Invoice amount (60000.00) exceeds PO amount (50000.00)"

#### TC-INV-CD-006: GST Percentage Invalid
**Test**: Validate GST percentage matches expected rate (18%)
**Input**: Invoice with `gstPercentage: 12` (should be 18)
**Expected Result**:
- `invoiceCrossDocument.gstPercentageValid`: false
- `issues`: "GST Percentage mismatch: Invoice has 12%, expected 18%"

#### TC-INV-CD-007: All Cross-Document Checks Pass
**Test**: Validate invoice with all cross-document checks passing
**Input**: Invoice and PO with matching data
**Expected Result**:
- `invoiceCrossDocument.allChecksPass`: true
- `invoiceCrossDocument.agencyCodeMatches`: true
- `invoiceCrossDocument.poNumberMatches`: true
- `invoiceCrossDocument.gstStateMatches`: true
- `invoiceCrossDocument.hsnSacCodeValid`: true
- `invoiceCrossDocument.invoiceAmountValid`: true
- `invoiceCrossDocument.gstPercentageValid`: true

---

## Cost Summary Validation Test Cases

### Test Category: Cost Summary Field Presence (5 tests)

#### TC-CS-FP-001: Place of Supply Missing
**Test**: Validate cost summary with missing place of supply
**Input**: Cost Summary with `placeOfSupply: ""` and `state: ""`
**Expected Result**: Missing "Place of Supply / State" in missingFields

#### TC-CS-FP-002: Element wise Cost Missing
**Test**: Validate cost summary with no cost breakdowns
**Input**: Cost Summary with `costBreakdowns: []` or all amounts zero
**Expected Result**: Missing "Element wise Cost" in missingFields

#### TC-CS-FP-003: Number of Days Missing
**Test**: Validate cost summary with missing number of days
**Input**: Cost Summary with `numberOfDays: null` or `numberOfDays: 0`
**Expected Result**: Missing "Number of Days" in missingFields

#### TC-CS-FP-004: Element wise Quantity Missing
**Test**: Validate cost summary with no quantities
**Input**: Cost Summary with all `costBreakdowns[].quantity: null` or zero
**Expected Result**: Missing "Element wise Quantity" in missingFields

#### TC-CS-FP-005: Total Cost Missing or Zero
**Test**: Validate cost summary with zero total cost
**Input**: Cost Summary with `totalCost: 0`
**Expected Result**: Missing "Total Cost" in missingFields

#### TC-CS-FP-006: All Fields Present
**Test**: Validate cost summary with all required fields
**Input**: Complete cost summary with all fields populated
**Expected Result**:
- `costSummaryFieldPresence.allFieldsPresent`: true
- `costSummaryFieldPresence.missingFields`: Empty list

### Test Category: Cost Summary Cross-Document (4 tests)

#### TC-CS-CD-001: Total Cost Exceeds Invoice Amount
**Test**: Validate cost summary total is less than or equal to invoice amount
**Input**:
- Invoice: `totalAmount: 50000`
- Cost Summary: `totalCost: 60000`
**Expected Result**:
- `costSummaryCrossDocument.totalCostValid`: false
- `issues`: "Cost Summary total (60000.00) exceeds Invoice amount (50000.00)"

#### TC-CS-CD-002: Element Cost Doesn't Match State Rate
**Test**: Validate element cost matches state rate within 10% tolerance
**Input**:
- Cost Summary: `placeOfSupply: "27"` (Maharashtra)
- Cost Breakdown: `elementName: "Venue Rental"`, `amount: 8000`
- Expected Rate: 5000 (tolerance: 4500-5500)
**Expected Result**:
- `costSummaryCrossDocument.elementCostsValid`: false
- `issues`: "Element 'Venue Rental' cost (8000.00) does not match state rate (expected: 5000.00)"

#### TC-CS-CD-003: Fixed Cost Exceeds State Limit
**Test**: Validate fixed cost is within state limit
**Input**:
- Cost Summary: `placeOfSupply: "27"` (Maharashtra)
- Cost Breakdown: `category: "Setup Cost"`, `amount: 15000`, `isFixedCost: true`
- State Limit: 10000
**Expected Result**:
- `costSummaryCrossDocument.fixedCostsValid`: false
- `issues`: "Fixed cost 'Setup Cost' (15000.00) exceeds state limit"

#### TC-CS-CD-004: Variable Cost Exceeds State Limit
**Test**: Validate variable cost is within state limit
**Input**:
- Cost Summary: `placeOfSupply: "27"` (Maharashtra)
- Cost Breakdown: `category: "Per Day Cost"`, `amount: 3000`, `isVariableCost: true`
- State Limit: 2000
**Expected Result**:
- `costSummaryCrossDocument.variableCostsValid`: false
- `issues`: "Variable cost 'Per Day Cost' (3000.00) exceeds state limit"

#### TC-CS-CD-005: All Cross-Document Checks Pass
**Test**: Validate cost summary with all cross-document checks passing
**Input**: Cost Summary with valid amounts and rates
**Expected Result**:
- `costSummaryCrossDocument.allChecksPass`: true
- `costSummaryCrossDocument.totalCostValid`: true
- `costSummaryCrossDocument.elementCostsValid`: true
- `costSummaryCrossDocument.fixedCostsValid`: true
- `costSummaryCrossDocument.variableCostsValid`: true

---

## Activity Summary Validation Test Cases

### Test Category: Activity Field Presence (2 tests)

#### TC-ACT-FP-001: Dealer and Location Details Missing
**Test**: Validate activity with missing dealer and location details
**Input**: Activity with `dealerName: ""`, `dealerCode: ""`, `locationActivities: []`
**Expected Result**: Missing "Dealer Name/Code" and "Location Activities" in missingFields

#### TC-ACT-FP-002: All Fields Present
**Test**: Validate activity with all required fields
**Input**: Complete activity with dealer info and location activities
**Expected Result**:
- `activityFieldPresence.allFieldsPresent`: true
- `activityFieldPresence.missingFields`: Empty list

### Test Category: Activity Cross-Document (1 test)

#### TC-ACT-CD-001: Number of Days Mismatch
**Test**: Validate activity days match cost summary days
**Input**:
- Cost Summary: `numberOfDays: 5`
- Activity: `totalDays: 7`
**Expected Result**:
- `activityCrossDocument.numberOfDaysMatches`: false
- `issues`: "Number of days mismatch: Activity Summary has 7 days, Cost Summary has 5 days"

#### TC-ACT-CD-002: Number of Days Match
**Test**: Validate activity days match cost summary days
**Input**:
- Cost Summary: `numberOfDays: 5`
- Activity: `totalDays: 5`
**Expected Result**:
- `activityCrossDocument.numberOfDaysMatches`: true
- `activityCrossDocument.allChecksPass`: true

---

## Photo Proofs Validation Test Cases

### Test Category: Photo Field Presence (4 tests)

#### TC-PHOTO-FP-001: Date/Timestamp Missing
**Test**: Validate photos with missing timestamps
**Input**: 5 photos, 3 with timestamp, 2 without
**Expected Result**:
- `photoFieldPresence.photosWithDate`: 3
- `photoFieldPresence.totalPhotos`: 5
- `missingFields`: "Date present on 3 out of 5 photos"

#### TC-PHOTO-FP-002: Location Coordinates Missing
**Test**: Validate photos with missing location data
**Input**: 5 photos, 4 with lat/long, 1 without
**Expected Result**:
- `photoFieldPresence.photosWithLocation`: 4
- `missingFields`: "Location coordinates present on 4 out of 5 photos"

#### TC-PHOTO-FP-003: Blue T-shirt Person Not Detected
**Test**: Validate photos with no blue t-shirt detection
**Input**: 5 photos, none with `hasBlueTshirtPerson: true`
**Expected Result**:
- `photoFieldPresence.photosWithBlueTshirt`: 0
- `missingFields`: "No photos with person in blue t-shirt detected (AI validation)"

#### TC-PHOTO-FP-004: Bajaj Vehicle Not Detected
**Test**: Validate photos with no vehicle detection
**Input**: 5 photos, none with `hasBajajVehicle: true`
**Expected Result**:
- `photoFieldPresence.photosWithVehicle`: 0
- `missingFields`: "No photos with Bajaj vehicle detected (AI validation)"

#### TC-PHOTO-FP-005: All Photo Fields Present
**Test**: Validate photos with all required metadata
**Input**: 5 photos with timestamp, location, blue t-shirt, and vehicle
**Expected Result**:
- `photoFieldPresence.allFieldsPresent`: true
- `photoFieldPresence.photosWithDate`: 5
- `photoFieldPresence.photosWithLocation`: 5
- `photoFieldPresence.photosWithBlueTshirt`: 5
- `photoFieldPresence.photosWithVehicle`: 5

### Test Category: Photo Cross-Document (2 tests - 3-way validation)

#### TC-PHOTO-CD-001: Photo Count Doesn't Match Man-Days
**Test**: Validate photo count matches man-days in activity summary
**Input**:
- Photos: 3 uploaded
- Activity: `totalDays: 5` (man-days)
**Expected Result**:
- `photoCrossDocument.photoCountMatchesManDays`: false
- `issues`: "Photo count (3) does not match man-days in Activity Summary (5)"

#### TC-PHOTO-CD-002: Man-Days Exceeds Cost Summary Days
**Test**: Validate man-days is less than or equal to cost summary days
**Input**:
- Activity: `totalDays: 7` (man-days)
- Cost Summary: `numberOfDays: 5`
**Expected Result**:
- `photoCrossDocument.manDaysWithinCostSummaryDays`: false
- `issues`: "Man-days in Activity Summary (7) exceeds days in Cost Summary (5)"

#### TC-PHOTO-CD-003: 3-Way Validation Passes
**Test**: Validate photo count, man-days, and cost summary days all match
**Input**:
- Photos: 5 uploaded
- Activity: `totalDays: 5` (man-days)
- Cost Summary: `numberOfDays: 5`
**Expected Result**:
- `photoCrossDocument.photoCountMatchesManDays`: true
- `photoCrossDocument.manDaysWithinCostSummaryDays`: true
- `photoCrossDocument.allChecksPass`: true

---

## Integration Test Scenarios

### Scenario 1: Perfect Package (All Validations Pass)
**Description**: Test a complete package with all validations passing
**Input**: Package with valid PO, Invoice, Cost Summary, Activity, and 5 Photos
**Expected Result**:
- `allPassed`: true
- All validation sub-results show success
- `issues`: Empty list
- Package state updated to `Validated`

### Scenario 2: Multiple Invoice Failures
**Description**: Test invoice with multiple field and cross-document failures
**Input**: Invoice missing fields + agency code mismatch + GST state mismatch
**Expected Result**:
- `allPassed`: false
- `invoiceFieldPresence.allFieldsPresent`: false
- `invoiceCrossDocument.allChecksPass`: false
- Multiple issues in `issues` list
- Package state updated to `ValidationFailed`

### Scenario 3: Cost Summary Failures
**Description**: Test cost summary with amount and rate violations
**Input**: Cost Summary with total > invoice + element costs exceeding rates
**Expected Result**:
- `allPassed`: false
- `costSummaryCrossDocument.allChecksPass`: false
- Issues for total cost and element costs
- Package state updated to `ValidationFailed`

### Scenario 4: Photo Validation Failures
**Description**: Test photo count mismatch and 3-way validation failure
**Input**: 3 photos, 5 man-days, 5 cost summary days
**Expected Result**:
- `allPassed`: false
- `photoCrossDocument.photoCountMatchesManDays`: false
- Issue for photo count mismatch
- Package state updated to `ValidationFailed`

---

## Test Execution Instructions

### Running Unit Tests

```bash
cd backend
dotnet test --filter "FullyQualifiedName~ValidationAgentTests"
```

### Running Specific Test Category

```bash
# Invoice tests only
dotnet test --filter "FullyQualifiedName~ValidationAgentTests&TestCategory=Invoice"

# Cost Summary tests only
dotnet test --filter "FullyQualifiedName~ValidationAgentTests&TestCategory=CostSummary"

# Activity tests only
dotnet test --filter "FullyQualifiedName~ValidationAgentTests&TestCategory=Activity"

# Photo tests only
dotnet test --filter "FullyQualifiedName~ValidationAgentTests&TestCategory=Photo"
```

### Test Coverage Report

```bash
dotnet test /p:CollectCoverage=true /p:CoverageReportFormat=html
```

---

## Test Data Templates

### Valid PO Data
```json
{
  "poNumber": "PO-2024-001",
  "poDate": "2024-01-15T00:00:00Z",
  "vendorName": "ABC Suppliers",
  "agencyCode": "AG001",
  "totalAmount": 100000,
  "lineItems": [
    {
      "itemCode": "ITEM001",
      "description": "Product A",
      "quantity": 10,
      "unitPrice": 5000
    }
  ]
}
```

### Valid Invoice Data
```json
{
  "invoiceNumber": "INV-2024-001",
  "invoiceDate": "2024-01-20T00:00:00Z",
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
    {
      "itemCode": "ITEM001",
      "description": "Product A",
      "quantity": 10,
      "unitPrice": 5000
    }
  ]
}
```

### Valid Cost Summary Data
```json
{
  "placeOfSupply": "27",
  "state": "Maharashtra",
  "numberOfDays": 5,
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
    }
  ]
}
```

### Valid Activity Data
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
      "numberOfDays": 5
    }
  ]
}
```

### Valid Photo Metadata
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

---

## Summary

This test specification covers:
- ✅ 33 validation requirements
- ✅ 50+ individual test cases
- ✅ Integration test scenarios
- ✅ Test data templates
- ✅ Execution instructions
- ✅ Expected results for all cases

All test cases are ready for implementation and execution!
