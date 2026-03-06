# Multi-Level Approval Workflow - Implementation Status

## ✅ Completed Backend Changes

### 1. Domain Layer Updates
- ✅ Updated `PackageState` enum with new states for multi-level approval
- ✅ Updated `DocumentPackage` entity with ASM and HQ approval tracking fields
- ✅ Added navigation properties for ASM and HQ reviewers

### 2. API Controller Updates
- ✅ Created 4 new endpoints for multi-level approval:
  - `PATCH /api/submissions/{id}/asm-approve` - ASM approves
  - `PATCH /api/submissions/{id}/asm-reject` - ASM rejects
  - `PATCH /api/submissions/{id}/hq-approve` - HQ final approval
  - `PATCH /api/submissions/{id}/hq-reject` - HQ rejects
- ✅ Updated `GetSubmission` to return approval tracking fields
- ✅ Added `ApproveSubmissionRequest` DTO
- ✅ Fixed ambiguous reference errors

### 3. Workflow Orchestrator Updates
- ✅ Changed final state to `PendingASMApproval`
- ✅ Updated idempotency check for new states

## ⏳ Pending Tasks

### Backend
1. **Stop running API process** (process ID 38308 is locking files)
2. **Create database migration** for new fields
3. **Apply migration** to database
4. **Restart API** with new code

### Frontend
1. **Create HQ pages** (copy from ASM):
   - `hq_review_page.dart` - List of submissions pending HQ approval
   - `hq_review_detail_page.dart` - Detailed view with approve/reject

2. **Update ASM pages**:
   - Filter for `PendingASMApproval` state
   - Use new endpoints (`/asm-approve`, `/asm-reject`)
   - Show `RejectedByHQ` packages that came back from HQ

3. **Update Agency Dashboard**:
   - Show rejection notes from ASM/HQ
   - Update status labels:
     - `PendingASMApproval` → "Pending ASM Approval"
     - `PendingHQApproval` → "Pending HQ Approval"  
     - `RejectedByASM` → "Rejected by ASM"
     - `RejectedByHQ` → "Rejected by HQ"
     - `Approved` → "Approved"

4. **Add rejection comments display**:
   - Show `asmReviewNotes` if rejected by ASM
   - Show `hqReviewNotes` if rejected by HQ
   - Display in both list and detail views

## Approval Flow Summary

```
Agency Upload
    ↓
AI Processing
    ↓
PendingASMApproval ←─────────┐
    ↓ (ASM Approves)          │
PendingHQApproval             │
    ↓ (HQ Approves)           │
Approved (Final)              │
                              │
ASM Rejects → RejectedByASM   │
(Goes back to Agency)         │
                              │
HQ Rejects → RejectedByHQ ────┘
(Goes back to ASM)
```

## Next Steps

1. **Stop API** (kill process 38308)
2. **Build solution** successfully
3. **Create migration**: `dotnet ef migrations add MultiLevelApproval`
4. **Apply migration**: `dotnet ef database update`
5. **Restart API**
6. **Test endpoints** with Postman/test page
7. **Create Flutter HQ pages**
8. **Update existing Flutter pages**
9. **End-to-end testing**

## Files Modified

### Backend
- `backend/src/BajajDocumentProcessing.Domain/Enums/PackageState.cs`
- `backend/src/BajajDocumentProcessing.Domain/Entities/DocumentPackage.cs`
- `backend/src/BajajDocumentProcessing.API/Controllers/SubmissionsController.cs`
- `backend/src/BajajDocumentProcessing.Infrastructure/Services/WorkflowOrchestrator.cs`

### Frontend (To be modified)
- `frontend/lib/features/approval/presentation/pages/asm_review_page.dart`
- `frontend/lib/features/approval/presentation/pages/asm_review_detail_page.dart`
- `frontend/lib/features/submission/presentation/pages/agency_dashboard_page.dart`
- New: `frontend/lib/features/approval/presentation/pages/hq_review_page.dart`
- New: `frontend/lib/features/approval/presentation/pages/hq_review_detail_page.dart`

## Date
March 5, 2026 - 9:00 PM
