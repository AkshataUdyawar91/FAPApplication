# Complete Approval/Rejection Flow Analysis

## Date: March 6, 2026

## 📊 Flow Implementation Status

### ✅ FULLY IMPLEMENTED FLOWS

#### 1. **Happy Path: Full Approval Flow** ✅
```
Agency Upload → AI Processing → ASM Approve → HQ Approve → FINAL APPROVED
```

**Status**: 100% Complete
- ✅ Agency uploads documents via upload page
- ✅ AI processes automatically (Extracting → Validating → Scoring)
- ✅ Moves to `PendingASMApproval`
- ✅ ASM reviews and approves → moves to `PendingHQApproval`
- ✅ HQ reviews and approves → moves to `Approved` (FINAL)

**Backend Endpoints**:
- ✅ `POST /api/documents/upload` - Agency uploads
- ✅ `POST /api/submissions/{id}/process-now` - Trigger workflow
- ✅ `PATCH /api/submissions/{id}/asm-approve` - ASM approves
- ✅ `PATCH /api/submissions/{id}/hq-approve` - HQ final approval

**Frontend Pages**:
- ✅ Agency Upload Page - Upload documents
- ✅ ASM Review Page - Review and approve
- ✅ HQ Review Page - Final review and approve
- ✅ Agency Dashboard - See "Approved" status

---

#### 2. **ASM Rejection Flow** ✅
```
Agency Upload → AI Processing → ASM Reject → Agency Sees Rejection
```

**Status**: 100% Complete
- ✅ Agency uploads documents
- ✅ AI processes → `PendingASMApproval`
- ✅ ASM reviews and rejects with notes → moves to `RejectedByASM`
- ✅ Agency sees rejection in dashboard with ASM notes displayed

**Backend Endpoints**:
- ✅ `PATCH /api/submissions/{id}/asm-reject` - ASM rejects with reason

**Frontend Pages**:
- ✅ ASM Review Detail Page - Reject button with notes input
- ✅ Agency Dashboard - Shows "Rejected by ASM" status
- ✅ Agency Dashboard Detail Dialog - Displays ASM rejection notes in red alert box

**What Agency Sees**:
- ✅ Status badge: "Rejected by ASM" (red)
- ✅ Detail dialog shows rejection reason in red alert box
- ✅ Can see which documents were rejected and why

---

#### 3. **HQ Rejection Flow** ✅
```
Agency Upload → AI Processing → ASM Approve → HQ Reject → ASM Sees Rejection
```

**Status**: 100% Complete
- ✅ Agency uploads documents
- ✅ AI processes → `PendingASMApproval`
- ✅ ASM approves → moves to `PendingHQApproval`
- ✅ HQ reviews and rejects with notes → moves to `RejectedByHQ`
- ✅ ASM sees rejection in review page with HQ notes displayed

**Backend Endpoints**:
- ✅ `PATCH /api/submissions/{id}/hq-reject` - HQ rejects with reason

**Frontend Pages**:
- ✅ HQ Review Detail Page - Reject button with notes input
- ✅ ASM Review Page - Shows `RejectedByHQ` packages in pending list
- ✅ ASM Review Detail Page - Displays HQ rejection section with notes

**What ASM Sees**:
- ✅ Package appears in pending list (can re-review)
- ✅ Red alert box showing "Rejected by HQ"
- ✅ HQ rejection notes and timestamp
- ✅ Message: "Please review HQ feedback and resubmit if appropriate"

---

### ⚠️ PARTIALLY IMPLEMENTED / MISSING FLOWS

#### 4. **Agency Resubmission After ASM Rejection** ⚠️
```
ASM Rejects → Agency Sees Rejection → Agency Resubmits → Back to AI Processing
```

**Status**: PARTIALLY IMPLEMENTED (70%)

**What Works**:
- ✅ Agency can see rejection with notes
- ✅ Agency can view which documents were rejected
- ✅ Agency can upload new documents

**What's Missing**:
- ❌ No explicit "Resubmit" button in agency dashboard
- ❌ No way to edit/replace documents in rejected package
- ❌ No endpoint to change state from `RejectedByASM` back to `Uploaded`
- ❌ Agency must create entirely new submission

**Current Workaround**:
- Agency creates a new submission with corrected documents
- Old rejected submission remains in rejected state

**What Should Happen**:
1. Agency clicks "Resubmit" on rejected package
2. Agency can replace/add documents
3. Agency clicks "Submit for Review"
4. Package state changes from `RejectedByASM` → `Uploaded`
5. Workflow triggers automatically
6. Goes back through AI processing → ASM review

---

#### 5. **ASM Re-review After HQ Rejection** ⚠️
```
HQ Rejects → ASM Sees Rejection → ASM Re-reviews → Resubmit to HQ
```

**Status**: PARTIALLY IMPLEMENTED (60%)

**What Works**:
- ✅ ASM can see HQ rejection with notes
- ✅ ASM can view the package details
- ✅ Package appears in ASM's pending list

**What's Missing**:
- ❌ No "Resubmit to HQ" button in ASM review detail page
- ❌ No endpoint to change state from `RejectedByHQ` back to `PendingHQApproval`
- ❌ ASM cannot add additional notes when resubmitting
- ❌ No way to track resubmission history

**Current Workaround**:
- ASM can only view the rejection
- Cannot take action to resubmit to HQ
- Package stays in `RejectedByHQ` state

**What Should Happen**:
1. ASM reviews HQ rejection notes
2. ASM makes necessary corrections/adds notes
3. ASM clicks "Resubmit to HQ"
4. Package state changes from `RejectedByHQ` → `PendingHQApproval`
5. HQ sees it again in their pending list
6. Resubmission is tracked (count, history)

---

## 📋 Complete Flow Matrix

| Flow | Agency | AI | ASM | HQ | Status |
|------|--------|----|----|-----|--------|
| **Happy Path** | Upload | Process | Approve | Approve | ✅ 100% |
| **ASM Reject** | Upload | Process | Reject | - | ✅ 100% |
| **HQ Reject** | Upload | Process | Approve | Reject | ✅ 100% |
| **Agency Resubmit** | Resubmit | Process | Review | - | ⚠️ 70% |
| **ASM Resubmit to HQ** | - | - | Resubmit | Review | ⚠️ 60% |

---

## 🔧 What's Missing - Detailed Breakdown

### Missing Backend Endpoints

#### 1. Agency Resubmit Endpoint
```csharp
[HttpPatch("{id}/resubmit")]
[Authorize(Roles = "Agency")]
public async Task<IActionResult> ResubmitPackage(
    Guid id,
    CancellationToken cancellationToken)
{
    // Change state from RejectedByASM → Uploaded
    // Clear rejection notes
    // Trigger workflow
}
```

#### 2. ASM Resubmit to HQ Endpoint
```csharp
[HttpPatch("{id}/resubmit-to-hq")]
[Authorize(Roles = "ASM")]
public async Task<IActionResult> ResubmitToHQ(
    Guid id,
    [FromBody] ResubmitRequest request,
    CancellationToken cancellationToken)
{
    // Change state from RejectedByHQ → PendingHQApproval
    // Add ASM resubmission notes
    // Track resubmission count
}
```

### Missing Frontend Features

#### 1. Agency Dashboard - Resubmit Button
- Add "Resubmit" button for packages in `RejectedByASM` state
- Allow editing/replacing documents
- Trigger resubmit endpoint
- Show success message

#### 2. ASM Review Detail Page - Resubmit to HQ Button
- Add "Resubmit to HQ" button for packages in `RejectedByHQ` state
- Allow ASM to add notes explaining corrections
- Trigger resubmit-to-hq endpoint
- Show success message

#### 3. Resubmission History Tracking
- Track number of resubmissions
- Show resubmission history in detail pages
- Display previous rejection notes
- Show timeline of reviews

---

## 🎯 Current User Experience

### Agency User Experience
**Can Do**:
- ✅ Upload documents
- ✅ See submission status
- ✅ View rejection notes from ASM
- ✅ View rejection notes from HQ (if ASM rejected by HQ)

**Cannot Do**:
- ❌ Resubmit rejected packages
- ❌ Edit/replace documents in rejected packages
- ❌ See resubmission history

**Workaround**: Create new submission

### ASM User Experience
**Can Do**:
- ✅ Review pending submissions
- ✅ Approve submissions (sends to HQ)
- ✅ Reject submissions (sends back to agency)
- ✅ View HQ rejection notes

**Cannot Do**:
- ❌ Resubmit to HQ after HQ rejection
- ❌ Add notes when resubmitting
- ❌ See resubmission history

**Workaround**: None - package stuck in `RejectedByHQ`

### HQ User Experience
**Can Do**:
- ✅ Review pending submissions from ASM
- ✅ Give final approval
- ✅ Reject submissions (sends back to ASM)
- ✅ View ASM notes and AI analysis

**Cannot Do**:
- Nothing missing for HQ

---

## 📊 Implementation Priority

### High Priority (Critical for Production)
1. **Agency Resubmit Flow** - Agencies need to fix and resubmit rejected packages
2. **ASM Resubmit to HQ Flow** - ASM needs to address HQ feedback and resubmit

### Medium Priority (Nice to Have)
3. **Resubmission History** - Track how many times a package was resubmitted
4. **Document Replacement** - Allow replacing specific documents without full resubmit
5. **Notification System** - Email notifications for rejections

### Low Priority (Future Enhancement)
6. **Bulk Actions** - Approve/reject multiple submissions at once
7. **Comments/Discussion** - Allow back-and-forth discussion on packages
8. **Audit Trail** - Detailed history of all actions

---

## 🚀 Recommended Next Steps

### Step 1: Implement Agency Resubmit (Backend)
```csharp
// Add to SubmissionsController.cs
[HttpPatch("{id}/resubmit")]
[Authorize(Roles = "Agency")]
public async Task<IActionResult> ResubmitPackage(Guid id)
{
    var package = await _context.DocumentPackages.FindAsync(id);
    
    if (package.State != PackageState.RejectedByASM)
        return BadRequest("Can only resubmit rejected packages");
    
    package.State = PackageState.Uploaded;
    package.ASMReviewNotes = null;
    package.ASMReviewedAt = null;
    package.UpdatedAt = DateTime.UtcNow;
    
    await _context.SaveChangesAsync();
    
    // Trigger workflow
    await _workflowOrchestrator.ProcessPackageAsync(id);
    
    return Ok(new { message = "Package resubmitted for review" });
}
```

### Step 2: Implement Agency Resubmit (Frontend)
```dart
// Add to agency_dashboard_page.dart
if (status == 'rejected_by_asm') ...[
  ElevatedButton(
    onPressed: () => _resubmitPackage(request['id']),
    child: Text('Resubmit for Review'),
  ),
]
```

### Step 3: Implement ASM Resubmit to HQ (Backend)
```csharp
[HttpPatch("{id}/resubmit-to-hq")]
[Authorize(Roles = "ASM")]
public async Task<IActionResult> ResubmitToHQ(
    Guid id,
    [FromBody] ResubmitRequest request)
{
    var package = await _context.DocumentPackages.FindAsync(id);
    
    if (package.State != PackageState.RejectedByHQ)
        return BadRequest("Can only resubmit HQ-rejected packages");
    
    package.State = PackageState.PendingHQApproval;
    package.ASMReviewNotes += $"\n\nResubmission Notes: {request.Notes}";
    package.UpdatedAt = DateTime.UtcNow;
    
    await _context.SaveChangesAsync();
    
    return Ok(new { message = "Package resubmitted to HQ" });
}
```

### Step 4: Implement ASM Resubmit to HQ (Frontend)
```dart
// Add to asm_review_detail_page.dart
if (state == 'rejectedbyhq') ...[
  ElevatedButton(
    onPressed: () => _showResubmitDialog(),
    child: Text('Resubmit to HQ'),
  ),
]
```

---

## ✅ Summary

### What's Complete (80%)
- ✅ Full approval flow (Agency → ASM → HQ → Approved)
- ✅ ASM rejection flow with notes display
- ✅ HQ rejection flow with notes display
- ✅ All review pages and dashboards
- ✅ Status tracking and display
- ✅ Role-based access control

### What's Missing (20%)
- ❌ Agency resubmit functionality
- ❌ ASM resubmit to HQ functionality
- ❌ Resubmission history tracking
- ❌ Document replacement in rejected packages

### Impact
**Current State**: The system works for first-time submissions and rejections, but rejected packages cannot be easily resubmitted. Users must create new submissions.

**Production Ready**: 80% - Core flows work, but resubmission is a critical missing feature for real-world use.

**Recommendation**: Implement resubmit flows before production deployment.
