# Validation Discrepancies Analysis

## Comparison: Requirements Document vs Implemented Code

### Summary of Discrepancies

| Category | Requirements Doc | Implemented Code | Status |
|----------|-----------------|------------------|--------|
| Total Invoice Validations | 13 field checks + 3 cross-checks | 13 field checks + 3 cross-checks | ✅ MATCH |
| Total Cost Summary Validations | 7 field checks + 3 cross-checks | 6 field checks + 3 cross-checks | ⚠️ MISMATCH |
| Total Activity Validations | 2 field checks + 1 cross-check | 3 field checks + 2 cross-checks | ⚠️ MISMATCH |
| Total Photo Validations | 4 checks | 6 checks | ⚠️ MISMATCH |
| Enquiry Dump Validations | 9 field checks | 0 checks | ❌ MISSING |

---

## 1. INVOICE VALIDATIONS

### ✅ MATCHING VALIDATIONS (13 Field Presence)

| # | Field | Requirements | Implemented | Status |
|---|-------|--------------|-------------|--------|
| 1 | Agency Name | Required | ✅ Validated | MATCH |
| 2 | Agency Address | Required | ✅ Validated | MATCH |
| 3 | Billing Name | Required | ✅ Validated | MATCH |
| 4 | Billing Address | Required | ✅ Validated | MATCH |
| 5 | State Name/Code | Required | ✅ Validated | MATCH |
| 6 | Invoice Number | Required | ✅ Validated | MATCH |
| 7 | Invoice Date | Required | ✅ Validated | MATCH |
| 8 | Vendor Code | Required | ✅ Validated | MATCH |
| 9 | GST Number | Required | ✅ Validated | MATCH |
| 10 | GST Percentage | Required (18%) | ✅ Validated (>0) | MATCH |
| 11 | HSN/SAC Code | Required | ✅ Validated | MATCH |
| 12 | Invoice Amount | Required | ✅ Validated | MATCH |
| 13 | PO Number | Required | ❌ NOT Validated | **MISSING** |

### ⚠️ INVOICE CROSS-DOCUMENT VALIDATIONS

| # | Validation | Requirements | Implemented | Status |
|---|------------|--------------|-------------|--------|
| 1 | Agency Code Match (Invoice vs PO) | Check - Match with PO | ✅ Implemented | MATCH |
| 2 | PO Number Match (Invoice vs PO) | Check - Match with PO | ✅ Implemented | MATCH |
| 3 | Vendor Code Match (Invoice vs PO) | Check - Match with PO | ✅ Implemented | MATCH |
| 4 | GST Number Match (Invoice vs State) | Check - Match with State backend | ❌ NOT Implemented | **MISSING** |
| 5 | HSN/SAC Code Match (Invoice vs Backend) | Check - Match backend | ❌ NOT Implemented | **MISSING** |
| 6 | Invoice Amount vs PO Amount | Check - Match or lesser than PO | ❌ NOT Implemented | **MISSING** |
| 7 | GST% Match (Invoice vs State) | Check - Match with State (18% default) | ❌ NOT Implemented | **MISSING** |

---

## 2. COST SUMMARY VALIDATIONS

### ⚠️ FIELD PRESENCE VALIDATIONS

| # | Field | Requirements | Implemented | Status |
|---|-------|--------------|-------------|--------|
| 1 | State/Place of Supply | Required | ✅ Validated (State) | MATCH |
| 2 | Element wise Cost | Required | ❌ NOT Validated | **MISSING** |
| 3 | No of Days | Required | ❌ NOT Validated | **MISSING** |
| 4 | No of Activation | Required (Not in PoC) | ❌ NOT Validated | MATCH (Not in PoC) |
| 5 | No of Teams | Required (Not in PoC) | ❌ NOT Validated | MATCH (Not in PoC) |
| 6 | Element wise Quantity | Required | ❌ NOT Validated | **MISSING** |
| 7 | Campaign Name | NOT in Requirements | ✅ Validated | **EXTRA** |
| 8 | Campaign Start Date | NOT in Requirements | ✅ Validated | **EXTRA** |
| 9 | Campaign End Date | NOT in Requirements | ✅ Validated | **EXTRA** |
| 10 | Total Cost | Required | ✅ Validated | MATCH |
| 11 | Cost Breakdowns | NOT in Requirements | ✅ Validated | **EXTRA** |

### ⚠️ COST SUMMARY CROSS-DOCUMENT VALIDATIONS

| # | Validation | Requirements | Implemented | Status |
|---|------------|--------------|-------------|--------|
| 1 | Total Cost vs Invoice Amount | Check - Match or lesser | ✅ Implemented (±2% tolerance) | MATCH |
| 2 | Element wise Cost vs State Rates | Check - Match with state rates | ❌ NOT Implemented | **MISSING** |
| 3 | Fixed Cost Limits vs State Rates | Check - Match with state rates | ❌ NOT Implemented | **MISSING** |
| 4 | Variable Cost Limits vs State Rates | Check - Match with state rates | ❌ NOT Implemented | **MISSING** |
| 5 | Date Range Match (Invoice in Campaign) | NOT in Requirements | ✅ Implemented | **EXTRA** |
| 6 | State Match (Cost Summary vs Invoice) | NOT in Requirements | ✅ Implemented | **EXTRA** |

---

## 3. ACTIVITY SUMMARY VALIDATIONS

### ⚠️ FIELD PRESENCE VALIDATIONS

| # | Field | Requirements | Implemented | Status |
|---|-------|--------------|-------------|--------|
| 1 | Dealer and Location details | Required | ✅ Validated (Location) | PARTIAL |
| 2 | No of days in each Location | Required (Not in PoC) | ❌ NOT Validated | MATCH (Not in PoC) |
| 3 | Activity Type | NOT in Requirements | ✅ Validated | **EXTRA** |
| 4 | Activity Date | NOT in Requirements | ✅ Validated | **EXTRA** |

### ⚠️ ACTIVITY CROSS-DOCUMENT VALIDATIONS

| # | Validation | Requirements | Implemented | Status |
|---|------------|--------------|-------------|--------|
| 1 | No of days vs Cost Summary | Check - Match with cost summary | ❌ NOT Implemented | **MISSING** |
| 2 | Date Range Match (Activity in Campaign) | NOT in Requirements | ✅ Implemented | **EXTRA** |
| 3 | Location Match (Activity vs Cost Summary) | NOT in Requirements | ✅ Implemented | **EXTRA** |

---

## 4. PHOTO PROOFS VALIDATIONS

### ⚠️ FIELD PRESENCE VALIDATIONS

| # | Field | Requirements | Implemented | Status |
|---|-------|--------------|-------------|--------|
| 1 | Date (EXIF Timestamp) | Required | ✅ Validated | MATCH |
| 2 | Lat Long (GPS Coordinates) | Required | ✅ Validated | MATCH |
| 3 | Person with Blue T-shirt | Required | ✅ Validated (AI) | MATCH |
| 4 | 3W Vehicle (Bajaj Vehicle) | Required | ✅ Validated (AI) | MATCH |

### ⚠️ PHOTO CROSS-DOCUMENT VALIDATIONS

| # | Validation | Requirements | Implemented | Status |
|---|------------|--------------|-------------|--------|
| 1 | No of days vs Cost Summary | Check - 3-way validation with activity summary | ❌ NOT Implemented | **MISSING** |
| 2 | No of photos vs Man days in Activity | Check - Cross check photos with man days | ❌ NOT Implemented | **MISSING** |
| 3 | No of man days vs Cost Summary | Check - Equal or lesser than cost summary days | ❌ NOT Implemented | **MISSING** |
| 4 | Minimum Photo Count | NOT in Requirements | ✅ Implemented | **EXTRA** |
| 5 | Date Range Match (Photo in Campaign) | NOT in Requirements | ✅ Implemented | **EXTRA** |

---

## 5. ENQUIRY DUMP VALIDATIONS

### ❌ COMPLETELY MISSING

| # | Field | Requirements | Implemented | Status |
|---|-------|--------------|-------------|--------|
| 1 | State | Required (Not in PoC) | ❌ NOT Validated | **MISSING** |
| 2 | Date | Required (Not in PoC) | ❌ NOT Validated | **MISSING** |
| 3 | Dealer Code | Required (Not in PoC) | ❌ NOT Validated | **MISSING** |
| 4 | Dealer Name | Required (Not in PoC) | ❌ NOT Validated | **MISSING** |
| 5 | District | Required (Not in PoC) | ❌ NOT Validated | **MISSING** |
| 6 | Pincode | Required (Not in PoC) | ❌ NOT Validated | **MISSING** |
| 7 | Customer Name | Required (Not in PoC) | ❌ NOT Validated | **MISSING** |
| 8 | Customer Number | Required (Not in PoC) | ❌ NOT Validated | **MISSING** |
| 9 | Test Ride Taken | Required (Not in PoC) | ❌ NOT Validated | **MISSING** |

**NOTE:** All Enquiry Dump validations are marked "Not in PoC" in requirements, so this is expected.

---

## CRITICAL MISSING VALIDATIONS (High Priority)

### 1. Invoice Validations (4 Missing)
- ❌ **PO Number field presence check** - Required field not validated
- ❌ **GST Number vs State backend match** - Cross-validation missing
- ❌ **HSN/SAC Code vs Backend match** - Cross-validation missing
- ❌ **Invoice Amount vs PO Amount** - Should be equal or lesser than PO
- ❌ **GST% vs State match** - Should match state rate (18% default)

### 2. Cost Summary Validations (6 Missing)
- ❌ **Element wise Cost field presence** - Required field not validated
- ❌ **No of Days field presence** - Required field not validated
- ❌ **Element wise Quantity field presence** - Required field not validated
- ❌ **Element wise Cost vs State Rates** - Backend rate validation missing
- ❌ **Fixed Cost Limits vs State Rates** - Backend rate validation missing
- ❌ **Variable Cost Limits vs State Rates** - Backend rate validation missing

### 3. Activity Validations (1 Missing)
- ❌ **No of days vs Cost Summary** - Cross-validation missing

### 4. Photo Validations (3 Missing)
- ❌ **No of photos vs Man days in Activity** - 3-way validation missing
- ❌ **No of man days vs Cost Summary days** - 3-way validation missing
- ❌ **No of days cross-check** - Cost Summary vs Activity vs Photos

---

## EXTRA VALIDATIONS (Not in Requirements)

### Implemented but Not Required:
1. ✅ **Cost Summary - Campaign Name** - Extra field validation
2. ✅ **Cost Summary - Campaign Start/End Date** - Extra field validation
3. ✅ **Cost Summary - Cost Breakdowns** - Extra field validation
4. ✅ **Cost Summary - Date Range Match** - Extra cross-validation
5. ✅ **Cost Summary - State Match** - Extra cross-validation
6. ✅ **Activity - Activity Type** - Extra field validation
7. ✅ **Activity - Activity Date** - Extra field validation
8. ✅ **Activity - Date Range Match** - Extra cross-validation
9. ✅ **Activity - Location Match** - Extra cross-validation
10. ✅ **Photo - Minimum Count** - Extra validation
11. ✅ **Photo - Date Range Match** - Extra cross-validation

---

## IMPLEMENTATION DIFFERENCES

### 1. Data Model Differences

**Requirements Document assumes:**
- Element-wise cost breakdown in Cost Summary
- No of Days field in Cost Summary
- Element wise Quantity in Cost Summary
- Dealer and Location details in Activity Summary
- No of days in each Location in Activity Summary

**Implemented Code uses:**
- Campaign Name, Start Date, End Date in Cost Summary
- Cost Breakdowns array (Category + Amount) in Cost Summary
- Activity Type, Location, Activity Date in Activity Summary
- No element-wise or quantity fields

### 2. Validation Logic Differences

**Requirements:**
- Invoice Amount should be **equal or lesser** than PO Amount
- Total Cost should be **equal or lesser** than Invoice Amount
- GST% should match state rate (18% default)
- Element costs should match state rates (backend)

**Implemented:**
- Invoice Amount vs Cost Summary: **±2% tolerance** (not "equal or lesser")
- No PO Amount comparison
- GST% only checks if > 0 (not state-specific)
- No state rate backend validation

---

## RECOMMENDATIONS

### Priority 1 (Critical - Required for PoC)
1. ✅ Add **PO Number field presence** validation in Invoice
2. ✅ Add **Invoice Amount vs PO Amount** comparison (equal or lesser)
3. ✅ Add **Element wise Cost** field in Cost Summary data model
4. ✅ Add **No of Days** field in Cost Summary data model
5. ✅ Add **Element wise Quantity** field in Cost Summary data model
6. ✅ Add **No of days cross-validation** (Activity vs Cost Summary)
7. ✅ Add **Photo count vs Man days** 3-way validation

### Priority 2 (Important - Backend Integration)
1. ✅ Implement **GST Number vs State** backend validation
2. ✅ Implement **HSN/SAC Code** backend validation
3. ✅ Implement **GST% vs State** backend validation (18% default)
4. ✅ Implement **Element wise Cost vs State Rates** backend validation
5. ✅ Implement **Fixed/Variable Cost Limits** backend validation

### Priority 3 (Future - Not in PoC)
1. ⏸️ Implement **Enquiry Dump** validations (all 9 fields)
2. ⏸️ Add **No of Activation** field in Cost Summary
3. ⏸️ Add **No of Teams** field in Cost Summary
4. ⏸️ Add **No of days in each Location** in Activity Summary

### Priority 4 (Optional - Already Working)
1. ✅ Keep extra validations (Campaign dates, Activity dates, etc.) - They add value
2. ✅ Keep ±2% tolerance for amount consistency - More flexible than "equal or lesser"

---

## CONCLUSION

**Total Discrepancies: 18**
- ❌ **14 Missing Validations** (required but not implemented)
- ⚠️ **11 Extra Validations** (implemented but not required)
- ⚠️ **3 Data Model Differences** (different field structure)

**PoC Readiness:**
- ✅ Core validations working (Invoice fields, Cost Summary total, Photos)
- ⚠️ Missing critical cross-validations (PO amount, element costs, 3-way photo validation)
- ❌ Backend rate validations not implemented (GST, HSN/SAC, state rates)

**Recommendation:** Implement Priority 1 validations before production deployment.
