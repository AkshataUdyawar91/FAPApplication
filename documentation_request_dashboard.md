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
  - `PendingRA` — awaiting RA review
  - `RARejected` — rejected by RA
  - `Approved` — final approval given
  - `CHRejected` — rejected by Circle Head (RA can view and act on these)
  - `PendingCHReason` — sent back to CH for clarification by RA
  - `PendingRAReasonResponse` — CH responded to clarification, awaiting RA review

### Admin / HQ
- No filters — sees all submissions

### Common Filters (all roles)
- Excludes `Draft` packages
- Excludes orphan packages (no `SubmissionNumber` and state < `Extracting`)
- Ordered by `CreatedAt` descending

---

## Status Visibility Matrix

| Status ID | Status Name | Agency Sees | CH (ASM) Sees | RA Sees | Can Accept | Can Reject | Can Ra Ask Reason |
|---|---|---|---|---|---|---|---|
| 0 | `Draft` | ❌ Hidden | ❌ Hidden | ❌ Hidden | ❌ | ❌ | ❌ |
| 1 | `Uploaded` | Uploaded | Uploaded | ❌ Hidden | ❌ | ❌ | ❌ |
| 2 | `Extracting` | Extracting | Processing | ❌ Hidden | ❌ | ❌ | ❌ |
| 3 | `Validating` | Validating | Processing | ❌ Hidden | ❌ | ❌ | ❌ |
| 4 | `PendingCH` | Pending with CH | Pending | ❌ Hidden | CH ✅ | CH ✅ | ❌ |
| 5 | `CHRejected` | Rejected by CH | Rejected | CH Rejected | ❌ | RA ✅ | RA ✅ |
| 6 | `PendingRA` | Pending with RA | Pending with RA | Pending | RA ✅ | RA ✅ | ❌ |
| 7 | `RARejected` | Rejected by RA | Rejected by RA | Rejected | ❌ | ❌ | RA ✅ |
| 8 | `Approved` | Approved | Approved | Approved | ❌ | ❌ | ❌ |
| 9 | `PendingCHReason` | Pending with RA | RA Asked Reason | Asked Reason | ❌ | RA ✅ | RA ✅ |
| 10 | `PendingRAReasonResponse` | Pending with RA | Reason Sent | CH Responded | RA ✅ | RA ✅ | RA ✅ |
---

## Complete State Flow Graph

```
Agency creates request
        │
        ▼
    [Uploaded] ──→ [Extracting] ──→ [Validating] ──→ [PendingCH]
                                                          │
                                          ┌───────────────┼───────────────┐
                                          ▼               ▼               │
                                    CH Approves      CH Rejects           │
                                          │               │               │
                                          ▼               ▼               │
                                     [PendingRA]    [CHRejected]          │
                                          │               │               │
                          ┌───────────────┼───────┐       │               │
                          ▼               ▼       ▼       ▼               │
                    RA Approves    RA Rejects   RA Asks  RA Sees          │
                          │           │        Reason   CH Rejected       │
                          ▼           ▼          │       │                │
                     [Approved]  [RARejected]    │    ┌──┴──┐             │
                                      │          │    ▼     ▼             │
                                      │          │  RA     RA Asks       │
                                      ▼          │ Rejects  Reason       │
                                Agency must      │    │       │           │
                                resubmit         │    ▼       │           │
                                      │          │ [RARejected]           │
                                      ▼          │              │         │
                                 [Uploaded]      ▼              ▼         │
                                 (new version)  [PendingCHReason]  │
                                                      │                  │
                                                      ▼                  │
                                                CH Responds              │
                                                with reason              │
                                                      │                  │
                                                      ▼                  │
                                          [PendingRAReasonResponse]
                                                      │
                                          ┌───────────┼───────────┐
                                          ▼           ▼           ▼
                                    RA Approves  RA Rejects  RA Asks
                                          │           │      Reason Again
                                          ▼           ▼           │
                                     [Approved] [RARejected]      │
                                                                  ▼
                                                    [PendingCHReason]
                                                    (cycle repeats)
```

### State Transition Table

| From State | Action | By | To State | ASM Label | RA Label |
|---|---|---|---|---|---|
| `Uploaded` | Process | System | `Extracting` | — | — |
| `Extracting` | Extract complete | System | `Validating` | — | — |
| `Validating` | Validate complete | System | `PendingCH` | Pending | — |
| `PendingCH` | Approve | CH | `PendingRA` | Pending with RA | Pending |
| `PendingCH` | Reject | CH | `CHRejected` | Rejected | CH Rejected |
| `PendingRA` | Approve | RA | `Approved` | Approved | Approved |
| `PendingRA` | Reject | RA | `RARejected` | Rejected by RA | Rejected |
| `PendingRA` | Ask Reason | RA | `PendingCHReason` | RA Asked Reason | CH Clarification |
| `CHRejected` | Reject | RA | `RARejected` | Rejected by RA | Rejected |
| `CHRejected` | Ask Reason | RA | `PendingCHReason` | RA Asked Reason | CH Clarification |
| `PendingCHReason` | Respond | CH | `PendingRAReasonResponse` | Reason Sent | CH Responded |
| `PendingRAReasonResponse` | Approve | RA | `Approved` | Approved | Approved |
| `PendingRAReasonResponse` | Reject | RA | `RARejected` | Rejected by RA | Rejected |
| `PendingRAReasonResponse` | Ask Reason | RA | `PendingCHReason` | RA Asked Reason | CH Clarification |
| `RARejected` | Resubmit | Agency | `Uploaded` | — | — |
| `CHRejected` | Resubmit | Agency | `Uploaded` | — | — |

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
| `asmapproved`, `pendinghqapproval`, `pendingra` | `pending_with_ra` | Pending with RA |
| `approved` | `approved` | Approved |
| `rejected`, `rejectedbyasm`, `reuploadrequested`, `chrejected` | `rejected_by_asm` | Rejected by CH |
| `rejectedbyhq`, `rejectedbyra`, `rarejected` | `rejected_by_ra` | Rejected by RA |

### Status Badge Colors (Agency)

The Agency badge uses the raw backend state for granular display:

| Raw State | Label | Background | Text Color |
|---|---|---|---|
| `approved` | Approved | `#D1FAE5` | `#065F46` |
| `rejectedbyasm`, `chrejected` | Rejected by CH | `#FEE2E2` | `#991B1B` |
| `rejectedbyhq`, `rejectedbyra`, `rarejected` | Rejected by RA | `#FEE2E2` | `#991B1B` |
| `pendingchapproval`, `pendingwithch`, `pendingch` | Pending with CH | `#DBEAFE` | `#1E40AF` |
| `pendinghqapproval`, `pendingwithra`, `pendingra` | Pending with RA | `#DBEAFE` | `#1E40AF` |
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
| `pendinghqapproval`, `pendingwithra`, `pendingra`, `asmapproved` | `pending-with-ra` | Pending with RA |
| `approved` | `approved` | Approved |
| `rejectedbyasm`, `rejected`, `asmrejected`, `chrejected`, `rejectedbych` | `rejected` | Rejected |
| `rejectedbyhq`, `rejectedbyra`, `rarejected` | `rejected-by-ra` | Rejected by RA |
| `validationfailed`, `reuploadrequested` | `rejected` | Rejected |
| `uploaded` | `uploaded` | (not in dropdown) |
| `extracting`, `validating`, `scoring`, `recommending` | `processing` | (not in dropdown) |

### Status Badge Colors (ASM)

| Status Key | Label | Background | Text Color | Border |
|---|---|---|---|---|
| `pending` | Pending | `AppColors.pendingBackground` | `AppColors.pendingText` | `AppColors.pendingBorder` |
| `ra-asked-reason` | RA Asked Reason | `#FFF7ED` | `#C2410C` | `#FDBA74` |
| `reason-sent` | Reason Sent | `#ECFDF5` | `#065F46` | `#6EE7B7` |
| `pending-with-ra` | Pending with RA | `#FEF3C7` | `#92400E` | `#F59E0B` |
| `approved` | Approved | `AppColors.approvedBackground` | `AppColors.approvedText` | `AppColors.approvedBorder` |
| `rejected` | Rejected | `AppColors.rejectedBackground` | `AppColors.rejectedText` | `AppColors.rejectedBorder` |
| `rejected-by-ra` | Rejected by RA | `AppColors.rejectedBackground` | `AppColors.rejectedText` | `AppColors.rejectedBorder` |

### Filter Dropdown (static)

- All
- Pending
- RA Asked Reason
- Reason Sent
- Rejected
- Rejected by RA
- Pending with RA
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
- Backend returns only submissions matching RA's assigned `ActivityState` AND in `raVisibleStates`: `PendingRA`, `RARejected`, `Approved`, `CHRejected`, `PendingCHReason`, `PendingRAReasonResponse`
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
| `pendingra`, `pendinghqapproval` | `pending` | Pending |
| `pendingrareasonresponse` | `clarification-response` | CH Responded |
| `approved` | `approved` | Approved |
| `rarejected`, `rejectedbyhq`, `hqrejected`, `rejectedbyra` | `rejected` | Rejected |
| `chrejected` | `ch-rejected` | CH Rejected |
| `pendingchreason`, `pendingch`, `pendingasmapproval` | `ch-clarification` | CH Clarification |
| (anything else) | `other` | (raw state) |

### Status Badge Colors (RA)

| Status Key | Label | Background | Text Color | Border |
|---|---|---|---|---|
| `pending` | Pending | `AppColors.pendingBackground` | `AppColors.pendingText` | `AppColors.pendingBorder` |
| `approved` | Approved | `AppColors.approvedBackground` | `AppColors.approvedText` | `AppColors.approvedBorder` |
| `rejected` | Rejected | `AppColors.rejectedBackground` | `AppColors.rejectedText` | `AppColors.rejectedBorder` |
| `ch-rejected` | CH Rejected | `#FEF3C7` | `#92400E` | `#FCD34D` |
| `ch-clarification` | CH Clarification | `#FFF7ED` | `#C2410C` | `#FDBA74` |
| `clarification-response` | CH Responded | `#ECFDF5` | `#065F46` | `#6EE7B7` |

### Filter Dropdown (static)

- All
- Approved
- Pending
- Rejected
- CH Rejected
- CH Clarification
- CH Responded

### Sorting

Client-side sorting by: date, amount, PO number, invoice number, status, confidence.

### Navigation

Clicking a row navigates to `HQReviewDetailPage` with `submissionId`, `token`, `userName`, and `poNumber`.

---

## RA Actions on Submission Detail

When RA opens a submission from the dashboard, the available actions depend on the submission state:

| Submission State | Approve | Reject (to Agency) | Ask CH Clarification |
|---|---|---|---|
| `PendingRA` | ✅ | ✅ | ❌ |
| `PendingRAReasonResponse` | ✅ | ✅ | ✅ |
| `CHRejected` | ❌ | ✅ | ✅ |
| `PendingCHReason` | ❌ | ✅ | ✅ |
| `RARejected` | ❌ | ❌ | ✅ |
| `Approved` | ❌ | ❌ | ❌ |

### Action Endpoints

| Action | Endpoint | Accepted States | Result State |
|---|---|---|---|
| Approve | `PATCH /api/submissions/{id}/hq-approve` | `PendingRA`, `PendingRAReasonResponse` | `Approved` |
| Reject to Agency | `PATCH /api/submissions/{id}/hq-reject` | `PendingRA`, `CHRejected`, `PendingCHReason`, `PendingRAReasonResponse` | `RARejected` |
| Ask CH Reason | `PATCH /api/submissions/{id}/ra-send-back-to-ch` | `RARejected`, `CHRejected`, `PendingCHReason`, `PendingRAReasonResponse` | `PendingCHReason` |
| CH Respond to Clarification | `PATCH /api/submissions/{id}/asm-respond-clarification` | `PendingCHReason` | `PendingRAReasonResponse` |

### State Flow After RA Actions

```
PendingRA ──→ Approved                        (RA approves — final)
PendingRA ──→ RARejected                      (RA rejects — Agency must resubmit)
PendingRA ──→ PendingCHReason                  (RA asks CH for reason)
CHRejected ──→ RARejected                     (RA fully rejects)
CHRejected ──→ PendingCHReason                (RA asks CH to reconsider)
PendingCHReason ──→ PendingRAReasonResponse    (CH responds with reason)
PendingRAReasonResponse ──→ Approved           (RA approves after clarification)
PendingRAReasonResponse ──→ RARejected         (RA rejects after clarification)
PendingRAReasonResponse ──→ PendingCHReason    (RA asks again)
```

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
