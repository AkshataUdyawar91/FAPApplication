# Chatbot Validation Rules Documentation

This document details every validation rule executed during the chatbot submission flow, how each value is calculated, and how results are persisted to the database.

---

## Validation Architecture

When a document is uploaded through the chatbot, the backend runs proactive validation rules immediately after AI extraction completes. The flow is:

1. Frontend uploads file via `POST /api/documents/upload`
2. Frontend polls `GET /api/documents/{id}/extraction-status` every 3s until `extracted`
3. Frontend sends `{action}_uploaded` to `POST /api/assistant/message` with the document ID
4. Backend loads the document entity (with AI-extracted data populated in columns and `ExtractedDataJson`)
5. Backend runs the `Run{DocType}ValidationRules()` method
6. Results are persisted to the `ValidationResults` table
7. Results are returned to the frontend as `validationRules[]` in the response

---

## Database Schema: `ValidationResults` Table

Every validation result is stored in this table, keyed by `DocumentId`:

| Column | Type | Description |
|---|---|---|
| `Id` | `Guid` | Primary key |
| `DocumentType` | `enum` | `Invoice`, `CostSummary`, `ActivitySummary`, `EnquiryDocument`, `TeamPhoto` |
| `DocumentId` | `Guid` | FK to the specific document being validated |
| `AllValidationsPassed` | `bool` | `true` only if zero non-warning failures |
| `RuleResultsJson` | `string?` | JSON array of individual rule results (see structure below) |
| `ValidationDetailsJson` | `string?` | Unified JSON with source, timestamp, counts, and rules |
| `FailureReason` | `string?` | Semicolon-joined messages from failed/warning rules |
| `SapVerificationPassed` | `bool` | Legacy SAP check flag |
| `AmountConsistencyPassed` | `bool` | Legacy amount check flag |
| `LineItemMatchingPassed` | `bool` | Legacy line item check flag |
| `CompletenessCheckPassed` | `bool` | Legacy completeness flag |
| `DateValidationPassed` | `bool` | Legacy date check flag |
| `VendorMatchingPassed` | `bool` | Legacy vendor check flag |
| `CreatedAt` | `DateTime` | Record creation timestamp |
| `UpdatedAt` | `DateTime` | Last update timestamp |

### Upsert Logic

For every document, the system checks if a `ValidationResult` already exists for that `DocumentId`:
- If exists → updates `AllValidationsPassed`, `RuleResultsJson`, `ValidationDetailsJson`, `FailureReason`, `UpdatedAt`
- If not → inserts a new row

This makes re-uploads and re-validations idempotent.

---

## Per-Rule Result Structure

Each rule in `RuleResultsJson` and in the API response follows this shape:

```json
{
  "ruleCode": "INV_INVOICE_NUMBER_PRESENT",
  "type": "Required",
  "passed": true,
  "isWarning": false,
  "label": "Invoice Number",
  "extractedValue": "E-INV-145",
  "message": null
}
```

| Field | Description |
|---|---|
| `ruleCode` | Unique identifier for the rule |
| `type` | `"Required"` (must pass) or `"Check"` (cross-validation) |
| `passed` | Whether the check passed |
| `isWarning` | If `true`, counts as warning not hard failure |
| `label` | Human-readable name shown in the validation table UI |
| `extractedValue` | The value extracted from the document (shown in the "Extracted" column) |
| `message` | Error/warning message when not passed; `null` when passed |

### `ValidationDetailsJson` Structure

Built by `BuildValidationDetailsJson()`, wraps the rules with metadata:

```json
{
  "source": "proactive",
  "validatedAt": "2026-03-27T10:30:00.000Z",
  "totalRules": 9,
  "passed": 7,
  "failed": 1,
  "warnings": 1,
  "rules": [ ...same rule objects as RuleResultsJson... ]
}
```

### Summary Counts in API Response

The response also includes pre-computed counts:
- `passedCount` = rules where `passed == true && isWarning == false`
- `failedCount` = rules where `passed == false && isWarning == false`
- `warningCount` = rules where `isWarning == true`

`AllValidationsPassed` in the DB is set to `failCount == 0`.

---

## 1. Invoice Validation (9 Rules)

Method: `RunInvoiceValidationRules(Invoice invoice, PO? po, decimal? livePoBalance)`

Data sources:
- `Invoice` entity columns: `InvoiceNumber`, `InvoiceDate`, `TotalAmount`, `GSTNumber`
- `Invoice.ExtractedDataJson`: AI-extracted JSON with `AgencyName`, `AgencyAddress`, `VendorCode`, `PONumber`, `GSTPercentage`
- `PO` entity: loaded via `package.SelectedPOId` or `invoice.POId`
- `livePoBalance`: computed as `PO.TotalAmount - SUM(other invoices on same PO)`

| # | Rule Code | Label | Type | How Value Is Calculated | Pass Condition |
|---|---|---|---|---|---|
| 1 | `INV_INVOICE_NUMBER_PRESENT` | Invoice Number | Required | `invoice.InvoiceNumber` | Not null/whitespace |
| 2 | `INV_DATE_PRESENT` | Invoice Date | Required | `invoice.InvoiceDate` → formatted as `dd-MMM-yyyy` | Has value and not `default` |
| 3 | `INV_AMOUNT_PRESENT` | Invoice amount | Required | `invoice.TotalAmount` → formatted as `₹{value:N0}` | Has value and > 0 |
| 4 | `INV_AGENCY_NAME_ADDRESS` | Agency Name & Addresses | Required | Parsed from `ExtractedDataJson` keys `AgencyName` + `AgencyAddress` → displayed as `"{name}, {address}"` | Both name and address are non-empty |
| 5 | `INV_VENDOR_CODE_PRESENT` | Agency Code | Required | Parsed from `ExtractedDataJson` key `VendorCode` | Not null/whitespace |
| 6 | `INV_PO_NUMBER_MATCH` | PO Number | Check | Parsed from `ExtractedDataJson` key `PONumber` → compared case-insensitively against `po.PONumber` | Extracted PO number matches selected PO number |
| 7 | `INV_GST_NUMBER_PRESENT` | GSTIN for State | Required | `invoice.GSTNumber` | Not null/whitespace AND exactly 15 characters |
| 8 | `INV_GST_PERCENT_PRESENT` | GST % | Required | Parsed from `ExtractedDataJson` key `GSTPercentage` → displayed as `"{value}%"` | Has value and > 0 |
| 9 | `INV_AMOUNT_VS_PO_BALANCE` | Invoice amount limit | Check | `invoice.TotalAmount` compared against available PO balance. Balance = `livePoBalance ?? po.RemainingBalance ?? po.TotalAmount`. Displayed as `"₹{invoiceAmt:N0}"` with message showing balance | Invoice amount ≤ available PO balance. If exceeds → `isWarning = true` (not hard fail) |

### Live PO Balance Calculation (Rule 9)

```
livePoBalance = PO.TotalAmount - SUM(TotalAmount of all other non-deleted invoices on this PO, excluding current invoice)
```

This is computed at validation time via a DB query:
```csharp
var alreadyConsumed = await _context.Invoices
    .Where(i => i.POId == po.Id && !i.IsDeleted && i.Id != docId && i.TotalAmount.HasValue)
    .SumAsync(i => i.TotalAmount!.Value, ct);
livePoBalance = po.TotalAmount.Value - alreadyConsumed;
```

Fallback chain: `livePoBalance` → `po.RemainingBalance` → `po.TotalAmount` → `0`

---

## 2. Cost Summary Validation (8 Rules)

Method: `RunCostSummaryValidationRules(CostSummary costSummary, decimal? invoiceAmount)`

Data sources:
- `CostSummary` entity columns: `PlaceOfSupply`, `NumberOfDays`, `NumberOfActivations`, `NumberOfTeams`, `TotalCost`, `ElementWiseCostsJson`, `ElementWiseQuantityJson`, `CostBreakdownJson`
- `CostSummary.ExtractedDataJson`: fallback if dedicated columns are null. Parses `placeOfSupply`/`state`, `numberOfDays`, `numberOfActivations`, `numberOfTeams`, `totalCost`, and `costBreakdowns[]` array
- `invoiceAmount`: loaded from the latest non-deleted Invoice on the same `PackageId`

### Fallback Logic

If any dedicated column is null, the system parses `ExtractedDataJson` (case-insensitive) to fill in missing values. For `costBreakdowns[]` array, it builds `elementWiseCosts` and `elementWiseQuantity` JSON from the array elements.

| # | Rule Code | Label | Type | How Value Is Calculated | Pass Condition |
|---|---|---|---|---|---|
| 1 | `CS_PLACE_OF_SUPPLY_PRESENT` | State/Place of Supply | Required | `costSummary.PlaceOfSupply` or fallback from `ExtractedDataJson.placeOfSupply` / `state` | Not null/whitespace |
| 2 | `CS_ELEMENT_WISE_COSTS_PRESENT` | Element wise Cost | Required | `costSummary.ElementWiseCostsJson` or built from `ExtractedDataJson.costBreakdowns[]` | Not null/whitespace and not `"[]"` |
| 3 | `CS_TOTAL_DAYS_PRESENT` | No of Days | Required | `costSummary.NumberOfDays` or fallback from `ExtractedDataJson.numberOfDays` → displayed as integer string | Has value and > 0 |
| 4 | `CS_ELEMENT_WISE_QUANTITY_PRESENT` | Element wise Quantity | Required | `costSummary.ElementWiseQuantityJson` or built from `ExtractedDataJson.costBreakdowns[]` | Not null/whitespace and not `"[]"` |
| 5 | `CS_TOTAL_VS_INVOICE` | Total Cost | Required | `costSummary.TotalCost` compared against `invoiceAmount` (latest invoice on same package). Displayed as `"Cost: ₹{totalCost:F2} \| Invoice: ₹{invoiceAmount:F2}"` | `totalCost ≤ invoiceAmount`. If either is null → `isWarning = true` |
| 6 | `CS_ELEMENT_COST_VS_RATES` | Element Cost limit as per State Rate | Check | Checks if `CostBreakdownJson` or `ExtractedDataJson.costBreakdowns[]` is present | Breakdown data exists (presence check only) |
| 7 | `CS_FIXED_COST_LIMITS` | Fixed Cost Limit as per State Rate | Check | Iterates `costBreakdowns[]` where `isFixedCost == true`. For each item, calls `_referenceData.ValidateFixedCostLimit(elementName, amount, stateCode)`. State code resolved via `_referenceData.GetStateCodeByName(placeOfSupply)` | All fixed cost items within state rate limits |
| 8 | `CS_VARIABLE_COST_LIMITS` | Variable cost limit as per State Rate | Check | Iterates `costBreakdowns[]` where `isVariableCost == true`. For each item, calls `_referenceData.ValidateVariableCostLimit(elementName, amount, stateCode)` | All variable cost items within state rate limits |

### State Rate Validation (Rules 7 & 8)

The system uses `IReferenceDataService` to validate cost limits:
1. Resolves state name to state code: `_referenceData.GetStateCodeByName(placeOfSupply)`
2. For each cost breakdown item flagged as fixed/variable:
   - Reads `elementName` (or `category`) and `amount` from the breakdown JSON
   - Calls `ValidateFixedCostLimit()` or `ValidateVariableCostLimit()` against state-specific rate cards
3. If state is not identified → `isWarning = true` (cannot validate)
4. If no fixed/variable items found → passes with message "No items found to validate"

---

## 3. Activity Summary Validation (1 Rule)

Method: `RunActivitySummaryValidationRules(ActivitySummary actSummary, int? costSummaryDays)`

Data sources:
- `ActivitySummary.TotalWorkingDays`: extracted by AI from the activity summary document
- `costSummaryDays`: `CostSummary.NumberOfDays` from the most recent cost summary on the same package

Cost summary lookup priority:
1. Exact `costSummaryDocumentId` from payload (set during cost summary upload step)
2. Fallback: latest non-deleted `CostSummary` for the same `PackageId`

| # | Rule Code | Label | Type | How Value Is Calculated | Pass Condition |
|---|---|---|---|---|---|
| 1 | `AS_DAYS_MATCH_COST_SUMMARY` | Days worked matches Cost Summary | Required | `actSummary.TotalWorkingDays` compared against `costSummary.NumberOfDays`. Displayed as `"Activity Working Days: {X} \| Cost Summary Days: {Y}"` | Values are equal. If either is null → `isWarning = true` with message explaining which value is missing |

---

## 4. Team Photo Validation (4 Rules per Photo)

Method: `RunPhotoValidationRules(TeamPhotos photo)`

Each photo is validated individually. Data sources per photo:
- `TeamPhotos` entity columns: `PhotoTimestamp`, `DateVisible`, `PhotoDateOverlay`, `Latitude`, `Longitude`, `BlueTshirtPresent`, `ThreeWheelerPresent`
- `TeamPhotos.ExtractedMetadataJson`: fallback if dedicated columns are null. Parses `timestamp`, `photoDateFromOverlay`, `latitude`, `longitude`, `hasBlueTshirtPerson`/`blueTshirtPresent`, `has3WVehicle`/`threeWheelerPresent`

### Fallback Logic

If `DateVisible` and `BlueTshirtPresent` columns are both null, the system parses `ExtractedMetadataJson` (case-insensitive) to fill in all four detection values.

| # | Rule Code | Label | Type | How Value Is Calculated | Pass Condition |
|---|---|---|---|---|---|
| 1 | `PHOTO_DATE_VISIBLE` | Date on Photos | Required | `photo.DateVisible ?? photo.PhotoTimestamp.HasValue`. Value displayed as `PhotoTimestamp` formatted `dd-MMM-yyyy HH:mm`, or `PhotoDateOverlay`. Fallback: `ExtractedMetadataJson.timestamp` or `photoDateFromOverlay` | Date is visible/detected |
| 2 | `PHOTO_GPS_VISIBLE` | GPS Coordinates | Required | `photo.Latitude.HasValue && photo.Longitude.HasValue`. Displayed as `"{lat:F4}, {lon:F4}"`. Fallback: `ExtractedMetadataJson.latitude` + `longitude` | Both lat and lon present |
| 3 | `PHOTO_BLUE_TSHIRT` | Promoter wearing Blue T-shirt | Required | `photo.BlueTshirtPresent ?? false`. Displayed as `"Present ✓"` when true. Fallback: `ExtractedMetadataJson.hasBlueTshirtPerson` or `blueTshirtPresent` | AI detected blue t-shirt person |
| 4 | `PHOTO_3W_VEHICLE` | Branded 3 wheeler | Required | `photo.ThreeWheelerPresent ?? false`. Displayed as `"Present ✓"` when true. Fallback: `ExtractedMetadataJson.has3WVehicle` or `threeWheelerPresent` | AI detected 3-wheeler vehicle |

### Photo-Level DB Persistence

For each photo:
- `TeamPhotos.IsFlaggedForReview` is set to `true` if any rule fails
- A `ValidationResult` row is upserted with `DocumentType = TeamPhoto` and `DocumentId = photoId`

### Photo Constraints

- Maximum 10 photos per team (enforced before validation runs)
- Photos are linked to teams via `TeamPhotos.TeamId`
- `DisplayOrder` is assigned sequentially starting from existing count + 1

---

## 5. Enquiry Dump Validation (9 Rules)

Method: `RunEnquiryDumpValidationRules(List<EnquiryRecord> records)`

Data source:
- `EnquiryDocument.ExtractedDataJson` → deserialized as `EnquiryDumpData.Records[]`
- Each record has fields: `CustomerNumber`, `State`, `Date`, `DealerCode`, `DealerName`, `District`, `Pincode`, `CustomerName`, `TestRideTaken`

All 9 rules use the same pattern: count how many records have the field populated, compute the percentage, and check against an 80% threshold.

| # | Rule Code | Label | Type | How Value Is Calculated | Pass Condition |
|---|---|---|---|---|---|
| 1 | `EQ_CUSTOMER_PHONE` | Customer Phone | Required | Count of records where `CustomerNumber` is not null/whitespace. Displayed as `"{count}/{total} records ({pct:P0})"` | ≥ 80% of records have value |
| 2 | `EQ_STATE` | State | Required | Count where `State` is not null/whitespace | ≥ 80% |
| 3 | `EQ_DATE` | Date | Required | Count where `Date.HasValue` | ≥ 80% |
| 4 | `EQ_DEALER_CODE` | Dealer Code | Required | Count where `DealerCode` is not null/whitespace | ≥ 80% |
| 5 | `EQ_DEALER_NAME` | Dealer Name | Required | Count where `DealerName` is not null/whitespace | ≥ 80% |
| 6 | `EQ_DISTRICT` | District | Required | Count where `District` is not null/whitespace | ≥ 80% |
| 7 | `EQ_PINCODE` | Pincode | Required | Count where `Pincode` is not null/whitespace | ≥ 80% |
| 8 | `EQ_CUSTOMER_NAME` | Customer Name | Required | Count where `CustomerName` is not null/whitespace | ≥ 80% |
| 9 | `EQ_TEST_RIDE` | Test Ride | Required | Count where `TestRideTaken` is not null/whitespace | ≥ 80% |

### Threshold Calculation

```
percentage = (count of records with field present) / (total records)
passed = percentage >= 0.80
```

If zero records are extracted, all 9 rules fail with message `"No records found"`.

### Additional Response Fields

The enquiry validation response includes two extra fields beyond the standard rule results:
- `totalRecords`: total number of enquiry records parsed from the Excel
- `missingPhoneCount`: count of records where `CustomerNumber` is null/whitespace

---

## Extraction Wait Behavior

For Cost Summary and Enquiry Dump, the backend has an additional server-side wait loop if `ExtractedDataJson` is still null when the validation handler runs:

```
Poll every 2 seconds, up to 30 attempts (60 seconds total)
Re-query the document from DB each iteration
Break as soon as ExtractedDataJson is populated
```

This is in addition to the frontend's own extraction polling (every 3s, up to 40 attempts / 120s).

---

## Read-Back Verification

After persisting validation results, the Cost Summary and Enquiry Dump handlers read back from the `ValidationResults` table and use the DB-stored `RuleResultsJson` for the API response. This ensures the response exactly matches what was persisted. If the read-back fails, the in-memory rules are used as fallback.

---

## Summary of All Rules by Document Type

| Document Type | Rule Count | Rule Codes |
|---|---|---|
| Invoice | 9 | `INV_INVOICE_NUMBER_PRESENT`, `INV_DATE_PRESENT`, `INV_AMOUNT_PRESENT`, `INV_AGENCY_NAME_ADDRESS`, `INV_VENDOR_CODE_PRESENT`, `INV_PO_NUMBER_MATCH`, `INV_GST_NUMBER_PRESENT`, `INV_GST_PERCENT_PRESENT`, `INV_AMOUNT_VS_PO_BALANCE` |
| Cost Summary | 8 | `CS_PLACE_OF_SUPPLY_PRESENT`, `CS_ELEMENT_WISE_COSTS_PRESENT`, `CS_TOTAL_DAYS_PRESENT`, `CS_ELEMENT_WISE_QUANTITY_PRESENT`, `CS_TOTAL_VS_INVOICE`, `CS_ELEMENT_COST_VS_RATES`, `CS_FIXED_COST_LIMITS`, `CS_VARIABLE_COST_LIMITS` |
| Activity Summary | 1 | `AS_DAYS_MATCH_COST_SUMMARY` |
| Team Photo | 4 (per photo) | `PHOTO_DATE_VISIBLE`, `PHOTO_GPS_VISIBLE`, `PHOTO_BLUE_TSHIRT`, `PHOTO_3W_VEHICLE` |
| Enquiry Dump | 9 | `EQ_CUSTOMER_PHONE`, `EQ_STATE`, `EQ_DATE`, `EQ_DEALER_CODE`, `EQ_DEALER_NAME`, `EQ_DISTRICT`, `EQ_PINCODE`, `EQ_CUSTOMER_NAME`, `EQ_TEST_RIDE` |


---

# Chatbot Submission Flow — Sections & How They Work

This section documents the complete guided conversational flow in the chatbot, covering every section (step), the response types rendered, user actions available, backend handlers, and how data flows between steps.

---

## Architecture Overview

The chatbot is a guided workflow assistant that walks Agency users through creating a field activity submission. It uses a single API endpoint with action-based routing:

- Endpoint: `POST /api/assistant/message`
- Controller: `AssistantController`
- Authorization: JWT required, roles `Agency`, `ASM`, `HQ`
- Request DTO: `AssistantRequest` with fields `action`, `message`, `payloadJson`
- Response DTO: `AssistantResponse` with `type` (determines which UI widget renders), `message`, and type-specific data fields

The frontend uses a Riverpod `AssistantNotifier` that manages `AssistantState` containing the message history, loading state, selected PO, submission ID, team payload context, and current step tracking.

### State Tracking

```
AssistantState {
  messages: List<AssistantMessage>   // Full chat history
  isLoading: bool                    // API call in progress
  selectedPO: POItemModel?           // PO selected in step 2
  submissionId: String?              // Draft package ID (created at step 3)
  lastDocumentId: String?            // Most recently uploaded document
  teamPayloadJson: String?           // Carries team context across steps 7-9
  isSubmissionFlow: bool             // True once "create_request" is tapped
  currentStep: int                   // 0=not in flow, 1-5=current phase
}
```

### Payload Propagation

Multi-step context (submission ID, team number, dealer info, dates) is carried through the flow via `payloadJson` — a JSON string passed in each request and echoed back in each response. The frontend stores this in `teamPayloadJson` and sends it with every subsequent action.

---

## Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│  Phase 1: GREETING                                                  │
│  action: greet → type: greeting                                     │
│  Cards: [Start new submission, Show pending claims, Why returned]   │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ tap "Start a new submission"
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Phase 2: PO SELECTION                                              │
│  action: create_request → type: po_list                             │
│  Shows up to 50 open/partially-consumed POs for the agency          │
│  Optional: action: search_po → type: po_search_results              │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ tap a PO item
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Phase 3: STATE SELECTION                                           │
│  action: select_po → type: state_selection                          │
│  Shows top 4 frequent states + "More states..." search              │
│  Optional: action: search_state / list_states                       │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ tap a state → creates Draft package in DB
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Phase 4: INVOICE UPLOAD                                            │
│  action: select_state → type: invoice_upload                        │
│  Upload → poll extraction → action: invoice_uploaded                │
│  → type: invoice_validation (9 rules table)                         │
│  User: Continue / Re-upload                                         │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ action: continue_invoice
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Phase 5: COST SUMMARY UPLOAD                                       │
│  type: cost_summary_upload                                          │
│  Upload → poll extraction → action: cost_summary_uploaded           │
│  → type: cost_summary_validation (8 rules table)                    │
│  User: Continue / Re-upload                                         │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ action: continue_after_cost_summary
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Phase 6: ACTIVITY SUMMARY UPLOAD                                   │
│  type: activity_summary_upload                                      │
│  Upload → poll extraction → action: activity_summary_uploaded       │
│  → type: activity_summary_validation (1 rule table)                 │
│  User: Continue / Re-upload                                         │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ action: continue_after_activity
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Phase 7: TEAM DETAILS ENTRY (loops per team)                       │
│  7a. team_count_input (if not auto-detected from cost summary)      │
│  7b. team_name_input → 7c. dealer_list/dealer_search                │
│  7d. date_picker_start → 7e. team_dates_confirm                     │
│  action: confirm_team → saves Team to DB → loops or moves to photos │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ all teams confirmed
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Phase 8: TEAM PHOTOS UPLOAD (loops per team)                       │
│  type: photo_upload (min 3, max 10 per team)                        │
│  Upload → action: photos_uploaded → type: photo_validation_results  │
│  User: Add more / Replace / Done                                    │
│  action: done_team_photos → loops to next team or summary           │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ all teams' photos done
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Phase 9: TEAM SUMMARY                                              │
│  type: team_summary                                                 │
│  Shows all teams with photo validation stats                        │
│  User: Continue                                                     │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ action: continue_after_teams
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Phase 10: ENQUIRY DUMP UPLOAD                                      │
│  type: enquiry_dump_upload                                          │
│  Upload → poll extraction → action: enquiry_dump_uploaded           │
│  → type: enquiry_dump_validation (9 rules table)                    │
│  User: Continue / Re-upload                                         │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ action: continue_after_enquiry
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Phase 11: FINAL REVIEW                                             │
│  type: final_review                                                 │
│  Shows all sections: PO, Invoice, Cost Summary, Activity,           │
│  Teams, Enquiry — each with key fields and pass/fail status         │
│  User: Submit / Save Draft                                          │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ action: submit_from_chat
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Phase 12: SUBMISSION SUCCESS                                       │
│  type: submit_success                                               │
│  Confirms PO number, invoice number, submission number              │
│  Background workflow orchestrator queued                            │
└─────────────────────────────────────────────────────────────────────┘
```


---

## Section-by-Section Detail

### Phase 1: Greeting

| Attribute | Value |
|---|---|
| Action | `greet` |
| Response type | `greeting` |
| Backend handler | `BuildGreeting()` |
| Frontend trigger | Auto-called when chatbot panel opens |

The greeting is the entry point. It shows a welcome message and three action cards:

| Card | Title | Action |
|---|---|---|
| 1 | Start a new submission | `create_request` |
| 2 | Show my pending claims | `view_requests` |
| 3 | Why was my claim returned | `pending_approvals` |

Cards are rendered as `WorkflowActionCard` widgets (InkWell-based). Tapping a card sends the corresponding `action` to the backend.

Additional non-submission actions from the greeting:
- `view_requests` → returns `status_cards` type with the user's pending submissions as clickable cards with deep links
- `pending_approvals` → returns `status_cards` type with rejected submissions showing reviewer name and rejection reason
- `help` → returns `help` type with example questions and action cards

### Feature Gate

The chatbot is gated by the `AgencyConversationalAI` feature flag (hot-reloaded per request). If disabled for Agency role, returns an `error` type response with "currently unavailable" message.

---

### Phase 2: PO Selection

| Attribute | Value |
|---|---|
| Action | `create_request` |
| Response type | `po_list` |
| Backend handler | `BuildPOListPrompt()` |
| Frontend notifier | `sendAction('create_request')` |

When the user taps "Start a new submission", the backend queries the agency's open POs:

```
POs WHERE AgencyId = {agencyId}
      AND IsDeleted = false
      AND POStatus IN ('Open', 'PartiallyConsumed', NULL)
ORDER BY PODate DESC
LIMIT 50
```

Each PO item in the response contains:

| Field | Source |
|---|---|
| `id` | `PO.Id` |
| `poNumber` | `PO.PONumber` |
| `poDate` | `PO.PODate` |
| `vendorName` | `PO.VendorName` |
| `totalAmount` | `PO.TotalAmount` |
| `remainingBalance` | `PO.RemainingBalance` |
| `poStatus` | `PO.POStatus` |

The frontend renders these as a scrollable list. The user can also search by typing in the search bar (min 3 characters), which triggers `search_po` action and returns `po_search_results` type with up to 10 matching POs.

User actions:
- Tap a PO → calls `selectPO()` on the notifier → sends `select_po` action with `payloadJson: {"poId": "..."}` 
- Type in search bar → debounced `searchPO()` call → sends `search_po` action

---

### Phase 3: State Selection

| Attribute | Value |
|---|---|
| Action | `select_po` |
| Response type | `state_selection` |
| Backend handler | `HandleSelectPO()` → `BuildStateSelectionPrompt()` |
| Frontend notifier | `selectPO(po)` |

After PO selection, the backend shows a state selection prompt. It queries the agency's most frequently used states (top 4) from previous submissions, or defaults to Maharashtra, Gujarat, Karnataka, Tamil Nadu.

The response includes:
- Up to 4 state cards (rendered as OutlinedButtons)
- A "More states..." card that triggers `list_states` action (returns all 36 states/UTs)
- A search input (min 1 character) for `search_state` action

The `selectedPO` is returned in the response so the frontend stores it in state.

User actions:
- Tap a state card → `selectState(stateName)` → sends `select_state` with `message: stateName`
- Type in search → `searchState(query)` → sends `search_state`
- Tap "More states..." → `listAllStates()` → sends `list_states`

---

### Phase 3b: Draft Submission Creation

When the user selects a state (`select_state` action), the backend creates a `DocumentPackage` in `Draft` state:

```csharp
new DocumentPackage {
    State = PackageState.Draft,
    SelectedPOId = poId,        // from payload
    ActivityState = validState,  // validated against AllIndianStates list
    AgencyId = agencyId,
    SubmittedByUserId = userId,
    CurrentStep = 4,
}
```

The `submissionId` is returned in the response and stored in `AssistantState.submissionId`. All subsequent uploads and actions reference this ID.

Response type transitions to `invoice_upload`.

---

### Phase 4: Invoice Upload & Validation

| Attribute | Value |
|---|---|
| Upload response type | `invoice_upload` |
| Validation response type | `invoice_validation` |
| Backend handler | `HandleInvoiceUploaded()` |
| Frontend notifier | `uploadInvoice(bytes, fileName)` |
| Allowed formats | PDF, JPG, PNG |

Upload flow:
1. Frontend calls `POST /api/documents/upload` with file bytes, fileName, submissionId, documentType=Invoice
2. Backend stores file in Azure Blob Storage, creates `Invoice` entity, triggers AI extraction
3. Frontend polls `GET /api/documents/{id}/extraction-status` every 3s (max 40 attempts / 120s)
4. Once `extracted`, frontend sends `invoice_uploaded` action with `message: documentId`
5. Backend loads the Invoice entity with eager-loaded PO and Package
6. Backend runs `RunInvoiceValidationRules()` (9 rules — see validation section above)
7. Results persisted to `ValidationResults` table
8. Response includes `validationRules[]`, `passedCount`, `failedCount`, `warningCount`, `fileName`

The validation table UI shows 3 columns: "What Was Checked" | "Result" (✅/❌/⚠️) | "What Was Found"

User actions after validation:
- "Continue" / "Continue with warnings" → `continueAfterValidation()` → sends `continue_invoice` → transitions to `cost_summary_upload`
- "Re-upload" → `reuploadInvoice()` → sends `reupload_invoice` → returns to `invoice_upload`

---

### Phase 5: Cost Summary Upload & Validation

| Attribute | Value |
|---|---|
| Upload response type | `cost_summary_upload` |
| Validation response type | `cost_summary_validation` |
| Backend handler | `HandleCostSummaryUploaded()` |
| Frontend notifier | `uploadCostSummary(bytes, fileName)` |
| Allowed formats | PDF, JPG, PNG, XLS, XLSX |

Same upload-poll-validate pattern as Invoice. Key differences:
- Backend has a server-side extraction wait loop (poll every 2s, up to 30 attempts / 60s) if `ExtractedDataJson` is still null
- Fetches the latest Invoice on the same package for the `CS_TOTAL_VS_INVOICE` cross-check
- Runs `RunCostSummaryValidationRules()` (8 rules — see validation section above)
- Response includes `costSummaryDocumentId` in `payloadJson` for downstream use

User actions after validation:
- "Continue" → sends `continue_after_cost_summary` → transitions to `activity_summary_upload`
- "Re-upload" → sends `reupload_cost_summary` → returns to `cost_summary_upload`

The `costSummaryDocumentId` is propagated through the payload chain so the Activity Summary validation can look up the exact cost summary for day-count comparison.

---

### Phase 6: Activity Summary Upload & Validation

| Attribute | Value |
|---|---|
| Upload response type | `activity_summary_upload` |
| Validation response type | `activity_summary_validation` |
| Backend handler | `HandleActivitySummaryUploaded()` |
| Frontend notifier | `uploadActivitySummary(bytes, fileName)` |
| Allowed formats | PDF, JPG, PNG, XLS, XLSX |

Same upload-poll-validate pattern. Key differences:
- Looks up cost summary days using `costSummaryDocumentId` from payload (fallback: latest cost summary for the package)
- Runs `RunActivitySummaryValidationRules()` (1 rule — days match)
- Response includes both `submissionId` and `costSummaryDocumentId` in `payloadJson`

User actions after validation:
- "Continue" → sends `continue_after_activity` → transitions to team details entry
- "Re-upload" → sends `reupload_activity_summary` → returns to `activity_summary_upload`

---

### Phase 7: Team Details Entry

This is a multi-step sub-flow that loops once per team. The number of teams is auto-detected from the Cost Summary's `NumberOfTeams` field. If not available, the user is asked to enter it manually.

#### 7a. Team Count Input (conditional)

| Attribute | Value |
|---|---|
| Response type | `team_count_input` |
| Backend handler | `HandleContinueAfterActivity()` |
| Shown when | Cost Summary `NumberOfTeams` is null or ≤ 0 |

If the team count can be read from the cost summary (DB column or `ExtractedDataJson.numberOfTeams`), this step is skipped and the flow goes directly to team name input.

User action: type a number → sends `submit_team_count` with `message: "2"`

#### 7b. Team Name Input

| Attribute | Value |
|---|---|
| Response type | `team_name_input` |
| Backend handler | `HandleSubmitTeamCount()` or `HandleContinueAfterActivity()` |

Shows "Please enter Team {N} name:" with a text input field.

The `teamContext` field in the response carries `currentTeam` and `totalTeams` for the UI to show progress (e.g., "Team 1 of 3").

User action: type team name → sends `submit_team_name` with `message: "T1"`

#### 7c. Dealer Selection

| Attribute | Value |
|---|---|
| Response type | `dealer_list` or `dealer_search` |
| Backend handler | `HandleSubmitTeamName()` |

After entering the team name, the backend loads all active dealers filtered by the submission's `ActivityState`:

```
Dealers WHERE IsActive = true AND IsDeleted = false AND State = {activityState}
ORDER BY DealerName
```

If dealers are found → returns `dealer_list` type with a scrollable list of dealers (each showing `dealerName`, `dealerCode`, `city`, `state`).

If no dealers found → returns `dealer_search` type with a search input (min 2 characters).

Each dealer item in the response:

| Field | Source |
|---|---|
| `dealerCode` | `Dealer.DealerCode` |
| `dealerName` | `Dealer.DealerName` |
| `city` | `Dealer.City` |
| `state` | `Dealer.State` |

User action: tap a dealer → sends `select_dealer` with dealer info in `payloadJson`

#### 7d. Date Picker

| Attribute | Value |
|---|---|
| Response type | `date_picker_start` |
| Backend handler | `HandleSelectDealer()` |

Shows the selected dealer name and city, and prompts for start and end dates.

The frontend opens native date pickers. Dates are sent via `submit_team_dates` action with `startDate` and `endDate` in `payloadJson`.

Validation:
- Both dates must be parseable
- End date must not be before start date
- Working days are auto-calculated (weekdays between start and end, inclusive)

#### 7e. Team Dates Confirmation

| Attribute | Value |
|---|---|
| Response type | `team_dates_confirm` |
| Backend handler | `HandleSubmitTeamDates()` |

Shows: "Start: {date} | End: {date} | Working days: {N}"

User action: tap "Confirm ✓" → sends `confirm_team`

#### 7f. Team Confirmation & DB Persistence

| Backend handler | `HandleConfirmTeam()` |
|---|---|

On confirmation, the backend creates a `Teams` entity:

```csharp
new Teams {
    PackageId = submissionId,
    CampaignName = teamName,
    TeamCode = dealerCode,
    TeamNumber = currentTeam,
    StartDate = startDate,
    EndDate = endDate,
    WorkingDays = workingDays,
    DealershipName = dealerName,
    DealershipAddress = city,
    State = state,
    VersionNumber = 1,
}
```

If `currentTeam < totalTeams` → loops back to `team_name_input` for the next team.
If all teams done → transitions to Phase 8 (photo upload) for Team 1.

---

### Phase 8: Team Photos Upload

| Attribute | Value |
|---|---|
| Response type | `photo_upload` |
| Validation response type | `photo_validation_results` |
| Backend handler | `HandlePhotosUploaded()` |
| Frontend notifier | `uploadTeamPhotos(bytesList, fileNames, payload)` |

This phase loops per team. For each team:

1. Backend shows "Upload photo proofs for {teamName} (Team {N} of {total}). Minimum 3 photos, maximum 10 photos."
2. Frontend uploads multiple photos via `POST /api/documents/upload` (one per photo)
3. Each photo is stored as a `TeamPhotos` entity linked to the team
4. After upload, frontend sends `photos_uploaded` with comma-separated photo IDs
5. Backend runs `RunPhotoValidationRules()` per photo (4 rules each — see validation section)
6. Results persisted per photo to `ValidationResults` table
7. Response includes `photoResults[]` — each with `photoId`, `displayOrder`, `fileName`, `rules[]`, `allPassed`

Photo constraints:
- Minimum 3 photos per team (enforced on `done_team_photos`)
- Maximum 10 photos per team (enforced before upload)
- `DisplayOrder` assigned sequentially

User actions:
- "Add more photos" → sends `add_more_photos` → returns to `photo_upload`
- "Replace photo" → sends `replace_photo` with photo ID → replaces specific photo
- "Done Team {N}" → sends `done_team_photos`
  - If < 3 photos → error message, stays on photo upload
  - If `currentPhotoTeam < totalTeams` → moves to next team's photo upload
  - If all teams done → transitions to Phase 9 (team summary)

---

### Phase 9: Team Summary

| Attribute | Value |
|---|---|
| Response type | `team_summary` |
| Backend handler | `BuildFinalTeamSummary()` |

Shows a summary card for each team with aggregated photo validation stats:

| Field | Description |
|---|---|
| `teamNumber` | Sequential team number |
| `teamName` | Campaign/team name |
| `dealerName` | Assigned dealer |
| `city` | Dealer city |
| `state` | Dealer state |
| `startDate` | Activity start date (dd-MMM-yyyy) |
| `endDate` | Activity end date (dd-MMM-yyyy) |
| `workingDays` | Calculated working days |
| `photoCount` | Total photos uploaded |
| `photosPassed` | Photos where all 4 rules passed |
| `photosWithDate` | Photos with date detected |
| `photosWithGps` | Photos with GPS coordinates |
| `photosWithBlueTshirt` | Photos with blue t-shirt detected |
| `photosWithVehicle` | Photos with 3-wheeler detected |
| `uniquePhotoDays` | Distinct dates across all photos (from EXIF/overlay) |
| `activitySummaryDays` | Working days from Activity Summary (for comparison) |
| `failedPhotoIds` | IDs of photos that failed validation |

User action: "Continue →" → sends `continue_after_teams` → transitions to Phase 10

---

### Phase 10: Enquiry Dump Upload & Validation

| Attribute | Value |
|---|---|
| Upload response type | `enquiry_dump_upload` |
| Validation response type | `enquiry_dump_validation` |
| Backend handler | `HandleEnquiryDumpUploaded()` |
| Frontend notifier | `uploadEnquiryDump(bytes, fileName)` |
| Allowed formats | XLSX, CSV, PDF |

Same upload-poll-validate pattern. Key differences:
- Backend has server-side extraction wait loop (2s × 30 attempts = 60s)
- Parses `ExtractedDataJson` as `EnquiryDumpData.Records[]`
- Runs `RunEnquiryDumpValidationRules()` (9 rules — 80% threshold per field)
- Response includes `totalRecords` and `missingPhoneCount` in addition to standard validation fields

User actions after validation:
- "Continue" → sends `continue_after_enquiry` → transitions to Phase 11 (final review)
- "Re-upload" → sends `reupload_enquiry_dump` → returns to `enquiry_dump_upload`

---

### Phase 11: Final Review

| Attribute | Value |
|---|---|
| Response type | `final_review` |
| Backend handler | `HandleFinalReview()` |

Loads the full submission with all related entities and builds a review summary. The response contains `reviewSections[]` — each section has a title, icon, pass/fail status, and key fields.

Sections included (in order):

| Section | Icon | Fields Shown |
|---|---|---|
| Purchase Order | `description` | PO Number, PO Date, Vendor, Amount |
| Invoice | `receipt_long` | Invoice No, Invoice Date, Amount, GST No |
| Cost Summary | `table_chart` | State, No. of Teams, No. of Days, Total Cost |
| Activity Summary | `event_note` | Dealer, Total Days, Working Days |
| Teams | `groups` | Per-team: "{name} \| {dealer} \| {startDate} – {endDate}" |
| Enquiry Dump | `people_alt` | Total Records, Missing Phone count |

Each section's `passed` field is determined by looking up the `ValidationResults` table for the corresponding document ID.

The `FinalReviewSection` structure:

```json
{
  "title": "Invoice",
  "icon": "receipt_long",
  "passed": true,
  "fields": [
    { "label": "Invoice No", "value": "E-INV-145" },
    { "label": "Amount", "value": "₹50,000.00" }
  ]
}
```

User actions:
- "Submit" → sends `submit_from_chat` → transitions to Phase 12
- "Save Draft" → sends `save_draft_from_chat` → returns `draft_saved` type

---

### Phase 12: Submission

| Attribute | Value |
|---|---|
| Response type | `submit_success` |
| Backend handler | `HandleSubmitFromChat()` |

The submit handler performs these steps:

1. Validates the authenticated user owns the package
2. Validates package is in `Draft` or `Uploaded` state
3. Validates all required documents are present:
   - PO selected (`SelectedPOId` is set)
   - At least one Invoice
   - Cost Summary
   - Activity Summary
   - Enquiry Document
   - At least one team with ≥ 3 photos
4. Generates a submission number via `ISubmissionNumberService` (format: `CIQ-YYYY-XXXXX`)
5. Assigns a Circle Head via `ICircleHeadAssignmentService` based on `ActivityState`
6. Updates package: `CurrentStep = 10`, `State = Uploaded`
7. Queues background workflow via `IBackgroundWorkflowQueue`
8. Returns success message with PO number and invoice number

Success response:
```json
{
  "type": "submit_success",
  "message": "Your submission with PO - 8110011755 and Invoice - E-INV-145 has been submitted.",
  "submissionId": "..."
}
```

After submission, the background workflow orchestrator processes the package through the state machine: `Uploaded → Extracting → Validating → Validated → Scoring → Recommending → PendingApproval`.

---

## Non-Submission Actions

Beyond the submission flow, the chatbot handles these additional actions:

| Action | Response Type | Description |
|---|---|---|
| `view_requests` | `status_cards` | Shows the user's pending/under-review submissions as cards with deep links to detail pages |
| `pending_approvals` | `status_cards` | Shows rejected submissions with reviewer name and rejection reason |
| `message` | `text` or `status_cards` | Free-text natural language queries. Status-check queries (detected by keyword or LLM classifier) return status cards. Other queries are forwarded to `IChatService` for GPT-4 response generation |
| `help` | `help` | Shows example questions and action cards |
| `save_draft_from_chat` | `draft_saved` | Saves current progress without submitting |

### Status Cards

Each status card contains:

| Field | Source |
|---|---|
| `fapId` | `FAP-{first 8 chars of package ID}` |
| `fullId` | Full package GUID |
| `poNumber` | From `POs` table via `SelectedPOId` |
| `invoiceNumber` | From latest Invoice on the package |
| `status` | `PackageState.ToString()` with display-friendly mapping |
| `amount` | Invoice `TotalAmount` formatted as `₹{amount:N2}` |
| `submittedDate` | `CreatedAt` formatted as `dd MMM yyyy` |
| `deepLink` | `/submissions/{id}` for navigation |
| `reviewerName` | From `RequestApprovalHistory` (rejection entries only) |
| `rejectionReason` | From `RequestApprovalHistory.Comments` (rejection entries only) |

---

## Response Types Reference

Complete list of all `type` values returned by the assistant endpoint:

| Type | Phase | Description |
|---|---|---|
| `greeting` | 1 | Welcome message with action cards |
| `po_list` | 2 | List of agency's open POs |
| `po_search` | 2 | PO search prompt (empty state) |
| `po_search_results` | 2 | PO search results |
| `state_selection` | 3 | State selection with frequent states and search |
| `state_search_results` | 3 | Filtered state list from search |
| `invoice_upload` | 4 | Invoice upload prompt with allowed formats |
| `invoice_validation` | 4 | Invoice validation results (9 rules) |
| `cost_summary_upload` | 5 | Cost summary upload prompt |
| `cost_summary_validation` | 5 | Cost summary validation results (8 rules) |
| `activity_summary_upload` | 6 | Activity summary upload prompt |
| `activity_summary_validation` | 6 | Activity summary validation results (1 rule) |
| `team_count_input` | 7 | Manual team count entry |
| `team_name_input` | 7 | Team name text input |
| `dealer_list` | 7 | Selectable dealer list (filtered by state) |
| `dealer_search` | 7 | Dealer search input (fallback when no dealers found) |
| `dealer_search_results` | 7 | Dealer search results |
| `date_picker_start` | 7 | Date picker prompt for activity period |
| `team_dates_confirm` | 7 | Date confirmation with working days |
| `photo_upload` | 8 | Photo upload prompt (per team) |
| `photo_validation_results` | 8 | Photo validation results (4 rules per photo) |
| `team_summary` | 9 | All-teams summary with photo stats |
| `enquiry_dump_upload` | 10 | Enquiry dump upload prompt |
| `enquiry_dump_validation` | 10 | Enquiry dump validation results (9 rules) |
| `final_review` | 11 | Full submission review with all sections |
| `submit_success` | 12 | Submission confirmed |
| `draft_saved` | — | Draft saved confirmation |
| `status_cards` | — | Submission status cards (view/rejected claims) |
| `help` | — | Help cards with example questions |
| `text` | — | Free-text GPT-4 response |
| `error` | — | Error message |

---

## AssistantRequest DTO

```json
{
  "userId": "string?",
  "action": "string?",
  "message": "string?",
  "payloadJson": "string?"
}
```

| Field | Usage |
|---|---|
| `action` | Determines which handler runs (see action switch in controller) |
| `message` | Free text: search queries, document IDs, team names, team counts, state names |
| `payloadJson` | JSON string carrying multi-step context: submissionId, poId, team details, dealer info, dates, costSummaryDocumentId |

## AssistantResponse DTO

| Field | Type | Used By |
|---|---|---|
| `type` | `string` | All responses — determines which widget renders |
| `message` | `string` | All responses — bot message text |
| `cards` | `WorkflowCard[]?` | greeting, state_selection, help, upload prompts |
| `poItems` | `POItem[]?` | po_list, po_search_results |
| `selectedPO` | `POItem?` | select_po response — stored in frontend state |
| `allowedFormats` | `string[]?` | Upload prompts (invoice, cost summary, activity, enquiry) |
| `states` | `string[]?` | state_search_results, list_states |
| `inputHint` | `string?` | Search/input prompts — placeholder text |
| `minSearchLength` | `int?` | Minimum characters before search triggers |
| `submissionId` | `Guid?` | Created at state selection, propagated through all steps |
| `validationRules` | `ValidationRuleResult[]?` | All validation responses |
| `passedCount` | `int?` | Validation responses |
| `failedCount` | `int?` | Validation responses |
| `warningCount` | `int?` | Validation responses |
| `dealers` | `DealerItem[]?` | dealer_list, dealer_search_results |
| `teamContext` | `TeamContextDto?` | Team-related steps — carries currentTeam, totalTeams |
| `payloadJson` | `string?` | Multi-step context propagation |
| `photoResults` | `PhotoValidationResult[]?` | photo_validation_results |
| `teamSummaries` | `TeamSummaryItem[]?` | team_summary |
| `totalRecords` | `int?` | enquiry_dump_validation |
| `missingPhoneCount` | `int?` | enquiry_dump_validation |
| `reviewSections` | `FinalReviewSection[]?` | final_review |
| `fileName` | `string?` | Validation responses — original uploaded filename |
| `statusCards` | `StatusCard[]?` | status_cards (view/rejected claims) |
