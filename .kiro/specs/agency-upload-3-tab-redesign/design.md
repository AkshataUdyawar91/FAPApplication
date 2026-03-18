# Design Document: Agency Upload 3-Step Redesign

## Overview

This redesign consolidates the existing 7-step linear wizard in `AgencyUploadPage` into 3 steps, keeping the same wizard-style stepper with Back/Next navigation. The change is purely presentational — all state variables, API methods, file pickers, and data models remain untouched.

**Step mapping:**

| Step | `_currentStep` | Contents |
|------|---------------|----------|
| Invoice Details | 1 | PO upload, POFieldsSection, invoice list, cost summary upload |
| Teams | 2 | Activity summary upload, CampaignListSection |
| Enquiry & Additional Docs | 3 | Enquiry doc (mandatory), additional docs (optional) |

The existing `_steps` list is updated from 7 entries to 3. `_totalSteps` changes from 7 to 3. All other wizard infrastructure (`_currentStep`, `_handleNext`, `_handleBack`, `_buildProgressCard`, `_buildActionButtons`) remains in place.

---

## Architecture

Single file change: `frontend/lib/features/submission/presentation/pages/agency_upload_page.dart`. No new files, no backend changes.

```
_AgencyUploadPageState
  ├── _currentStep (1–3, unchanged mechanism)
  ├── _totalSteps = 3  (was 7)
  ├── _steps = 3 entries  (was 7)
  ├── _handleNext() — updated validation per step
  ├── _buildProgressCard() — unchanged rendering, fewer steps
  ├── _buildStepContent() — 3 cases instead of 7
  │     ├── case 1: _buildInvoiceDetailsStep()
  │     ├── case 2: _buildTeamsStep()
  │     └── case 3: _buildEnquiryStep()
  └── _buildActionButtons() — unchanged (Next on steps 1–2, Submit on step 3)
```

---

## Components and Interfaces

### Fields to change

```dart
// CHANGE
static const int _totalSteps = 3; // was 7

// CHANGE — replace 7-entry list with:
final List<Map<String, dynamic>> _steps = [
  {'number': 1, 'title': 'Invoice Details', 'icon': Icons.receipt_long},
  {'number': 2, 'title': 'Teams',           'icon': Icons.groups},
  {'number': 3, 'title': 'Enquiry & Docs',  'icon': Icons.find_in_page},
];
```

### `_handleNext` — updated validation

```dart
void _handleNext() {
  // Step 1: PO required
  if (_currentStep == 1 && _purchaseOrder == null && _existingPOFileName == null) {
    _showError('Please upload Purchase Order');
    return;
  }
  // Step 2: at least one team required
  if (_currentStep == 2 && _campaigns.isEmpty) {
    _showError('Please add at least one team');
    return;
  }
  if (_currentStep < _totalSteps) setState(() => _currentStep++);
}
```

### `_handleSubmit` — add enquiry validation

```dart
Future<void> _handleSubmit() async {
  if (_purchaseOrder == null && _existingPOFileName == null) {
    _showError('Please upload Purchase Order');
    return;
  }
  if (_enquiryDocFile == null && _existingEnquiryDocFileName == null) {
    _showError('Please upload Enquiry Document');
    return;
  }
  // ... rest unchanged
}
```

### `_buildStepContent` — 3 cases

```dart
Widget _buildStepContent(DeviceType device) {
  if (_isLoadingExisting) return _buildLoadingIndicator();
  switch (_currentStep) {
    case 1: return SingleChildScrollView(child: _buildInvoiceDetailsStep(device));
    case 2: return SingleChildScrollView(child: _buildTeamsStep(device));
    case 3: return SingleChildScrollView(child: _buildEnquiryStep(device));
    default: return const SizedBox();
  }
}
```

### `_buildInvoiceDetailsStep`

Contains in order:
1. PO upload card (existing `_buildFileUploadCard` / `_buildExistingFileCard`)
2. Extraction loading card or `POFieldsSection`
3. Invoice list section (existing inline invoice UI from old step 2)
4. Cost summary upload card

### `_buildTeamsStep`

Contains in order:
1. Activity summary upload card
2. `CampaignListSection` (existing, unchanged)

### `_buildEnquiryStep`

Contains in order:
1. Enquiry doc upload card with a **"Required"** badge
2. Additional documents section (existing `_buildAdditionalDocsStep` content, relabelled optional)

The "Required" badge is a small `Container` with `AppColors.primary` background placed next to the card title.

---

## Data Models

No changes. All existing state variables remain:
- `_purchaseOrder`, `_existingPOFileName`, `_poData`, `_poFields`
- `_invoices: List<InvoiceItemData>`
- `_campaigns: List<CampaignItemData>`
- `_costSummaryFile`, `_existingCostSummaryFileName`
- `_activitySummaryFile`, `_existingActivitySummaryFileName`
- `_enquiryDocFile`, `_existingEnquiryDocFileName`
- `_additionalDocs`, `_selectedAdditionalDocIndices`

---

## Correctness Properties

### Property 1: Step count is exactly 3

`_totalSteps == 3` and `_steps.length == 3` at all times. `_currentStep` is always in `{1, 2, 3}`.

**Validates: Requirement 1.4**

### Property 2: Next/Back navigation stays in bounds

For any `_currentStep` in `{1, 2, 3}`:
- `_handleNext` never sets `_currentStep > 3`
- `_handleBack` never sets `_currentStep < 1`

**Validates: Requirement 1.5**

---

## Error Handling

Unchanged from existing implementation, with two additions:

| Trigger | Message |
|---------|---------|
| Next on step 1, no PO | "Please upload Purchase Order" |
| Next on step 2, no teams | "Please add at least one team" |
| Submit, no PO | "Please upload Purchase Order" |
| Submit, no enquiry doc | "Please upload Enquiry Document" |

---

## Testing Strategy

| Test | Requirement |
|------|-------------|
| Progress card shows 3 steps with correct titles | 1.1, 1.4 |
| Initial step is 1 | 1.2 |
| Old 7-step titles absent from progress card | 1.4 |
| Step 1 contains PO card, POFieldsSection, invoice list, cost summary card | 2.1–2.4 |
| Extraction loading shown when `_isExtractingPO = true` on step 1 | 2.5 |
| Step 2 contains activity summary card and CampaignListSection | 3.1–3.2 |
| Step 3 contains enquiry card with "Required" badge and additional docs | 4.1–4.3 |
| Next on step 1 without PO shows error | 2.7 |
| Submit without enquiry doc shows error | 4.5 |
| Submit button appears only on step 3 | 5.1 |
| Next Step button appears on steps 1 and 2 | 1.5 |
