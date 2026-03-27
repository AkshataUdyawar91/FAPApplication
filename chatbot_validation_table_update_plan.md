# Plan: Update Validation Tables in Chatbot — COMPLETED

## Context

The chatbot (conversational submission flow) displays validation results as inline cards after each document upload. The new validation structure from the Excel spec requires updating these cards to show only the specified rows with the correct headings, order, and evidence format.

The chatbot uses two distinct validation mechanisms:
- **ValidationResultCard** (rendered by `_buildValidationCard` in `bot_message_bubble.dart`) — for Invoice, Cost Summary, Activity Summary. Rules come from `ProactiveValidationService.cs` (conversational path) and `AssistantController.cs` (non-conversational path).
- **PhotoValidationResult** (rendered as per-photo rule rows + aggregate summary in `BuildFinalTeamSummary`) — for Photos. Rules come from `AssistantController.RunPhotoValidationRules`.

---

## 1. Photo Validation Table ✅ DONE

### New Structure (from Excel)

| Sno | New Heading | Result | Evidence |
|-----|------------|--------|----------|
| 1 | Photo Count | Pass/Fail | `{n} photos uploaded` |
| 2 | Date on Photos | Pass/Fail | `{x}/{n} photos have date mentioned` |
| 3 | GPS Coordinates | Pass/Fail | `{x}/{n} photos have coordinates present` |
| 4 | No. of Days | Pass/Fail | *(cross-doc: photo count vs cost summary days)* |
| 5 | Promoter wearning Blue T-shirt | Pass/Fail | `{x}/{n} photos have promoters wear blue T-shirt` |
| 6 | Branded 3 wheeler | Pass/Fail | `{x}/{n} photos have Branded 3 wheeler` |

### Changes Made

**Backend — `AssistantController.cs`:**
- `RunPhotoValidationRules()`: Updated `Label` values: Date→Date on Photos, GPS→GPS Coordinates, Blue T-shirt→Promoter wearning Blue T-shirt, 3W Vehicle→Branded 3 wheeler

**Frontend — label maps updated in 3 files:**
- `agency_submission_detail_page.dart`: Photo rule label map updated
- `asm_review_detail_page.dart`: Photo rule label map updated
- `hq_review_detail_page.dart`: Photo rule label map updated
- `bot_message_bubble.dart`: `_ruleLabel()` static map includes photo labels

---

## 2. Invoice Validation Table ✅ DONE

### New Structure (from Excel) — 9 rules

| Sno | New Heading | Result | Evidence |
|-----|------------|--------|----------|
| 1 | Invoice Number | Pass/Fail | *(extracted value)* |
| 2 | Invoice Date | Pass/Fail | *(extracted value)* |
| 3 | Invoice amount | Pass/Fail | *(extracted value)* |
| 4 | Agency Name & Addresses | Pass/Fail | *(extracted value)* |
| 5 | Agency Code | Pass/Fail | *(extracted value)* |
| 6 | PO Number | Pass/Fail | *(extracted/matched value)* |
| 7 | GSTIN for State | Pass/Fail | *(extracted value)* |
| 8 | GST % | Pass/Fail | *(extracted value)* |
| 9 | Invoice amount limit | Pass/Fail | *(amount vs PO balance)* |

### Rules REMOVED

| Old RuleCode | Old Label | Reason |
|-------------|-----------|--------|
| `INV_HSN_SAC_PRESENT` | HSN/SAC Code | Not in new spec |
| `INV_BILLING_NAME_ADDRESS` | Billing Name & Address | Not in new spec |
| `INV_SUPPLIER_STATE` | Supplier State | Not in new spec (merged into GSTIN for State) |

### Changes Made

**Backend — `ProactiveValidationService.cs` (`ValidateInvoiceAsync`):**
- Removed 3 rules: `INV_HSN_SAC_PRESENT`, `INV_BILLING_NAME_ADDRESS`, `INV_SUPPLIER_STATE`
- Reordered remaining 9 rules to match Excel sequence
- Updated field names: Invoice Amount→Invoice amount, Vendor Code→Agency Code, GST Number→GSTIN for State, GST Percentage→GST %
- Updated Agency Name & Address message text

**Backend — `AssistantController.cs` (`RunInvoiceValidationRules`):**
- Removed same 3 rules: HSN/SAC, Billing Name & Address, Supplier State
- Reordered to 9 rules matching Excel sequence
- Updated labels: Invoice Amount→Invoice amount, Agency Name & Address→Agency Name & Addresses, Vendor Code→Agency Code, GST Number→GSTIN for State, PO Number Match→PO Number (label already was "PO Number"), Amount vs PO Balance→Invoice amount limit
- Added GST Number and GST % rules after PO Number (rules 7–8)

---

## 3. Cost Summary Validation Table ✅ DONE

### New Structure (from Excel) — 8 rules

| Sno | New Heading | Result | Evidence |
|-----|------------|--------|----------|
| 1 | State/Place of Supply | Pass/Fail | *(extracted value)* |
| 2 | Element wise Cost | Pass/Fail | *(extracted value)* |
| 3 | No of Days | Pass/Fail | *(extracted value)* |
| 4 | Element wise Quantity | Pass/Fail | *(extracted value)* |
| 5 | Total Cost | Pass/Fail | *(total cost validation)* |
| 6 | Element Cost limit as per State Rate | Pass/Fail | *(element cost vs rate card)* |
| 7 | Fixed Cost Limit as per State Rate | Pass/Fail | *(fixed cost vs rate card)* |
| 8 | Variable cost limit as per State Rate | Pass/Fail | *(variable cost vs rate card)* |

### Rules ADDED

| New RuleCode | New Label |
|-------------|-----------|
| `CS_ELEMENT_WISE_COSTS_PRESENT` | Element wise Cost |
| `CS_ELEMENT_WISE_QUANTITY_PRESENT` | Element wise Quantity |

### Rules REMOVED from AssistantController

| Old RuleCode | Old Label | Reason |
|-------------|-----------|--------|
| `CS_ACTIVATIONS_PRESENT` | No. of Activations | Not in Excel spec |
| `CS_TEAMS_PRESENT` | No. of Teams | Not in Excel spec |

### Changes Made

**Backend — `ProactiveValidationService.cs` (`ValidateCostSummaryAsync`):**
- Added 2 new rules: `CS_ELEMENT_WISE_COSTS_PRESENT`, `CS_ELEMENT_WISE_QUANTITY_PRESENT`
- Reordered all 8 rules to match Excel sequence
- Updated labels: Place of Supply→State/Place of Supply, Total Days→No of Days
- Updated messages: Total Cost, Element Cost limit as per State Rate

**Backend — `AssistantController.cs` (`RunCostSummaryValidationRules`):**
- Removed 2 rules: `CS_ACTIVATIONS_PRESENT`, `CS_TEAMS_PRESENT`
- Reordered to 8 rules matching Excel sequence
- Added `CS_ELEMENT_COST_VS_RATES` rule (was missing)
- Moved `CS_TOTAL_VS_INVOICE` before Fixed/Variable cost blocks
- Updated all labels: State/Place of Supply, Element wise Cost, No of Days, Element wise Quantity, Total Cost, Element Cost limit as per State Rate, Fixed Cost Limit as per State Rate, Variable cost limit as per State Rate

---

## 4. Activity Validation Table ✅ DONE

### New Structure (from Excel) — 1 rule

| Sno | New Heading | Result | Evidence |
|-----|------------|--------|----------|
| 1 | Days worked matches Cost Summary | Pass/Fail | *(cross-document days comparison)* |

### Rules REMOVED

| Old RuleCode | Old Label | Reason |
|-------------|-----------|--------|
| `AS_DEALER_LOCATION_PRESENT` | Dealer/Location | Not in new spec |
| `AS_DAYS_MATCH_TEAM_DETAILS` | Days Match (Team Details) | Not in new spec |

### Changes Made

**Backend — `ProactiveValidationService.cs` (`ValidateActivitySummaryAsync`):**
- Removed 2 rules: `AS_DEALER_LOCATION_PRESENT`, `AS_DAYS_MATCH_TEAM_DETAILS`
- Kept only `AS_DAYS_MATCH_COST_SUMMARY`
- Updated messages: "Days worked matches Cost Summary" / "Days worked does not match Cost Summary"

**Backend — `AssistantController.cs` (`RunActivitySummaryValidationRules`):**
- Updated label: "No. of Working Days vs Cost Summary Days" → "Days worked matches Cost Summary"

---

## 5. Frontend Chatbot Label Display ✅ DONE

### Problem Identified

The chatbot's `_buildRuleRow` in `bot_message_bubble.dart` was displaying raw `rule.ruleCode` (e.g., `CS_ELEMENT_WISE_COSTS_PRESENT`) instead of human-readable labels. The `ProactiveRuleResult` DTO had no `label` field.

### Changes Made

**Backend — `ProactiveRuleResult.cs`:**
- Added `Label` property with `[JsonPropertyName("label")]`

**Backend — `ProactiveValidationService.cs` (`CheckFieldPresence`):**
- Now sets `Label = fieldName` on all field-presence rules

**Frontend — `validation_rule_result.dart`:**
- Added `label` field to `ValidationRuleResult` entity

**Frontend — `validation_result_model.dart`:**
- Added `label` parsing from JSON and serialization in `toJson`

**Frontend — `conversation_response_model.dart`:**
- Updated `fromJson` to synthesize a `ValidationResultCardModel` from the flat `validationRules` array when the backend sends validation responses (previously `card` was always `null` for validation responses)

**Frontend — `bot_message_bubble.dart`:**
- Added `_ruleLabel()` static method with complete rule code → display label mapping for all document types (Invoice, Cost Summary, Activity, Photo)
- Updated `_buildRuleRow` to use `rule.label ?? _ruleLabel(rule.ruleCode)` for display

**Frontend — `validation_card.dart`:**
- Updated `_buildRuleRow` to prefer `rule.label` over auto-generated `_humanReadableRule`

---

## Summary of All File Changes

### Backend Files

| File | Changes |
|------|---------|
| `ProactiveValidationService.cs` | Invoice: remove 3 rules, reorder to 9, update labels. Cost Summary: add 2 rules, reorder to 8, update labels. Activity: remove 2 rules, keep 1, update messages. `CheckFieldPresence`: now sets `Label` field. |
| `AssistantController.cs` | `RunPhotoValidationRules()`: update 4 labels. `RunInvoiceValidationRules()`: remove 3 rules, reorder to 9, update labels, add GST rules. `RunCostSummaryValidationRules()`: remove 2 rules (Activations, Teams), add Element Cost vs Rates, reorder to 8, move Total Cost before Fixed/Variable, update all labels. `RunActivitySummaryValidationRules()`: update label. |
| `ProactiveRuleResult.cs` | Added `Label` property with JSON serialization |

### Frontend Files

| File | Changes |
|------|---------|
| `validation_rule_result.dart` | Added `label` field |
| `validation_result_model.dart` | Added `label` parsing and serialization |
| `conversation_response_model.dart` | Synthesize `ValidationResultCardModel` from flat `validationRules` array |
| `bot_message_bubble.dart` | Added `_ruleLabel()` static label map, updated `_buildRuleRow` to show labels |
| `validation_card.dart` | Updated to prefer `rule.label` over auto-generated label |
| `agency_submission_detail_page.dart` | Photo rule label map updated |
| `asm_review_detail_page.dart` | Photo rule label map updated |
| `hq_review_detail_page.dart` | Photo rule label map updated |

---

## Implementation Status: ✅ COMPLETE

All changes compiled successfully (backend `dotnet build` passed, all 4 projects).
