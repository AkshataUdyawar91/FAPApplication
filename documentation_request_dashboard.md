# Request Dashboard Documentation

This document describes the three role-specific dashboard pages — what they show, how they filter data, which API serves the list, and how statuses are mapped.

---

## Overview

Each role has its own dashboard page that calls `GET /api/submissions` and renders a filterable, sortable list of submissions.

| Role | Page File | Route |
|---|---|---|
| Agency | `agency_dashboard_page.dart` | `/agency-dashboard` |
| CH (Circle Head / ASM) | `asm_review_page.dart` | `/asm-review` |
| RA (Regional Authority) | `hq_review_page.dart` | `/hq-review` |

All three pages share the same backend endpoint but receive different data based on role-scoped filtering in the controller.

---

## API Endpoint

`GET /api/submissions`

Controller: `SubmissionsController.ListSubmissions()`

### Query Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `state` | `string?` | `null` | Filter by `PackageState` enum value (e.g., `PendingRA`, `Approved`) |
| `page` | `int` | `1` | Page number (1-based) |
| `pageSize` | `int` | `20` | Items per page (max 100) |

### Response DTO: `SubmissionListResponse`

```json
{
  "total": 42,
  "page": 1,
  "pageSize": 20,
  "items": [ ...SubmissionListItemDto[] ]
}
```

### `SubmissionListItemDto` Fields

| Field | Type | Source |
|---|---|---|
| `id` | `Guid` | `DocumentPackage.Id` |
| `state` | `string` | `PackageState.ToString()` |
| `createdAt` | `DateTime` | `DocumentPackage.CreatedAt` |
| `updatedAt` | `DateTime?` | `DocumentPackage.UpdatedAt` |
| `documentCount` | `int` | Count of PO + Invoices + TeamPhotos |
| `invoiceNumber` | `string?` | First non-deleted Invoice's `InvoiceNumber` |
| `invoiceAmount` | `decimal?` | Sum of all non-deleted Invoice `TotalAmount` values |
| `poNumber` | `string?` | From PO entity or `SelectedPOId` lookup, fallback to `ExtractedDataJson` |
| `poAmount` | `decimal?` | From PO entity `TotalAmount`, fallback to `ExtractedDataJson` |
| `overallConfidence` | `decimal?` | `ConfidenceScore.OverallConfidence` |
| `submissionNumber` | `string?` | Format `CIQ-YYYY-XXXXX` |

---

## Backend Role-Based Filtering

The `ListSubmissions` endpoint applies different filters depending on the authenticated user's role:

### Agency
- Filters by `AgencyId`: only submissions belonging to the user's agency (resolved via `ResolveUserAgencyIdAsync`)
- No state restriction — sees all states except `Draft` and orphan packages

### ASM (Circle Head)
- Filters by `ActivityState`: only submissions whose `ActivityState` matches the user's assigned states (resolved via `ResolveAssignedStatesAsync` from `StateMapping` table)
- No explicit state restriction — sees all non-Draft states for their assigned regions

### RA (Regional Authority)
- Filters by `ActivityState`: only submissions whose `ActivityState` matches the user's RA-assigned states (resolved via `ResolveRAAssignedStatesAsync` from `StateMapping.RAUserId`)
- State restriction — only sees submissions in these states:
  - `PendingRA` — awaiting RA review ("Pending your Approval")
  - `RARejected` — rejected by RA ("Rejected by Finance")
  - `Approved` — final approval given
  - `CHRejected` — rejected by Circle Head ("Rejected by Circle head")
- **Note**: `PendingCHReason` and `PendingRAReasonResponse` are defined in the schema but marked as **Unused** in the Excel spec. The backend may still include them in the RA visible states list for backward compatibility, but they are not reachable in the active flow.

### Admin / HQ
- No filters — sees all submissions

### Common Filters (all roles)
- Excludes `Draft` packages
- Excludes orphan packages (no `SubmissionNumber` and state < `Extracting`)
- Ordered by `CreatedAt` descending

---

## Status Visibility Matrix

### First Submission (ReSubmit = 0)

| Status ID | Status Name | In Use | Agency Sees | CH (ASM) Sees | RA Sees | Can Accept | Can Reject | Can RA Ask Reason | Agency Approval Flow | CH Approval Flow | RA Approval Flow |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | `Draft` | Used | ❌ Hidden | ❌ Hidden | ❌ Hidden | ❌ | ❌ | ❌ | — | — | — |
| 1 | `Uploaded` | Used | Uploaded | Uploaded | ❌ Hidden | ❌ | ❌ | ❌ | — | — | — |
| 2 | `Extracting` | Used | Extracting | Processing | ❌ Hidden | ❌ | ❌ | ❌ | — | — | — |
| 3 | `Validating` | Used | Validating | Processing | ❌ Hidden | ❌ | ❌ | ❌ | — | — | — |
| 4 | `PendingCH` | Used | Pending with CH | Pending | ❌ Hidden | CH ✅ | CH ✅ | ❌ | Pending with CH | Pending | ❌ Hidden |
| 5 | `CHRejected` | Used | Rejected by Circle head | Rejected | Rejected by Circle head | ❌ | ❌ | ❌ | Rejected by Circle head | Rejected | Rejected by Circle head |
| 6 | `PendingRA` | Used | Pending Finance approval | Pending Finance approval | Pending your Approval | RA ✅ | RA ✅ | ❌ | Pending Finance approval | Pending Finance approval | Pending your Approval |
| 7 | `RARejected` | Used | Rejected by Finance | Rejected by Finance | Rejected by Finance | ❌ | ❌ | ❌ | Rejected by Finance | Rejected by Finance | Rejected by Finance |
| 8 | `Approved` | Used | Approved | Approved | Approved | ❌ | ❌ | ❌ | Approved | Approved | Approved |
| 9 | `PendingCHReason` | **Unused** | Pending with RA | RA Asked Reason | Asked Reason | ❌ | ❌ | ❌ | N/A | N/A | N/A |
| 10 | `PendingRAReasonResponse` | **Unused** | Pending with RA | Reason Sent | CH Responded | ❌ | ❌ | ❌ | N/A | N/A | N/A |

### ReSubmission (ReSubmit = 1)

When a submission is resubmitted after rejection, the same status IDs (4–8) are reused with the `ReSubmit` bit set to `1`. The visibility labels and actions are identical to the first-submission equivalents.

| Status ID | Status Name | In Use | Agency Sees | CH (ASM) Sees | RA Sees | Can Accept | Can Reject | Can RA Ask Reason | Agency Approval Flow | CH Approval Flow | RA Approval Flow |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 4 | `ReSubmitPendingCH` | Used | Re-Submit to CH | Pending Re-Submit | ❌ Hidden | CH ✅ | CH ✅ | ❌ | Pending with CH | Pending | ❌ Hidden |
| 5 | `ReSubmitCHRejected` | Used | Rejected by Circle head | Rejected | ❌ Hidden | ❌ | ❌ | ❌ | Rejected by Circle head | Rejected | Rejected by Circle head |
| 6 | `ReSubmitPendingRA` | Used | Pending Finance approval | Pending Finance approval | Pending your Approval | RA ✅ | RA ✅ | ❌ | Pending Finance approval | Pending Finance approval | Pending your Approval |
| 7 | `ReSubmitRARejected` | Used | Rejected by Finance | Rejected by Finance | Rejected by Finance | ❌ | ❌ | ❌ | Rejected by Finance | Rejected by Finance | Rejected by Finance |
| 8 | `ReSubmitApproved` | Used | Approved | Approved | Approved | ❌ | ❌ | ❌ | Approved | Approved | Approved |

**Note on ReSubmit bit**: The `ReSubmit` flag is a **new `BIT` column on the `DocumentPackages` table** (default `0`). It distinguishes first-time submissions from resubmissions at the same approval stage. The same status IDs (4–8) are reused with `ReSubmit=1`, allowing the UI to show different labels (e.g., "Re-Submit to CH" vs "Pending with CH") and track resubmission history separately. The `ReSubmit` flag is set to `1` when the Agency resubmits a `CHRejected` or `RARejected` submission, and persists through the entire resubmission approval cycle. See `documentation_submission_details.md` § "ReSubmit Bit — Status Variant Mapping" for full DB schema, EF Core property, and per-role label mapping.

**Note on Unused statuses**: Status IDs 9 (`PendingCHReason`) and 10 (`PendingRAReasonResponse`) are defined in the schema but currently unused in the active approval flow. The RA "Ask Reason" / CH clarification cycle is not active in the current FAP flow.
---

## Approval Flow (per Excel)

The approval flow defines what each role sees at each stage. Colors indicate the flow point status.

| Approval Flow Point | Agency | CH | RA | Color |
|---|---|---|---|---|
| Agency | Submitted | Submitted | Submitted | Green |
| | Re-Submitted | Re-Submitted | Re-Submitted | Blue |
| CH | Pending with CH | Pending | Pending with CH | Orange |
| | Approved by CH | Approved | Approved by CH | Green |
| | Rejected by CH | Rejected | Rejected by CH | Red |
| RA | Pending with RA | Pending with RA | Pending | Orange |
| | Approved by RA | Approved by RA | Approved | Green |
| | Rejected by RA | Rejected by RA | Rejected | Red |

---

## Complete State Flow Graph

### First Submission Flow

```
Agency creates request
        │
        ▼
    [Uploaded] ──→ [Extracting] ──→ [Validating] ──→ [PendingCH]
         (1)           (2)              (3)              (4)
                                                          │
                                          ┌───────────────┴───────────────┐
                                          ▼                               ▼
                                    CH Approves                      CH Rejects
                                          │                               │
                                          ▼                               ▼
                                     [PendingRA]                    [CHRejected]
                                         (6)                            (5)
                                          │                               │
                          ┌───────────────┴───────────────┐               │
                          ▼                               ▼               ▼
                    RA Approves                      RA Rejects     Agency must
                          │                               │         resubmit
                          ▼                               ▼               │
                     [Approved]                      [RARejected]         │
                         (8)                             (7)              │
                                                          │               │
                                                          └───────┬───────┘
                                                                  ▼
                                                          Agency Resubmits
                                                          (ReSubmit bit = 1)
                                                                  │
                                                                  ▼
                                                        [ReSubmitPendingCH]
                                                              (4, R=1)
                                                                  │
                                                    ┌─────────────┴─────────────┐
                                                    ▼                           ▼
                                              CH Approves                 CH Rejects
                                                    │                           │
                                                    ▼                           ▼
                                          [ReSubmitPendingRA]       [ReSubmitCHRejected]
                                               (6, R=1)                  (5, R=1)
                                                    │
                                    ┌───────────────┴───────────────┐
                                    ▼                               ▼
                              RA Approves                      RA Rejects
                                    │                               │
                                    ▼                               ▼
                           [ReSubmitApproved]              [ReSubmitRARejected]
                                (8, R=1)                       (7, R=1)
```

**Note**: The PendingCHReason (9) and PendingRAReasonResponse (10) states are defined but currently unused. The RA "Ask Reason" clarification cycle is not active in the current FAP flow.

### State Transition Table

#### First Submission (ReSubmit = 0)

| From State | Action | By | To State | Agency Label | CH Label | RA Label |
|---|---|---|---|---|---|---|
| `Uploaded` (1) | Process | System | `Extracting` (2) | Extracting | Processing | ❌ Hidden |
| `Extracting` (2) | Extract complete | System | `Validating` (3) | Validating | Processing | ❌ Hidden |
| `Validating` (3) | Validate complete | System | `PendingCH` (4) | Pending with CH | Pending | ❌ Hidden |
| `PendingCH` (4) | Approve | CH | `PendingRA` (6) | Pending Finance approval | Pending Finance approval | Pending your Approval |
| `PendingCH` (4) | Reject | CH | `CHRejected` (5) | Rejected by Circle head | Rejected | Rejected by Circle head |
| `PendingRA` (6) | Approve | RA | `Approved` (8) | Approved | Approved | Approved |
| `PendingRA` (6) | Reject | RA | `RARejected` (7) | Rejected by Finance | Rejected by Finance | Rejected by Finance |
| `RARejected` (7) | Resubmit | Agency | `ReSubmitPendingCH` (4, R=1) | Re-Submit to CH | Pending Re-Submit | ❌ Hidden |
| `CHRejected` (5) | Resubmit | Agency | `ReSubmitPendingCH` (4, R=1) | Re-Submit to CH | Pending Re-Submit | ❌ Hidden |

#### ReSubmission (ReSubmit = 1)

| From State | Action | By | To State | Agency Label | CH Label | RA Label |
|---|---|---|---|---|---|---|
| `ReSubmitPendingCH` (4, R=1) | Approve | CH | `ReSubmitPendingRA` (6, R=1) | Pending Finance approval | Pending Finance approval | Pending your Approval |
| `ReSubmitPendingCH` (4, R=1) | Reject | CH | `ReSubmitCHRejected` (5, R=1) | Rejected by Circle head | Rejected | ❌ Hidden |
| `ReSubmitPendingRA` (6, R=1) | Approve | RA | `ReSubmitApproved` (8, R=1) | Approved | Approved | Approved |
| `ReSubmitPendingRA` (6, R=1) | Reject | RA | `ReSubmitRARejected` (7, R=1) | Rejected by Finance | Rejected by Finance | Rejected by Finance |

---

## Agency Dashboard

File: `frontend/lib/features/submission/presentation/pages/agency_dashboard_page.dart`

### Layout

- Top bar with Bajaj branding
- Sidebar navigation (desktop) / drawer (mobile)
- Main view toggles between:
  - Chatbot view (`AssistantChatPanel`) — default on login
  - Requests table view — shown when user clicks "My Requests" or "Pending Claims"
- Floating action button for AI chat assistant

### Data Loading

- Calls `GET /api/submissions` with `page` and `pageSize=20`
- Supports server-side pagination via `PaginationBar` widget
- Stores response in `_requests` list

### Table Columns

| Column | Source Field |
|---|---|
| FAP NUMBER | `submissionNumber` (fallback: `FAP-{id first 8 chars}`) |
| PO NO. | `poNumber` |
| INVOICE NO. | `invoiceNumber` |
| INVOICE AMT | `invoiceAmount` (formatted as ₹) |
| SUBMITTED DATE | `createdAt` |
| STATUS | `state` (mapped via `_normalizeStatus` + `_buildStatusBadge`) |
| Actions | View button → navigates to `agency_submission_detail_page` |

### Status Normalization (Agency)

| Backend State(s) | Normalized Key | Dropdown Label |
|---|---|---|
| `uploaded`, `draft` | `uploaded` | Submitted |
| `extracting`, `validating`, `validated`, `scoring`, `recommending` | `extracting` | Extracting |
| `pendingapproval`, `pendingchapproval`, `pendingch` | `pending_with_asm` | Pending with CH |
| `asmapproved`, `pendinghqapproval`, `pendingra` | `pending_with_ra` | Pending Finance approval |
| `approved` | `approved` | Approved |
| `rejected`, `rejectedbyasm`, `reuploadrequested`, `chrejected` | `rejected_by_asm` | Rejected by Circle head |
| `rejectedbyhq`, `rejectedbyra`, `rarejected` | `rejected_by_ra` | Rejected by Finance |

**Note on Excel label mapping**: The Excel spec uses "Rejected by Circle head" (not "Rejected by CH") and "Rejected by Finance" / "Pending Finance approval" (not "Rejected by RA" / "Pending with RA") for the Agency view. The frontend may still use the shorter aliases internally.

### Status Badge Colors (Agency)

The Agency badge uses the raw backend state for granular display. Labels follow the Excel spec terminology:

| Raw State | Label | Background | Text Color |
|---|---|---|---|
| `approved` | Approved | `#D1FAE5` | `#065F46` |
| `rejectedbyasm`, `chrejected` | Rejected by Circle head | `#FEE2E2` | `#991B1B` |
| `rejectedbyhq`, `rejectedbyra`, `rarejected` | Rejected by Finance | `#FEE2E2` | `#991B1B` |
| `pendingchapproval`, `pendingwithch`, `pendingch` | Pending with CH | `#DBEAFE` | `#1E40AF` |
| `pendinghqapproval`, `pendingwithra`, `pendingra` | Pending Finance approval | `#DBEAFE` | `#1E40AF` |
| `processingfailed` | Processing Failed | `#FEF3C7` | `#92400E` |
| `uploaded` | Uploaded | `#FEF3C7` | `#92400E` |
| `extracting` | Extracting | `#FEF3C7` | `#92400E` |
| `validating` | Validating | `#FEF3C7` | `#92400E` |

### Filter Dropdown

Dynamic — only shows statuses that exist in the current data set. Built via `_availableStatuses` getter.

### Navigation

Clicking a row navigates to `AgencySubmissionDetailPage` with `submissionId`, `token`, and `userName`.

---

## CH (Circle Head / ASM) Dashboard

File: `frontend/lib/features/approval/presentation/pages/asm_review_page.dart`

### Layout

- Top bar with Bajaj branding
- Sidebar navigation (desktop) / drawer (mobile)
- KPI cards row (quarterly FAP metrics from `/analytics/quarterly-fap`)
- Quarter/Year filter for KPI data
- Search bar + status filter dropdown + sort dropdown
- Submission list: card layout (mobile) / DataTable (desktop)
- Floating action button for AI chat

### Data Loading

- Calls `GET /api/submissions` with no explicit state filter (backend scopes by ASM's assigned states)
- Loads all submissions in one call (no pagination — full list)
- KPI data loaded separately from `GET /analytics/quarterly-fap`

### Table Columns

| Column | Source Field | Sortable |
|---|---|---|
| FAP NUMBER | `submissionNumber` | No |
| PO NO. | `poNumber` | Yes |
| INVOICE NO. | `invoiceNumber` | Yes |
| INVOICE AMT | `invoiceAmount` | Yes |
| SUBMITTED DATE | `createdAt` | Yes |
| STATUS | `state` (normalized) | Yes |
| Actions | View button → navigates to `asm_review_detail_page` | No |

### Status Normalization (ASM)

| Backend State(s) | Normalized Key | Dropdown Label |
|---|---|---|
| `pendingasmapproval`, `pendingapproval`, `pendingwithasm`, `pendingch`, `pendingchapproval` | `pending` | Pending |
| `pendingchreason` | `ra-asked-reason` | RA Asked Reason |
| `pendingrareasonresponse` | `reason-sent` | Reason Sent |
| `pendinghqapproval`, `pendingwithra`, `pendingra`, `asmapproved` | `pending-with-ra` | Pending Finance approval |
| `approved` | `approved` | Approved |
| `rejectedbyasm`, `rejected`, `asmrejected`, `chrejected`, `rejectedbych` | `rejected` | Rejected |
| `rejectedbyhq`, `rejectedbyra`, `rarejected` | `rejected-by-ra` | Rejected by Finance |
| `validationfailed`, `reuploadrequested` | `rejected` | Rejected |
| `uploaded` | `uploaded` | (not in dropdown) |
| `extracting`, `validating`, `scoring`, `recommending` | `processing` | (not in dropdown) |

**Note on Excel label mapping**: The Excel spec uses "Pending Finance approval" (not "Pending with RA") and "Rejected by Finance" (not "Rejected by RA") for the CH view. Status IDs 9 and 10 (`PendingCHReason`, `PendingRAReasonResponse`) are marked as Unused in the Excel but are still handled in the frontend normalization for backward compatibility.

### Status Badge Colors (ASM)

| Status Key | Label | Background | Text Color | Border |
|---|---|---|---|---|
| `pending` | Pending | `AppColors.pendingBackground` | `AppColors.pendingText` | `AppColors.pendingBorder` |
| `ra-asked-reason` | RA Asked Reason | `#FFF7ED` | `#C2410C` | `#FDBA74` |
| `reason-sent` | Reason Sent | `#ECFDF5` | `#065F46` | `#6EE7B7` |
| `pending-with-ra` | Pending Finance approval | `#FEF3C7` | `#92400E` | `#F59E0B` |
| `approved` | Approved | `AppColors.approvedBackground` | `AppColors.approvedText` | `AppColors.approvedBorder` |
| `rejected` | Rejected | `AppColors.rejectedBackground` | `AppColors.rejectedText` | `AppColors.rejectedBorder` |
| `rejected-by-ra` | Rejected by Finance | `AppColors.rejectedBackground` | `AppColors.rejectedText` | `AppColors.rejectedBorder` |

### Filter Dropdown (static)

- All
- Pending
- RA Asked Reason
- Reason Sent
- Rejected
- Rejected by Finance
- Pending Finance approval
- Approved

### Sorting

Client-side sorting by: date, amount, PO number, invoice number, status, confidence.

### Navigation

Clicking a row navigates to `ASMReviewDetailPage` with `submissionId`, `token`, `userName`, and `poNumber`.

---

## RA (Regional Authority) Dashboard

File: `frontend/lib/features/approval/presentation/pages/hq_review_page.dart`

### Layout

- Top bar with Bajaj branding
- Sidebar navigation (desktop) / drawer (mobile)
- KPI cards row (quarterly FAP metrics from `/analytics/quarterly-fap`)
- Quarter/Year filter for KPI data
- Search bar + status filter dropdown + sort dropdown
- Submission list: card layout (mobile) / DataTable (desktop)
- Floating action button for AI chat

### Data Loading

- Calls `GET /api/submissions` with `pageSize=100` (no explicit state filter — backend enforces RA scoping)
- Backend returns only submissions matching RA's assigned `ActivityState` AND in `raVisibleStates`: `PendingRA`, `RARejected`, `Approved`, `CHRejected`
- **Note**: `PendingCHReason` and `PendingRAReasonResponse` may still be in the backend's `raVisibleStates` list for backward compatibility, but these states are marked as **Unused** in the Excel spec and are not reachable in the active flow.
- KPI data loaded separately from `GET /analytics/quarterly-fap`
- Client-side quarter/year filtering via `_matchesQuarterYear()`

### Table Columns

| Column | Source Field | Sortable |
|---|---|---|
| FAP NUMBER | `submissionNumber` | No |
| PO NO. | `poNumber` | Yes |
| PO AMT | `poAmount` | Yes |
| INVOICE NO. | `invoiceNumber` | Yes |
| INVOICE AMT | `invoiceAmount` | Yes |
| SUBMITTED DATE | `createdAt` | Yes |
| AI SCORE | `overallConfidence` (formatted as percentage) | Yes |
| STATUS | `state` (normalized) | Yes |
| Actions | View button → navigates to `hq_review_detail_page` | No |

### Status Normalization (RA)

| Backend State(s) | Normalized Key | Dropdown Label |
|---|---|---|
| `pendingra`, `pendinghqapproval` | `pending` | Pending your Approval |
| `pendingrareasonresponse` | `clarification-response` | CH Responded |
| `approved` | `approved` | Approved |
| `rarejected`, `rejectedbyhq`, `hqrejected`, `rejectedbyra` | `rejected` | Rejected by Finance |
| `chrejected` | `ch-rejected` | Rejected by Circle head |
| `pendingchreason`, `pendingch`, `pendingasmapproval` | `ch-clarification` | CH Clarification |
| (anything else) | `other` | (raw state) |

**Note on Excel label mapping**: The Excel spec uses "Pending your Approval" (not "Pending") and "Rejected by Finance" (not "Rejected") for the RA view. "Rejected by Circle head" is the RA-visible label for CH rejections.

### Status Badge Colors (RA)

| Status Key | Label | Background | Text Color | Border |
|---|---|---|---|---|
| `pending` | Pending your Approval | `AppColors.pendingBackground` | `AppColors.pendingText` | `AppColors.pendingBorder` |
| `approved` | Approved | `AppColors.approvedBackground` | `AppColors.approvedText` | `AppColors.approvedBorder` |
| `rejected` | Rejected by Finance | `AppColors.rejectedBackground` | `AppColors.rejectedText` | `AppColors.rejectedBorder` |
| `ch-rejected` | Rejected by Circle head | `#FEF3C7` | `#92400E` | `#FCD34D` |
| `ch-clarification` | CH Clarification | `#FFF7ED` | `#C2410C` | `#FDBA74` |
| `clarification-response` | CH Responded | `#ECFDF5` | `#065F46` | `#6EE7B7` |

### Filter Dropdown (static)

- All
- Approved
- Pending your Approval
- Rejected by Finance
- Rejected by Circle head
- CH Clarification
- CH Responded

### Sorting

Client-side sorting by: date, amount, PO number, invoice number, status, confidence.

### Navigation

Clicking a row navigates to `HQReviewDetailPage` with `submissionId`, `token`, `userName`, and `poNumber`.

---

## RA Actions on Submission Detail

When RA opens a submission from the dashboard, the available actions depend on the submission state.

**Per the Excel spec**: The "Can RA Ask Reason" action is ❌ (not available) for all active statuses. Status IDs 9 (`PendingCHReason`) and 10 (`PendingRAReasonResponse`) are marked as **Unused**. This means the RA clarification cycle (Ask CH Reason → CH Responds → RA reviews) is not active in the current FAP flow.

| Submission State | Approve | Reject (to Agency) | Ask CH Clarification |
|---|---|---|---|
| `PendingRA` | RA ✅ | RA ✅ | ❌ (unused) |
| `CHRejected` | ❌ | ❌ | ❌ (unused) |
| `RARejected` | ❌ | ❌ | ❌ (unused) |
| `Approved` | ❌ | ❌ | ❌ |

**Note**: The frontend may still have code paths for `PendingCHReason`, `PendingRAReasonResponse`, and the "Ask Reason" action for backward compatibility, but these states are not reachable in the current active flow per the Excel spec.

### Action Endpoints

| Action | Endpoint | Accepted States | Result State |
|---|---|---|---|
| Approve | `PATCH /api/submissions/{id}/hq-approve` | `PendingRA` | `Approved` |
| Reject to Agency | `PATCH /api/submissions/{id}/hq-reject` | `PendingRA` | `RARejected` |
| ~~Ask CH Reason~~ | ~~`PATCH /api/submissions/{id}/ra-send-back-to-ch`~~ | ~~Various~~ | ~~`PendingCHReason`~~ (Unused) |
| ~~CH Respond to Clarification~~ | ~~`PATCH /api/submissions/{id}/asm-respond-clarification`~~ | ~~`PendingCHReason`~~ | ~~`PendingRAReasonResponse`~~ (Unused) |

### State Flow After RA Actions

```
PendingRA ──→ Approved                        (RA approves — final)
PendingRA ──→ RARejected                      (RA rejects — Agency must resubmit)
```

The PendingCHReason/PendingRAReasonResponse clarification cycle is defined in the schema but not active per the Excel spec.

---

## KPI Cards (ASM and RA Dashboards)

Both ASM and RA dashboards show quarterly KPI cards at the top, loaded from `GET /analytics/quarterly-fap`.

Query parameters: `quarter` (e.g., `Q1`), `year` (e.g., `2026`)

Response model: `QuarterlyFapKpiModel`

The KPI cards display metrics like total submissions, approval rate, average processing time, etc. for the selected quarter/year.

---

## Shared UI Patterns

### Card Layout (Mobile)

On mobile, all three dashboards render submissions as cards with:
- Submission number / FAP number as title
- Key fields (PO number, invoice amount, date)
- Status badge
- Tap to navigate to detail page

### DataTable Layout (Desktop/Tablet)

On desktop, all three dashboards use `DataTable` with sortable columns, search filtering, and status dropdown filtering.

### Search

All dashboards support client-side text search across:
- Submission ID
- Invoice number
- PO number (ASM and RA)
- Submission number

### Responsive Breakpoints

- Mobile: < 600px (card layout, drawer navigation)
- Desktop: ≥ 600px (DataTable, sidebar navigation)
