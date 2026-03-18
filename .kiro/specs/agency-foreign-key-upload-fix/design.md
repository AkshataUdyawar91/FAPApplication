# Agency Foreign Key Upload Fix - Bugfix Design

## Overview

This bugfix addresses a critical database constraint violation that prevents agency users from uploading documents. The root cause is that the `DocumentService.UploadDocumentAsync` method creates new `DocumentPackage` entities without populating the required `AgencyId` field, causing a foreign key constraint violation when attempting to save to the database.

The fix involves retrieving the authenticated user's `AgencyId` from the `User` table and setting it on the new `DocumentPackage` before saving. Additionally, we validate that only agency users (those with a non-null `AgencyId`) can create new document packages, returning a 403 Forbidden error for non-agency users attempting this operation.

## Glossary

- **Bug_Condition (C)**: The condition that triggers the bug - when a new DocumentPackage is created without an AgencyId value
- **Property (P)**: The desired behavior - DocumentPackage must have a valid AgencyId from the authenticated user's record
- **Preservation**: Existing document upload validation, blob storage operations, and workflows for existing packages must remain unchanged
- **UploadDocumentAsync**: The method in `DocumentService.cs` (lines 57-340) that handles document uploads and package creation
- **packageId**: Optional parameter indicating whether to use an existing package (provided) or create a new one (null/empty)
- **AgencyId**: Foreign key field on DocumentPackage and User entities linking to the Agencies table

## Bug Details

### Bug Condition

The bug manifests when an agency user uploads their first document (no existing packageId) and the system attempts to create a new DocumentPackage. The `UploadDocumentAsync` method creates the package entity but does not populate the required `AgencyId` field, causing a database foreign key constraint violation.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type UploadDocumentRequest
  OUTPUT: boolean
  
  RETURN input.packageId IS NULL OR input.packageId = Guid.Empty
         AND input.userId EXISTS IN Users table
         AND newDocumentPackageCreated = true
         AND newDocumentPackage.AgencyId IS NULL
END FUNCTION
```

### Examples

- **Example 1**: Agency user (userId: `abc-123`, AgencyId: `xyz-789`) uploads first PO document with no packageId → System creates DocumentPackage with SubmittedByUserId=`abc-123` but AgencyId=NULL → Database rejects INSERT with FK constraint error
- **Example 2**: Agency user uploads second invoice with existing packageId → System uses existing package (no new package created) → Upload succeeds (no bug)
- **Example 3**: ASM user (userId: `def-456`, AgencyId: NULL) attempts to upload document with no packageId → System should reject with 403 Forbidden (agency users only)
- **Edge Case**: Agency user's AgencyId field is NULL in database (data integrity issue) → System should reject with 403 Forbidden and log warning

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Existing package uploads (when packageId is provided) must continue to work exactly as before
- File validation (size, type, malware scanning) must remain unchanged
- Blob storage upload operations must remain unchanged
- Document extraction (immediate and background) must remain unchanged
- Photo limit validation (50 photos per package) must remain unchanged
- All document type handling (PO, Invoice, CostSummary, ActivitySummary, EnquiryDocument, TeamPhoto) must remain unchanged

**Scope:**
All inputs that involve an existing packageId should be completely unaffected by this fix. This includes:
- Subsequent document uploads to an existing package
- Document uploads by any user role (Agency, ASM, HQ) to existing packages
- All validation, extraction, and storage operations

## Hypothesized Root Cause

Based on the bug description and code analysis, the root cause is clear:

1. **Missing AgencyId Assignment**: In `DocumentService.UploadDocumentAsync` (lines 96-109), when creating a new `DocumentPackage`, the code sets `SubmittedByUserId`, `State`, `CreatedAt`, and `CreatedBy`, but does not set the `AgencyId` field.

2. **Database Schema Constraint**: The `DocumentPackages` table has a non-nullable foreign key constraint on `AgencyId` referencing the `Agencies` table. When the INSERT statement executes with `AgencyId = NULL`, SQL Server rejects it.

3. **User Record Contains AgencyId**: The `User` entity has an `AgencyId` property (nullable Guid) that stores the agency association. For agency users, this field contains a valid agency ID. The fix requires querying this field and copying it to the new package.

4. **No Authorization Check**: The current code does not verify that the user creating a new package is actually an agency user (has a non-null AgencyId). Non-agency users should not be able to create new packages.

## Correctness Properties

Property 1: Bug Condition - New Package Has Valid AgencyId

_For any_ document upload request where no packageId is provided (new package creation) and the authenticated user has a non-null AgencyId, the fixed UploadDocumentAsync method SHALL retrieve the user's AgencyId from the User table and set it on the new DocumentPackage before saving, ensuring the database INSERT succeeds.

**Validates: Requirements 2.1, 2.3**

Property 2: Authorization - Non-Agency Users Rejected

_For any_ document upload request where no packageId is provided and the authenticated user has a null AgencyId (non-agency user), the fixed UploadDocumentAsync method SHALL return a 403 Forbidden error with a clear message indicating that only agency users can create new document packages.

**Validates: Requirements 2.2**

Property 3: Preservation - Existing Package Uploads Unchanged

_For any_ document upload request where a valid packageId is provided (existing package), the fixed UploadDocumentAsync method SHALL produce exactly the same behavior as the original code, preserving all existing validation, storage, and extraction operations without modification.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4**

## Fix Implementation

### Changes Required

Assuming our root cause analysis is correct (which it is, based on the error message and code inspection):

**File**: `backend/src/BajajDocumentProcessing.Infrastructure/Services/DocumentService.cs`

**Function**: `UploadDocumentAsync`

**Specific Changes**:

1. **Query User Record**: Before creating a new DocumentPackage (in the `else` block starting at line 96), query the User table to retrieve the authenticated user's AgencyId.
   - Use `_context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId)`
   - Include null check for user not found (defensive programming)

2. **Validate AgencyId**: Check if the retrieved user's AgencyId is null.
   - If null, throw a `ForbiddenException` with message: "Only agency users can create new document packages"
   - Log a warning if this occurs (may indicate authorization bypass or data integrity issue)

3. **Set AgencyId on New Package**: Assign the retrieved AgencyId to the new DocumentPackage entity.
   - Add line: `AgencyId = user.AgencyId.Value` (safe to use .Value after null check)

4. **Update Logging**: Include AgencyId in the log statement for new package creation.
   - Change log message to include agency information for audit trail

5. **Exception Handling**: Ensure ForbiddenException is defined in Domain.Exceptions namespace.
   - If not exists, create it following the pattern of existing exceptions (NotFoundException, ValidationException)
   - Map to HTTP 403 in global exception middleware

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bug on unfixed code, then verify the fix works correctly and preserves existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bug BEFORE implementing the fix. Confirm the root cause analysis.

**Test Plan**: Write integration tests that simulate agency user document uploads without providing a packageId. Run these tests on the UNFIXED code to observe the foreign key constraint violation and confirm the root cause.

**Test Cases**:
1. **New Package Creation Test**: Agency user uploads PO document with no packageId → Expect DbUpdateException with FK constraint message (will fail on unfixed code)
2. **User Query Test**: Verify that querying User table by userId returns correct AgencyId for agency users → Should pass (confirms data availability)
3. **Non-Agency User Test**: ASM user attempts to upload document with no packageId → Currently succeeds but creates invalid package (will fail on unfixed code)
4. **Null AgencyId Test**: Agency user with NULL AgencyId in database attempts upload → Currently fails with FK constraint (will fail on unfixed code)

**Expected Counterexamples**:
- DocumentPackage INSERT fails with: "The INSERT statement conflicted with the FOREIGN KEY constraint FK_DocumentPackages_Agencies_AgencyId"
- Possible causes: AgencyId not set on new package, no validation for non-agency users

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed function produces the expected behavior.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  user := GetUser(input.userId)
  IF user.AgencyId IS NOT NULL THEN
    result := UploadDocumentAsync_fixed(input)
    newPackage := GetDocumentPackage(result.PackageId)
    ASSERT newPackage.AgencyId = user.AgencyId
    ASSERT newPackage.SubmittedByUserId = user.Id
    ASSERT result.DocumentId IS NOT NULL
  ELSE
    ASSERT_THROWS ForbiddenException WITH message "Only agency users can create new document packages"
  END IF
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed function produces the same result as the original function.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  // input.packageId is provided (existing package)
  result_original := UploadDocumentAsync_original(input)
  result_fixed := UploadDocumentAsync_fixed(input)
  
  ASSERT result_original.DocumentId = result_fixed.DocumentId
  ASSERT result_original.PackageId = result_fixed.PackageId
  ASSERT result_original.BlobUrl = result_fixed.BlobUrl
  ASSERT result_original.ExtractedDataJson = result_fixed.ExtractedDataJson
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many test cases automatically across the input domain
- It catches edge cases that manual unit tests might miss
- It provides strong guarantees that behavior is unchanged for all existing package uploads

**Test Plan**: Observe behavior on UNFIXED code first for existing package uploads, then write property-based tests capturing that behavior.

**Test Cases**:
1. **Existing Package Upload Preservation**: Create a package, then upload multiple documents to it → Verify all uploads succeed and package remains unchanged (except for added documents)
2. **File Validation Preservation**: Upload invalid files (wrong type, too large) with existing packageId → Verify validation errors match original behavior
3. **Blob Storage Preservation**: Upload documents with existing packageId → Verify blob URLs are generated correctly and files are stored
4. **Extraction Preservation**: Upload PO/Invoice with existing packageId → Verify immediate extraction runs and data is saved correctly

### Unit Tests

- Test new package creation with valid agency user (AgencyId populated correctly)
- Test new package creation with non-agency user (403 Forbidden returned)
- Test new package creation with user not found (appropriate error returned)
- Test existing package upload (no changes to behavior)
- Test edge case: agency user with NULL AgencyId in database (403 Forbidden returned)

### Property-Based Tests

- Generate random valid agency users and verify new packages always have matching AgencyId
- Generate random document types and verify all types work correctly with new package creation
- Generate random existing packages and verify uploads to them are unchanged
- Test that all document uploads (new and existing packages) maintain referential integrity

### Integration Tests

- Test full document upload flow: agency user creates package with first document, then adds subsequent documents
- Test multi-user scenario: multiple agency users from different agencies create packages simultaneously
- Test authorization flow: verify ASM and HQ users cannot create new packages
- Test database constraints: verify FK constraint is satisfied and no orphaned records are created
