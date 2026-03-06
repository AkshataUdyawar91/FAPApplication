# Multi-Level Approval Workflow Implementation

## Overview
Implemented a complete multi-level approval workflow where:
- Agency submits → ASM reviews → HQ reviews → Final approval
- Rejections flow back: HQ reject → ASM, ASM reject → Agency
- All rejection comments are visible to all personas

## Backend Changes

### 1. Updated PackageState Enum
**File**: `backend/src/BajajDocumentProcessing.Domain/Enums/PackageState.cs`

**New States**:
- `PendingASMApproval` (8) - Waiting for ASM approval
- `ASMApproved` (9) - ASM approved, pending HQ (not used, goes directly to PendingHQApproval)
- `PendingHQApproval` (10) - Waiting for HQ approval
- `Approved` (11) - Final approval by HQ
- `RejectedByASM` (12) - Rejected by ASM, goes back to Agency
- `RejectedByHQ` (13) - Rejected by HQ, goes back to ASM
- `ReuploadRequested` (14) - Agency needs to reupload

**Legacy Aliases** (for backward compatibility):
- `PendingApproval` = `PendingASMApproval`
- `Rejected` = `RejectedByASM`

### 2. Updated DocumentPackage Entity
**File**: `backend/src/BajajDocumentProcessing.Domain/Entities/DocumentPackage.cs`

**New Fields**:
```csharp
// ASM Approval tracking
public Guid? ASMReviewedByUserId { get; set; }
public DateTime? ASMReviewedAt { get; set; }
public string? ASMReviewNotes { get; set; }

// HQ Approval tracking
public Guid? HQReviewedByUserId { get; set; }
public DateTime? HQReviewedAt { get; set; }
public string? HQReviewNotes { get; set; }

// Navigation properties
public User? ASMReviewedBy { get; set; }
public User? HQReviewedBy { get; set; }
```

### 3. New API Endpoints
**File**: `backend/src/BajajDocumentProcessing.API/Controllers/SubmissionsController.cs`

#### ASM Endpoints
- `PATCH /api/submissions/{id}/asm-approve` - ASM approves, moves to HQ
- `PATCH /api/submissions/{id}/asm-reject` - ASM rejects, sends back to Agency

#### HQ Endpoints
- `PATCH /api/submissions/{id}/hq-approve` - HQ final approval
- `PATCH /api/submissions/{id}/hq-reject` - HQ rejects, sends back to ASM

#### Legacy Endpoints (backward compatibility)
- `PATCH /api/submissions/{id}/approve` - Redirects to ASM approve
- `PATCH /api/submissions/{id}/reject` - Redirects to ASM reject

### 4. Updated WorkflowOrchestrator
**File**: `backend/src/BajajDocumentProcessing.Infrastructure/Services/WorkflowOrchestrator.cs`

- Changed final state from `PendingApproval` to `PendingASMApproval`
- Updated idempotency check to include all approval states

### 5. New DTOs
**File**: `backend/src/BajajDocumentProcessing.API/Controllers/SubmissionsController.cs`

```csharp
public record ApproveSubmissionRequest(string? Notes);
public record RejectSubmissionRequest(string Reason);
```

### 6. Updated GetSubmission Response
Added approval tracking fields to API response:
- `asmReviewedAt`
- `asmReviewNotes`
- `hqReviewedAt`
- `hqReviewNotes`

## Approval Flow

### Happy Path
```
Agency Upload
    ↓
AI Processing (Extract, Validate, Score, Recommend)
    ↓
PendingASMApproval
    ↓ (ASM Approves)
PendingHQApproval
    ↓ (HQ Approves)
Approved (Final)
```

### Rejection Flows

#### ASM Rejects
```
PendingASMApproval
    ↓ (ASM Rejects)
RejectedByASM
    ↓
Agency sees rejection with ASM notes
Agency can resubmit
```

#### HQ Rejects
```
PendingHQApproval
    ↓ (HQ Rejects)
RejectedByHQ
    ↓
ASM sees rejection with HQ notes
ASM can review and resubmit to HQ
```

## Frontend Changes Needed

### 1. HQ Dashboard (New)
Create pages similar to ASM:
- `frontend/lib/features/approval/presentation/pages/hq_review_page.dart`
- `frontend/lib/features/approval/presentation/pages/hq_review_detail_page.dart`

### 2. Update ASM Pages
- Show packages in `PendingASMApproval` state
- After approval, package moves to HQ (not final)
- Show `RejectedByHQ` packages that came back from HQ

### 3. Update Agency Dashboard
- Show `RejectedByASM` packages with ASM rejection notes
- Show `PendingASMApproval` as "Pending ASM Approval"
- Show `PendingHQApproval` as "Pending HQ Approval"
- Show `Approved` as "Approved"

### 4. Rejection Comments Display
All personas should see:
- ASM rejection notes (if rejected by ASM)
- HQ rejection notes (if rejected by HQ)
- Display in detail view and list view

## Database Migration Required

Run this SQL to add new columns:

```sql
ALTER TABLE DocumentPackages
ADD ASMReviewedByUserId uniqueidentifier NULL,
    ASMReviewedAt datetime2 NULL,
    ASMReviewNotes nvarchar(max) NULL,
    HQReviewedByUserId uniqueidentifier NULL,
    HQReviewedAt datetime2 NULL,
    HQReviewNotes nvarchar(max) NULL;

-- Add foreign key constraints
ALTER TABLE DocumentPackages
ADD CONSTRAINT FK_DocumentPackages_Users_ASMReviewedByUserId
    FOREIGN KEY (ASMReviewedByUserId) REFERENCES Users(Id);

ALTER TABLE DocumentPackages
ADD CONSTRAINT FK_DocumentPackages_Users_HQReviewedByUserId
    FOREIGN KEY (HQReviewedByUserId) REFERENCES Users(Id);
```

Or use EF Core migration:
```bash
cd backend/src/BajajDocumentProcessing.API
dotnet ef migrations add MultiLevelApproval
dotnet ef database update
```

## Testing Workflow

### 1. Agency Submits
```bash
POST /api/submissions
# Upload documents
POST /api/submissions/{id}/process-now
```

### 2. ASM Reviews
```bash
# Get pending submissions
GET /api/submissions?state=PendingASMApproval

# Approve
PATCH /api/submissions/{id}/asm-approve
Body: { "notes": "Looks good" }

# Or Reject
PATCH /api/submissions/{id}/asm-reject
Body: { "reason": "Missing documents" }
```

### 3. HQ Reviews
```bash
# Get pending submissions
GET /api/submissions?state=PendingHQApproval

# Approve (Final)
PATCH /api/submissions/{id}/hq-approve
Body: { "notes": "Final approval" }

# Or Reject (back to ASM)
PATCH /api/submissions/{id}/hq-reject
Body: { "reason": "Need more clarification" }
```

## Next Steps

1. ✅ Backend implementation complete
2. ⏳ Create database migration
3. ⏳ Create HQ Flutter pages (copy from ASM)
4. ⏳ Update ASM pages to use new endpoints
5. ⏳ Update Agency dashboard to show rejection notes
6. ⏳ Test complete workflow end-to-end

## Date
March 5, 2026 - 8:30 PM
