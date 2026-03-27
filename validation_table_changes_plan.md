# Plan: Update Validation Tables in Submission / Request Details

## Overview

Update the validation tables displayed in the submission/request detail pages for all three user roles (Agency, ASM/CH, RAI/HQ) to match the new structure defined in the Excel spec. Each document type (Photo, Invoice, Cost, Activity) gets a dedicated validation table with specific rows, result columns, and evidence columns.

The changes apply identically to all three pages since they share the same validation display logic:
- `agency_submission_detail_page.dart` (Agency)
- `asm_review_detail_page.dart` (ASM/CH)
- `hq_review_detail_page.dart` (RAI/HQ)

---

## 1. Photo Validation Table

### OLD Structure (Current)

| Sno | OLD Heading | OLD Description / Evidence |
|-----|-------------|---------------------------|
| 1 | Photo Count | `{n} photos uploaded` |
| 2 | Date on Photos | `{x}/{n} photos have date mentioned` |
| 3 | GPS Coordinates | `{x}/{n} photos have coordinates present` |
| 4 | No. of Days | `Photo count ({n}) meets/is less than required days in Cost Summary ({d})` |
| 5 | Promoter wearing Blue T-shirt | `{x}/{n} photos have promoters wear blue T-shirt` |
| 6 | Branded 3 Wheeler | `{x}/{n} photos have Branded 3W` |

### NEW Structure (Target — from Excel)

| Sno | NEW Heading | Result | Evidence |
|-----|-------------|--------|----------|
| 1 | Photo count | Pass/Fail | `{n} Photos uploaded` |
| 2 | Date on photos | Pass/Fail | `{x}/{n} Photos have date mentioned` |
| 3 | GPS coordinates | Pass/Fail | `{x}/{n} Photos have coordinates present` |
| 4 | No. of days | Pass/Fail | *(cross-doc: photo count vs cost summary days)* |
| 5 | Promoter wearning blue T-shirt | Pass/Fail | `{x}/{n} Photos have promoters wearing blue T-shirt` |
| 6 | Branded 3 wheeler | Pass/Fail | `{x}/{n} Photos have branded 3 wheelers` |

### Mapping (OLD → NEW)

| # | OLD Key / Label | NEW Key / Label | Value Mapping | Notes |
|---|----------------|-----------------|---------------|-------|
| 1 | `Photo Count` | `Photo Count` | No change | Same label, same evidence format |
| 2 | `Date on Photos` | `Date on Photos` | No change | Same label, same evidence format |
| 3 | `GPS Coordinates` | `Gps Coordinates` | Label casing change: `GPS` → `Gps` | Evidence format unchanged |
| 4 | `No. of Days` | `No. of Days` | No change | Cross-document check from `photoCountMatchesManDays` |
| 5 | `Promoter wearing Blue T-shirt` | `Promoter wearning Blue T-shirt` | Label change (note: Excel has typo "wearning") | Evidence unchanged |
| 6 | `Branded 3 Wheeler` | `Branded 3 wheeler` | Label casing change: `Wheeler` → `wheeler`; evidence: `Branded 3W` → `Branded 3 W` | Label + evidence text change |

### What Changes

- **Label updates**: `GPS Coordinates` → `Gps Coordinates`, `Promoter wearing Blue T-shirt` → `Promoter wearning Blue T-shirt`, `Branded 3 Wheeler` → `Branded 3 wheeler`
- **Evidence text**: `Branded 3W` → `Branded 3 W`
- **No structural change** — same 6 rows, same pass/fail logic, same data sources

### Backend Impact
- None. Photo validation data (`PhotoFieldPresenceResult`, `PhotoCrossDocumentResult`) already provides all needed fields. Label changes are frontend-only.

### Frontend Impact
- Update `_extractPhotoValidationRows()` method in all 3 pages to use new labels
- Update evidence string for row 6 (`Branded 3 W` instead of `Branded 3W`)

---

## 2. Invoice Validation Table

### OLD Structure (Current)

The invoice validation currently shows ALL extracted proactive rules + field presence + cross-document checks without filtering. Typical rows include:

| Sno | OLD Heading | Source |
|-----|-------------|--------|
| 1 | Invoice Number | `INV_INVOICE_NUMBER_PRESENT` / `INV_NUMBER_PRESENT` |
| 2 | Invoice Date | `INV_DATE_PRESENT` |
| 3 | Invoice Amount | `INV_AMOUNT_PRESENT` |
| 4 | GST Number | `INV_GST_NUMBER_PRESENT` / `INV_GST_PRESENT` |
| 5 | GST Percentage | `INV_GST_PERCENT_PRESENT` |
| 6 | HSN/SAC Code | `INV_HSN_SAC_PRESENT` |
| 7 | Vendor Code | `INV_VENDOR_CODE_PRESENT` |
| 8 | Agency Name & Address | `INV_AGENCY_NAME_ADDRESS` |
| 9 | Billing Name & Address | `INV_BILLING_NAME_ADDRESS` |
| 10 | Supplier State | `INV_SUPPLIER_STATE` |
| 11 | PO Number Match | `INV_PO_NUMBER_MATCH` / `INV_PO_MATCH` |
| 12 | Amount vs PO Balance | `INV_AMOUNT_VS_PO_BALANCE` |
| + | Agency Code Match | `agencyCodeMatches` (crossDocument) |
| + | GST State Match | `gstStateMatches` (crossDocument) |
| + | Invoice Amount (valid) | `invoiceAmountValid` (crossDocument) |
| + | GST Percentage (valid) | `gstPercentageValid` (crossDocument) |

### NEW Structure (Target — from Excel)

| Sno | NEW Heading | Result | Evidence |
|-----|-------------|--------|----------|
| 1 | Invoice number | Pass/Fail | *(extracted value)* |
| 2 | Invoice date | Pass/Fail | *(extracted value)* |
| 3 | Invoice amount | Pass/Fail | *(extracted value)* |
| 4 | Agency name & addresses | Pass/Fail | *(extracted value)* |
| 5 | Agency code | Pass/Fail | *(extracted value)* |
| 6 | PO number | Pass/Fail | *(extracted/matched value)* |
| 7 | GSTIN for state | Pass/Fail | *(extracted value)* |
| 8 | GST % | Pass/Fail | *(extracted value)* |
| 9 | Invoice amount limit | Pass/Fail | *(amount vs PO balance check)* |

### Mapping (OLD → NEW)

| # | OLD Key / Label | NEW Key / Label | Value Mapping | Notes |
|---|----------------|-----------------|---------------|-------|
| 1 | `Invoice Number` (`INV_INVOICE_NUMBER_PRESENT`) | `Invoice Number` | No change | Same source |
| 2 | `Invoice Date` (`INV_DATE_PRESENT`) | `Invoice Date` | No change | Same source |
| 3 | `Invoice Amount` (`INV_AMOUNT_PRESENT`) | `Invoice amount` | Label casing: `Amount` → `amount` | Same source |
| 4 | `Agency Name & Address` (`INV_AGENCY_NAME_ADDRESS`) | `Agency Name & Addresses` | Label: `Address` → `Addresses` (plural) | Same source |
| 5 | `Agency Code Match` (`agencyCodeMatches` crossDoc) OR `Vendor Code` (`INV_VENDOR_CODE_PRESENT`) | `Agency Code` | Renamed. Maps to `agencyCodeMatches` cross-doc check or `INV_VENDOR_CODE_PRESENT` | Prefer cross-doc check |
| 6 | `PO Number Match` (`INV_PO_NUMBER_MATCH`) | `PO Number` | Label simplified: removed "Match" suffix | Same source |
| 7 | `GST Number` (`INV_GST_NUMBER_PRESENT`) + `GST State Match` (`gstStateMatches`) | `GSTIN for State` | Merged: GST number presence + state match into single row | Combine both checks |
| 8 | `GST Percentage` (`INV_GST_PERCENT_PRESENT`) | `GST %` | Label change: `GST Percentage` → `GST %` | Same source |
| 9 | `Amount vs PO Balance` (`INV_AMOUNT_VS_PO_BALANCE`) | `Invoice amount limit` | Label change: `Amount vs PO Balance` → `Invoice amount limit` | Same source |

### Rows REMOVED from display

| OLD Label | Reason |
|-----------|--------|
| HSN/SAC Code | Not in new spec |
| Billing Name & Address | Not in new spec |
| Supplier State | Not in new spec (merged into GSTIN for State) |
| Invoice Amount (crossDoc valid) | Redundant with Invoice amount limit |
| GST Percentage (crossDoc valid) | Redundant with GST % |

### What Changes

- **Add invoice filtering** (like cost summary already has) — only show the 9 specified rows
- **Enforce exact row order** matching Excel sequence (Invoice Number → Invoice Date → Invoice amount → Agency Name & Addresses → Agency Code → PO Number → GSTIN for State → GST % → Invoice amount limit)
- **Rename labels** to match new spec
- **Merge** GST Number + GST State Match into single "GSTIN for State" row
- **Remove** HSN/SAC Code, Billing Name & Address, Supplier State from display

### Backend Impact
- None. All data already exists in `validationDetailsJson`. This is a frontend display filter change.

### Frontend Impact
- Update `_filterInvoiceRows()` method in all 3 pages to use an ordered list instead of iterating source rows — build result in the exact Excel sequence by looking up each target label from the source rows
- This ensures rows always appear in the Excel-defined order regardless of backend data order

---

## 3. Cost Summary Validation Table

### OLD Structure (Current — already filtered to 8 rows)

| Sno | OLD Heading | Source |
|-----|-------------|--------|
| 1 | State/Place of Supply | `CS_PLACE_OF_SUPPLY_PRESENT` |
| 2 | Element wise Cost | `CS_ELEMENT_WISE_COST` |
| 3 | No of Days | `CS_NUMBER_OF_DAYS` |
| 4 | Element wise Quantity | `CS_ELEMENT_WISE_QTY` |
| 5 | Total Cost | `totalCostValid` (crossDocument) |
| 6 | Element Cost limit as per State Rate | `elementCostsValid` / `CS_ELEMENT_COST_VS_RATES` |
| 7 | Fixed Cost Limit as per State Rate | `fixedCostsValid` (crossDocument) |
| 8 | Variable cost limit as per State Rate | `variableCostsValid` (crossDocument) |

### NEW Structure (Target — from Excel)

| Sno | NEW Heading | Result | Evidence |
|-----|-------------|--------|----------|
| 1 | State/Place of supply | Pass/Fail | *(extracted value)* |
| 2 | Element wise cost | Pass/Fail | *(extracted value)* |
| 3 | No of days | Pass/Fail | *(extracted value)* |
| 4 | Element wise quantity | Pass/Fail | *(extracted value)* |
| 5 | Total cost | Pass/Fail | *(total cost validation result)* |
| 6 | Element cost limit as per state rate | Pass/Fail | *(element cost vs rate card)* |
| 7 | Fixed cost limit as per state rate | Pass/Fail | *(fixed cost vs rate card)* |
| 8 | Variable cost limit as per state rate | Pass/Fail | *(variable cost vs rate card)* |

### Mapping (OLD → NEW)

| # | OLD Label | NEW Label | Value Mapping | Notes |
|---|-----------|-----------|---------------|-------|
| 1 | State/Place of Supply | State/Place of Supply | No change | Identical |
| 2 | Element wise Cost | Element wise Cost | No change | Identical |
| 3 | No of Days | No of Days | No change | Identical |
| 4 | Element wise Quantity | Element wise Quantity | No change | Identical |
| 5 | Total Cost | Total Cost | No change | Identical |
| 6 | Element Cost limit as per State Rate | Element Cost limit as per State Rate | No change | Identical |
| 7 | Fixed Cost Limit as per State Rate | Fixed Cost Limit as per State Rate | No change | Identical |
| 8 | Variable cost limit as per State Rate | Variable cost limit as per State Rate | No change | Identical |

### What Changes

- **Enforce exact row order** matching Excel sequence — update `_filterCostSummaryRows()` to build result in defined order instead of iterating source rows
- Labels and row count unchanged (same 8 rows, same labels)

### Backend Impact
- None.

### Frontend Impact
- Update `_filterCostSummaryRows()` in all 3 pages to use ordered lookup instead of source-order iteration

---

## 4. Activity Validation Table

### OLD Structure (Current)

The activity validation currently shows ALL extracted proactive rules + field presence + cross-document checks without filtering. Typical rows include:

| Sno | OLD Heading | Source |
|-----|-------------|--------|
| 1 | Dealer/Location | `AS_DEALER_LOCATION_PRESENT` |
| 2 | Total No. of Days | `AS_TOTAL_DAYS` |
| 3 | Total No. of Working Days | `AS_TOTAL_WORKING_DAYS` |
| 4 | Days Match (Cost Summary) | `AS_DAYS_MATCH_COST_SUMMARY` |
| 5 | Days Match (Team Details) | `AS_DAYS_MATCH_TEAM_DETAILS` |
| + | Number of Days Match | `numberOfDaysMatches` (crossDocument) |

### NEW Structure (Target — from Excel)

| Sno | NEW Heading | Result | Evidence |
|-----|-------------|--------|----------|
| 1 | Days worked matches cost summary | Pass/Fail | *(cross-document days comparison)* |

### Mapping (OLD → NEW)

| # | OLD Key / Label | NEW Key / Label | Value Mapping | Notes |
|---|----------------|-----------------|---------------|-------|
| 1 | `Days Match (Cost Summary)` (`AS_DAYS_MATCH_COST_SUMMARY`) OR `Number of Days Match` (`numberOfDaysMatches`) | `Days worked matches Cost Summary` | Same pass/fail logic | Prefer proactive rule `AS_DAYS_MATCH_COST_SUMMARY`, fallback to crossDoc `numberOfDaysMatches` |

### Rows REMOVED from display

| OLD Label | Reason |
|-----------|--------|
| Dealer/Location | Not in new spec |
| Total No. of Days | Not in new spec |
| Total No. of Working Days | Not in new spec |
| Days Match (Team Details) | Not in new spec |

### What Changes

- **Add activity filtering** — only show 1 row: "Days worked matches Cost Summary"
- **Rename label** from "Days Match (Cost Summary)" to "Days worked matches Cost Summary"
- **Remove** all other activity rows from display

### Backend Impact
- None. The `AS_DAYS_MATCH_COST_SUMMARY` rule and `numberOfDaysMatches` cross-doc check already exist.

### Frontend Impact
- Add `_filterActivityRows()` method in all 3 pages
- Call it in `_buildSingleValidationCard()` when title contains "Activity"
- Map old label to new label, filter to only 1 row

---

## Summary of Changes by File

### Files to Modify (Frontend Only — No Backend Changes)

| File | Changes |
|------|---------|
| `frontend/lib/features/submission/presentation/pages/agency_submission_detail_page.dart` | 1. Update `_extractPhotoValidationRows()` labels<br>2. Add `_filterInvoiceRows()` method<br>3. Add `_filterActivityRows()` method<br>4. Call invoice filter in `_buildInvoiceValidationCard()`<br>5. Call activity filter in `_buildSingleValidationCard()` for Activity |
| `frontend/lib/features/approval/presentation/pages/asm_review_detail_page.dart` | Same 5 changes as agency page |
| `frontend/lib/features/approval/presentation/pages/hq_review_detail_page.dart` | Same 5 changes as agency page |

### Files NOT Modified

| File | Reason |
|------|--------|
| Backend `ValidationAgent.cs` | No backend logic changes — all validation checks remain the same |
| Backend `IValidationAgent.cs` | No interface changes |
| Backend `SubmissionDetailResponse.cs` | No DTO changes |
| Backend `ValidationResult.cs` | No entity changes |
| Cost Summary filter logic | Already matches new spec |

### Rule Code Label Map Updates (in `_ruleCodeToLabel()`)

| Rule Code | OLD Label | NEW Label |
|-----------|-----------|-----------|
| `INV_AMOUNT_PRESENT` | `Invoice Amount` | `Invoice amount` |
| `INV_AGENCY_NAME_ADDRESS` | `Agency Name & Address` | `Agency Name & Addresses` |
| `INV_GST_NUMBER_PRESENT` | `GST Number` | `GSTIN for State` |
| `INV_GST_PERCENT_PRESENT` | `GST Percentage` | `GST %` |
| `INV_PO_NUMBER_MATCH` | `PO Number Match` | `PO Number` |
| `INV_AMOUNT_VS_PO_BALANCE` | `Amount vs PO Balance` | `Invoice amount limit` |
| `AS_DAYS_MATCH_COST_SUMMARY` | `Days Match (Cost Summary)` | `Days worked matches Cost Summary` |

---

## Implementation Order

1. **Invoice filter — enforce sequence** — Rewrite `_filterInvoiceRows()` in all 3 pages to iterate a fixed ordered list of 9 target labels, looking up each from source rows. This guarantees Excel order.
2. **Cost Summary filter — enforce sequence** — Rewrite `_filterCostSummaryRows()` in all 3 pages using same ordered-lookup pattern.
3. **Activity filter — already ordered** — Only 1 row, no ordering issue. Already done.
4. **Validation section order** — Already reordered to Photo → Invoice → Cost → Activity. Enquiry removed.
5. **Test** — Verify all 3 pages display correct rows in correct order for each document type
