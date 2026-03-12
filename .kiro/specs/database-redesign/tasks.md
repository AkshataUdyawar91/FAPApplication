# Database Redesign - Implementation Tasks

## Overview
This document breaks down the database redesign into small, independently verifiable tasks. Each task should be completed and tested before moving to the next.

## Tasks

### Phase 1: New Entity Creation
- [x] 1.1 Create Agency Entity
- [x] 1.2 Create ASM Entity
- [x] 1.3 Create PO Entity
- [x] 1.4 Create CostSummary Entity
- [x] 1.5 Create ActivitySummary Entity
- [x] 1.6 Create EnquiryDocument Entity
- [x] 1.7 Create AdditionalDocument Entity
- [x] 1.8 Create RequestApprovalHistory Entity
- [x] 1.9 Create RequestComments Entity

### Phase 2: Enum Updates
- [x] 2.1 Update UserRole Enum
- [x] 2.2 Update PackageState Enum
- [x] 2.3 Create ApprovalAction Enum
- [x] 2.4 Update DocumentType Enum

### Phase 3: Modify Existing Entities
- [x] 3.1 Update User Entity
- [x] 3.2 Update DocumentPackage Entity
- [x] 3.3 Update Invoice Entity
- [x] 3.4 Update Teams Entity (formerly Campaign)
- [x] 3.5 Update TeamPhotos Entity (formerly CampaignPhoto)
- [x] 3.6 Update ValidationResult Entity

### Phase 4: Update DbContext
- [x] 4.1 Register New Entities in DbContext

### Phase 5: Create Migration
- [x] 5.1 Generate EF Core Migration
- [x] 5.2 Review Migration SQL

### Phase 6: Update Application Layer
- [x] 6.1 Update DTOs for New Entities
- [x] 6.2 Update Service Interfaces

### Phase 7: Testing
- [x] 7.1 Update Unit Tests
- [x] 7.2 Create Property-Based Tests

### Phase 8: Documentation
- [x] 8.1 Update API Documentation
- [x] 8.2 Create Migration Guide

---

## Task Details

### 1.1 Create Agency Entity
**Estimated Time:** 30 minutes

**Steps:**
1. Create `backend/src/BajajDocumentProcessing.Domain/Entities/Agency.cs`
2. Add properties: Id, SupplierCode, SupplierName, BaseEntity fields
3. Add navigation properties: Users, DocumentPackages, POs
4. Create EF Core configuration: `backend/src/BajajDocumentProcessing.Infrastructure/Persistence/Configurations/AgencyConfiguration.cs`
5. Configure unique index on SupplierCode
6. Configure relationships

**Verification:**
- Entity compiles without errors
- Configuration file created
- Relationships defined

---

### 1.2 Create ASM Entity
**Estimated Time:** 20 minutes

**Steps:**
1. Create `backend/src/BajajDocumentProcessing.Domain/Entities/ASM.cs`
2. Add properties: Id, Name, Location, UserId (nullable), BaseEntity fields
3. Add navigation property: User
4. Create EF Core configuration: `backend/src/BajajDocumentProcessing.Infrastructure/Persistence/Configurations/ASMConfiguration.cs`
5. Configure relationships

**Verification:**
- Entity compiles without errors
- Configuration file created
- Optional UserId relationship configured

---

### 1.3 Create PO Entity
**Estimated Time:** 30 minutes

**Steps:**
1. Create `backend/src/BajajDocumentProcessing.Domain/Entities/PO.cs`
2. Add properties: Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, file fields, extraction fields, VersionNumber
3. Add navigation properties: DocumentPackage, Agency, ValidationResult
4. Create EF Core configuration: `backend/src/BajajDocumentProcessing.Infrastructure/Persistence/Configurations/POConfiguration.cs`
5. Configure unique index on PackageId (one-to-one)
6. Configure indexes on AgencyId, PONumber, VersionNumber

**Verification:**
- Entity compiles without errors
- One-to-one relationship with DocumentPackage configured
- Indexes defined

---

### 1.4 Create CostSummary Entity
**Estimated Time:** 25 minutes

**Steps:**
1. Create `backend/src/BajajDocumentProcessing.Domain/Entities/CostSummary.cs`
2. Add properties: Id, PackageId, TotalCost, CostBreakdownJson, file fields, extraction fields, VersionNumber
3. Add navigation properties: DocumentPackage, ValidationResult
4. Create EF Core configuration
5. Configure unique index on PackageId (one-to-one)

**Verification:**
- Entity compiles without errors
- One-to-one relationship configured
- Configuration file created

---

### 1.5 Create ActivitySummary Entity
**Estimated Time:** 25 minutes

**Steps:**
1. Create `backend/src/BajajDocumentProcessing.Domain/Entities/ActivitySummary.cs`
2. Add properties: Id, PackageId, ActivityDescription, file fields, extraction fields, VersionNumber
3. Add navigation properties: DocumentPackage, ValidationResult
4. Create EF Core configuration
5. Configure unique index on PackageId (one-to-one)

**Verification:**
- Entity compiles without errors
- One-to-one relationship configured
- Configuration file created

---

### 1.6 Create EnquiryDocument Entity
**Estimated Time:** 25 minutes

**Steps:**
1. Create `backend/src/BajajDocumentProcessing.Domain/Entities/EnquiryDocument.cs`
2. Add properties: Id, PackageId, file fields, extraction fields, VersionNumber
3. Add navigation properties: DocumentPackage, ValidationResult
4. Create EF Core configuration
5. Configure unique index on PackageId (one-to-one)

**Verification:**
- Entity compiles without errors
- One-to-one relationship configured
- Configuration file created

---

### 1.7 Create AdditionalDocument Entity
**Estimated Time:** 20 minutes

**Steps:**
1. Create `backend/src/BajajDocumentProcessing.Domain/Entities/AdditionalDocument.cs`
2. Add properties: Id, PackageId, DocumentType, Description, file fields, VersionNumber
3. Add navigation property: DocumentPackage
4. Create EF Core configuration
5. Configure index on PackageId

**Verification:**
- Entity compiles without errors
- One-to-many relationship configured
- Configuration file created

---

### 1.8 Create RequestApprovalHistory Entity
**Estimated Time:** 30 minutes

**Steps:**
1. Create `backend/src/BajajDocumentProcessing.Domain/Entities/RequestApprovalHistory.cs`
2. Add properties: Id, PackageId, ApproverId, ApproverRole, Action, Comments, ActionDate, VersionNumber
3. Add navigation properties: DocumentPackage, Approver (User)
4. Create EF Core configuration
5. Configure indexes: PackageId, ApproverId, (PackageId, VersionNumber), (PackageId, ActionDate)

**Verification:**
- Entity compiles without errors
- Relationships configured
- Composite indexes defined

---

### 1.9 Create RequestComments Entity
**Estimated Time:** 25 minutes

**Steps:**
1. Create `backend/src/BajajDocumentProcessing.Domain/Entities/RequestComments.cs`
2. Add properties: Id, PackageId, UserId, UserRole, CommentText, CommentDate, VersionNumber
3. Add navigation properties: DocumentPackage, User
4. Create EF Core configuration
5. Configure indexes: PackageId, UserId, (PackageId, VersionNumber)

**Verification:**
- Entity compiles without errors
- Relationships configured
- Composite indexes defined

---

### 2.1 Update UserRole Enum
**Estimated Time:** 10 minutes

**Steps:**
1. Open `backend/src/BajajDocumentProcessing.Domain/Enums/UserRole.cs`
2. Update to: Agency = 1, ASM = 2, RA = 3, Admin = 4
3. Remove HQ value

**Verification:**
- Enum updated
- No compilation errors

---

### 2.2 Update PackageState Enum
**Estimated Time:** 10 minutes

**Steps:**
1. Open `backend/src/BajajDocumentProcessing.Domain/Enums/PackageState.cs`
2. Update values: Uploaded, Extracting, Validating, PendingASM, ASMRejected, PendingRA, RARejected, Approved
3. Remove old values: PendingApproval, Rejected, ReuploadRequested

**Verification:**
- Enum updated
- No compilation errors

---

### 2.3 Create ApprovalAction Enum
**Estimated Time:** 10 minutes

**Steps:**
1. Create `backend/src/BajajDocumentProcessing.Domain/Enums/ApprovalAction.cs`
2. Add values: Submitted = 1, Approved = 2, Rejected = 3, Resubmitted = 4

**Verification:**
- Enum created
- No compilation errors

---

### 2.4 Update DocumentType Enum
**Estimated Time:** 10 minutes

**Steps:**
1. Open `backend/src/BajajDocumentProcessing.Domain/Enums/DocumentType.cs`
2. Update values: PO = 1, Invoice = 2, CostSummary = 3, ActivitySummary = 4, EnquiryDocument = 5, TeamPhoto = 6
3. Remove old values: Photo, Activity

**Verification:**
- Enum updated
- No compilation errors

---

### 3.1 Update User Entity
**Estimated Time:** 20 minutes

**Steps:**
1. Open `backend/src/BajajDocumentProcessing.Domain/Entities/User.cs`
2. Add property: `AgencyId` (Guid?, nullable)
3. Add navigation property: `Agency` (Agency?)
4. Update UserConfiguration to include Agency relationship
5. Add index on AgencyId

**Verification:**
- Property added
- Navigation property added
- Configuration updated
- No compilation errors

---

### 3.2 Update DocumentPackage Entity
**Estimated Time:** 45 minutes

**Steps:**
1. Open `backend/src/BajajDocumentProcessing.Domain/Entities/DocumentPackage.cs`
2. Add new properties:
   - `AgencyId` (Guid, required)
   - `VersionNumber` (int, default 1)
3. Add new navigation properties:
   - `Agency` (Agency)
   - `PO` (PO?)
   - `CostSummary` (CostSummary?)
   - `ActivitySummary` (ActivitySummary?)
   - `EnquiryDocument` (EnquiryDocument?)
   - `AdditionalDocuments` (ICollection<AdditionalDocument>)
   - `RequestApprovalHistory` (ICollection<RequestApprovalHistory>)
   - `RequestComments` (ICollection<RequestComments>)
4. Mark for removal (comment out, don't delete yet):
   - All ASM/HQ review fields
   - ResubmissionCount, HQResubmissionCount
   - Campaign-specific fields
   - Enquiry document fields
5. Update DocumentPackageConfiguration
6. Add indexes: AgencyId, VersionNumber, (AgencyId, State)

**Verification:**
- New properties added
- New navigation properties added
- Old fields commented out
- Configuration updated
- No compilation errors

---

### 3.3 Update Invoice Entity
**Estimated Time:** 20 minutes

**Steps:**
1. Open `backend/src/BajajDocumentProcessing.Domain/Entities/Invoice.cs`
2. Add property: `VersionNumber` (int)
3. Remove property: `PODocumentId` (comment out)
4. Update navigation: Remove `PODocument`, keep `Package`
5. Add navigation: `ValidationResult` (ValidationResult?)
6. Update InvoiceConfiguration
7. Add index on VersionNumber

**Verification:**
- VersionNumber added
- PODocumentId removed
- Navigation updated
- Configuration updated
- No compilation errors

---

### 3.4 Update Teams Entity (formerly Campaign)
**Estimated Time:** 30 minutes

**Steps:**
1. Open `backend/src/BajajDocumentProcessing.Domain/Entities/Campaign.cs`
2. Rename file to `Teams.cs` and class to `Teams`
3. Add property: `VersionNumber` (int)
4. Remove (comment out):
   - All cost summary fields
   - All activity summary fields
5. Update navigation: Rename `Invoices` to reference will be removed
6. Keep navigation: `Photos` (rename to TeamPhotos)
7. Update configuration file (rename to TeamsConfiguration)
8. Add index on VersionNumber

**Verification:**
- File and class renamed
- VersionNumber added
- Cost/Activity fields removed
- Configuration updated
- No compilation errors

---

### 3.5 Update TeamPhotos Entity (formerly CampaignPhoto)
**Estimated Time:** 25 minutes

**Steps:**
1. Open `backend/src/BajajDocumentProcessing.Domain/Entities/CampaignPhoto.cs`
2. Rename file to `TeamPhotos.cs` and class to `TeamPhotos`
3. Rename property: `CampaignId` → `TeamId`
4. Add property: `VersionNumber` (int)
5. Add navigation: `ValidationResult` (ValidationResult?)
6. Update navigation: `Campaign` → `Team`
7. Update configuration file (rename to TeamPhotosConfiguration)
8. Add index on VersionNumber

**Verification:**
- File and class renamed
- TeamId property updated
- VersionNumber added
- Navigation updated
- Configuration updated
- No compilation errors

---

### 3.6 Update ValidationResult Entity
**Estimated Time:** 30 minutes

**Steps:**
1. Open `backend/src/BajajDocumentProcessing.Domain/Entities/ValidationResult.cs`
2. Remove property: `PackageId`
3. Add properties:
   - `DocumentType` (DocumentType enum)
   - `DocumentId` (Guid)
4. Remove navigation: `Package`
5. Add comment explaining polymorphic relationship
6. Update ValidationResultConfiguration
7. Add composite index on (DocumentType, DocumentId)

**Verification:**
- PackageId removed
- Polymorphic fields added
- Configuration updated
- Composite index defined
- No compilation errors

---

### 4.1 Register New Entities in DbContext
**Estimated Time:** 20 minutes

**Steps:**
1. Open `backend/src/BajajDocumentProcessing.Infrastructure/Persistence/ApplicationDbContext.cs`
2. Add DbSet properties:
   - `DbSet<Agency> Agencies`
   - `DbSet<ASM> ASMs`
   - `DbSet<PO> POs`
   - `DbSet<CostSummary> CostSummaries`
   - `DbSet<ActivitySummary> ActivitySummaries`
   - `DbSet<EnquiryDocument> EnquiryDocuments`
   - `DbSet<AdditionalDocument> AdditionalDocuments`
   - `DbSet<RequestApprovalHistory> RequestApprovalHistories`
   - `DbSet<RequestComments> RequestComments`
3. Rename DbSet: `Campaigns` → `Teams`
4. Rename DbSet: `CampaignPhotos` → `TeamPhotos`
5. Apply configurations in OnModelCreating

**Verification:**
- All DbSets added
- DbSets renamed
- Configurations applied
- No compilation errors

---

### 5.1 Generate EF Core Migration
**Estimated Time:** 15 minutes

**Steps:**
1. Build solution: `dotnet build`
2. Navigate to API project directory
3. Generate migration: `dotnet ef migrations add DatabaseRedesign`
4. Review generated migration file
5. Verify Up() and Down() methods

**Verification:**
- Migration generated successfully
- Migration file reviewed
- Up() creates new tables
- Down() drops new tables
- No errors in migration code

---

### 5.2 Review Migration SQL
**Estimated Time:** 20 minutes

**Steps:**
1. Generate SQL script: `dotnet ef migrations script`
2. Review SQL for:
   - Table creation statements
   - Foreign key constraints
   - Index creation
   - Column modifications
3. Verify no data loss operations
4. Check for proper cascading delete rules

**Verification:**
- SQL script generated
- All tables created
- Foreign keys correct
- Indexes created
- No destructive operations

---

### 6.1 Update DTOs for New Entities
**Estimated Time:** 60 minutes

**Steps:**
1. Create `backend/src/BajajDocumentProcessing.Application/DTOs/Agency/`
   - `AgencyDto.cs`
   - `CreateAgencyRequest.cs`
2. Create `backend/src/BajajDocumentProcessing.Application/DTOs/ASM/`
   - `ASMDto.cs`
3. Create `backend/src/BajajDocumentProcessing.Application/DTOs/Approval/`
   - `RequestApprovalHistoryDto.cs`
   - `RequestCommentDto.cs`
   - `ApprovalActionRequest.cs`
4. Update existing DTOs to include VersionNumber where applicable

**Verification:**
- All DTOs created
- DTOs follow naming conventions
- DataAnnotations added for validation
- No compilation errors

---

### 6.2 Update Service Interfaces
**Estimated Time:** 30 minutes

**Steps:**
1. Review and update service interfaces to support new entities
2. Add methods for approval workflow
3. Add methods for versioning support
4. Update method signatures to include AgencyId where needed

**Verification:**
- Interfaces updated
- New methods added
- No compilation errors

---

### 7.1 Update Unit Tests
**Estimated Time:** 90 minutes

**Steps:**
1. Update existing entity tests for modified entities
2. Create tests for new entities
3. Test relationship configurations
4. Test validation rules
5. Test enum updates

**Verification:**
- All tests updated
- New tests created
- All tests pass
- Code coverage maintained

---

### 7.2 Create Property-Based Tests
**Estimated Time:** 60 minutes

**Steps:**
1. Create property tests for version consistency
2. Create property tests for state transitions
3. Create property tests for referential integrity
4. Test approval workflow properties

**Verification:**
- Property tests created
- All properties verified
- Tests pass with multiple iterations

---

### 8.1 Update API Documentation
**Estimated Time:** 30 minutes

**Steps:**
1. Update Swagger/OpenAPI documentation
2. Document new endpoints
3. Update existing endpoint documentation
4. Add examples for new request/response models

**Verification:**
- Swagger UI updated
- All endpoints documented
- Examples provided

---

### 8.2 Create Migration Guide
**Estimated Time:** 45 minutes

**Steps:**
1. Document breaking changes
2. Create data migration script outline
3. Document new workflow
4. Update README with new schema information

**Verification:**
- Migration guide created
- Breaking changes documented
- README updated

---

## Rollback Plan

If issues are encountered:

1. **Before Migration Applied:**
   - Delete migration file
   - Revert code changes
   - Checkout previous branch

2. **After Migration Applied:**
   - Run: `dotnet ef database update <PreviousMigration>`
   - Revert code changes
   - Review and fix issues
   - Create new migration

## Success Criteria

- All tasks completed
- All tests passing
- Migration generates successfully
- No compilation errors
- Documentation updated
- Code review completed
- Ready for data migration phase

## Estimated Total Time
- Phase 1: 4 hours
- Phase 2: 40 minutes
- Phase 3: 3 hours
- Phase 4: 20 minutes
- Phase 5: 35 minutes
- Phase 6: 1.5 hours
- Phase 7: 2.5 hours
- Phase 8: 1.25 hours

**Total: ~13.5 hours** (approximately 2 working days)
