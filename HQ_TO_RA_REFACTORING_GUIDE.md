# HQ to RA Terminology Refactoring Guide

## Overview
This document outlines the comprehensive refactoring needed to replace "HQ" (Headquarters) with "RA" (Regional Administrator) throughout the application while maintaining backward compatibility.

## Status: PARTIALLY COMPLETE

### ✅ Completed Changes

1. **Backend Enum (PackageState.cs)**
   - Added `RejectedByRA = 13` as primary state
   - Kept `RejectedByHQ = 13` as legacy alias

2. **Backend Controllers**
   - Updated `SubmissionsController.cs` to use `RejectedByRA`
   - Updated state transition logic

3. **Frontend UI Labels**
   - Most user-facing labels already show "RA" or "HQ/RA"
   - Status badges display correct terminology

### 🔄 Remaining Changes Needed

#### Backend Changes

##### 1. UserRole Enum (DO NOT CHANGE)
**File**: `backend/src/BajajDocumentProcessing.Domain/Enums/UserRole.cs`
- Keep `HQ = 2` for database compatibility
- Add XML comment: `/// HQ (legacy name, represents Regional Administrator - RA)`

##### 2. Authorization Policies
**File**: `backend/src/BajajDocumentProcessing.API/Program.cs`
- ✅ DONE: Updated policy names to RAOnly, ASMOrRA

##### 3. Controller Comments
**Files**: All controllers using `[Authorize(Roles = "HQ")]`
- Update XML comments from "HQ role" to "RA role"
- Keep actual role string as "HQ" for compatibility
- Files to update:
  - `AnalyticsController.cs` - ✅ DONE
  - `SubmissionsController.cs` - ✅ PARTIAL
  - `ChatController.cs`
  - `DocumentsController.cs`

##### 4. DTO Comments
**Files**:
- `SubmissionDetailResponse.cs` - Update "HQ reviewed" to "RA reviewed"
- `SubmissionStatusResponse.cs` - Update "resubmitted to HQ" to "resubmitted to RA"
- `LoginResponse.cs` - Update "Agency, ASM, or HQ" to "Agency, ASM, or RA"
- `UserInfoResponse.cs` - Update "Agency, ASM, or HQ" to "Agency, ASM, or RA"

##### 5. Service Comments
**Files**:
- `AuthorizationGuardrailService.cs` - Update "HQ users" to "RA users"
- `ChatService.cs` - Update system prompt "ASM/HQ/all" to "ASM/RA/all"
- `AnalyticsPlugin.cs` - Update function descriptions

##### 6. Seed Data Comments
**File**: `ApplicationDbContextSeed.cs`
- Update comment from "HQ User" to "RA User"
- Keep email as `hq@bajaj.com` for compatibility

##### 7. Test Files
**Files**:
- `EntityPersistenceProperties.cs` - Update test data comments
- `RoleBasedAuthorizationProperties.cs` - Update XML comments and test descriptions
- Keep test emails as `hq@test.com` for compatibility

#### Frontend Changes

##### 1. Route Names (OPTIONAL - Low Priority)
**File**: `frontend/lib/core/router/app_router.dart`
- Consider keeping `/hq/*` routes for URL compatibility
- Or add redirects from old `/hq/*` to new `/ra/*` routes

##### 2. Widget Names (OPTIONAL - Low Priority)
**Files**:
- `hq_review_page.dart` → Consider renaming to `ra_review_page.dart`
- `hq_review_detail_page.dart` → Consider renaming to `ra_review_detail_page.dart`
- `hq_rejection_section.dart` → Consider renaming to `ra_rejection_section.dart`
- **Note**: File renames require updating all imports

##### 3. Variable Names (OPTIONAL - Low Priority)
- `hqReviewedAt` → Keep for API compatibility
- `hqReviewNotes` → Keep for API compatibility
- `HQResubmissionCount` → Keep for API compatibility

##### 4. UI Labels (MOSTLY DONE)
- ✅ Most labels already show "RA" or "HQ/RA"
- ✅ Login page shows "HQ/RA"
- ✅ Sidebar shows "HQ/RA"
- Remaining: Search for any hardcoded "HQ" strings in UI text

##### 5. Test Files
**File**: `asm_review_preservation_test.dart`
- Update test descriptions from "HQ rejection" to "RA rejection"
- Update comments and property names

## Implementation Strategy

### Phase 1: Critical User-Facing Changes (DONE)
- ✅ UI labels and display text
- ✅ Status badges
- ✅ User role display

### Phase 2: Backend Comments and Documentation (IN PROGRESS)
- Update XML comments in controllers
- Update DTO documentation
- Update service comments

### Phase 3: Test Updates (PENDING)
- Update test descriptions
- Update test comments
- Keep test data for compatibility

### Phase 4: Optional Refactoring (FUTURE)
- Consider renaming files (requires import updates)
- Consider renaming internal variables (breaking change)
- Consider route renames (requires redirects)

## Backward Compatibility Notes

### Must Keep As-Is:
1. **Database**: `UserRole.HQ = 2` enum value
2. **JWT Claims**: Role claim value "HQ"
3. **API Authorization**: `[Authorize(Roles = "HQ")]` attribute strings
4. **JSON Properties**: `hqReviewedAt`, `hqReviewNotes`, etc.
5. **Email Addresses**: `hq@bajaj.com` in seed data

### Can Change Safely:
1. **UI Display Text**: All user-facing labels
2. **Comments**: XML documentation and code comments
3. **Variable Names**: Local variables and parameters (with caution)
4. **Policy Names**: Authorization policy names (internal only)

## Testing Checklist

After making changes, verify:
- [ ] Login works for all three roles
- [ ] ASM can approve/reject submissions
- [ ] RA can approve/reject submissions
- [ ] Status labels display correctly for each role
- [ ] Rejection flows work correctly
- [ ] API authorization still works
- [ ] Existing JWT tokens still validate
- [ ] Database queries still work

## Conclusion

The most critical user-facing changes are complete. The remaining work is primarily:
1. Updating comments and documentation (non-breaking)
2. Optionally renaming files and variables (breaking, low priority)

The application is fully functional with the current state. Further refactoring should be done incrementally to avoid breaking changes.
