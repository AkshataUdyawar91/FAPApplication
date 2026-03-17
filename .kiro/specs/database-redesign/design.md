# Database Redesign - Technical Design

## Architecture Overview

This design implements a normalized, relationship-driven database schema that supports:
- Agency-centric organization
- Document-level validation
- Comprehensive approval workflow tracking
- Document versioning for resubmissions
- Full audit trail

## Entity Relationship Diagram

```
Agency (1) ──→ (N) Users
Agency (1) ──→ (N) DocumentPackages
Agency (1) ──→ (N) PO

DocumentPackages (1) ──→ (1) PO
DocumentPackages (1) ──→ (N) Invoices
DocumentPackages (1) ──→ (1) CostSummary
DocumentPackages (1) ──→ (1) ActivitySummary
DocumentPackages (1) ──→ (1) EnquiryDocument
DocumentPackages (1) ──→ (N) AdditionalDocuments
DocumentPackages (1) ──→ (N) Teams
DocumentPackages (1) ──→ (N) RequestApprovalHistory
DocumentPackages (1) ──→ (N) RequestComments
DocumentPackages (1) ──→ (1) Recommendation
DocumentPackages (1) ──→ (1) ConfidenceScore
DocumentPackages (1) ──→ (N) Notifications
DocumentPackages (1) ──→ (N) AuditLogs

Teams (1) ──→ (N) TeamPhotos

PO (1) ──→ (1) ValidationResult
Invoice (1) ──→ (1) ValidationResult
CostSummary (1) ──→ (1) ValidationResult
ActivitySummary (1) ──→ (1) ValidationResult
EnquiryDocument (1) ──→ (1) ValidationResult
TeamPhoto (1) ──→ (1) ValidationResult

ASM (N) ←→ (N) DocumentPackages [via RequestApprovalHistory]
```

## Table Definitions

### 1. Agency (NEW)
Primary entity for supplier/agency management.

**Columns:**
- `Id` (Guid, PK)
- `SupplierCode` (string, unique, indexed) - Unique supplier identifier
- `SupplierName` (string) - Agency/supplier name
- `CreatedAt` (DateTime)
- `UpdatedAt` (DateTime?)
- `CreatedBy` (string?)
- `UpdatedBy` (string?)
- `IsDeleted` (bool)

**Indexes:**
- PK on `Id`
- Unique index on `SupplierCode`
- Index on `IsDeleted`

**Relationships:**
- One-to-many with Users
- One-to-many with DocumentPackages
- One-to-many with PO

---

### 2. Users (MODIFIED)
User accounts with role-based access.

**New Columns:**
- `AgencyId` (Guid?, FK → Agency) - NULL for ASM/RA/Admin users

**Existing Columns:**
- `Id` (Guid, PK)
- `Email` (string, unique)
- `PasswordHash` (string)
- `FullName` (string)
- `Role` (enum: Agency, ASM, RA, Admin)
- `PhoneNumber` (string?)
- `IsActive` (bool)
- `LastLoginAt` (DateTime?)
- `CreatedAt`, `UpdatedAt`, `CreatedBy`, `UpdatedBy`, `IsDeleted`

**Indexes:**
- PK on `Id`
- Unique index on `Email`
- Index on `AgencyId`
- Index on `Role`
- Index on `IsActive`

**Relationships:**
- Many-to-one with Agency (nullable)
- One-to-many with DocumentPackages (as submitter)
- One-to-many with RequestComments
- One-to-many with Notifications
- One-to-many with AuditLogs
- One-to-many with Conversations

---

### 3. ASM (NEW)
Area Sales Manager tracking.

**Columns:**
- `Id` (Guid, PK)
- `Name` (string) - ASM full name
- `Location` (string) - Geographic area/region
- `UserId` (Guid?, FK → Users) - Link to user account if exists
- `CreatedAt`, `UpdatedAt`, `CreatedBy`, `UpdatedBy`, `IsDeleted`

**Indexes:**
- PK on `Id`
- Index on `UserId`
- Index on `Location`

**Relationships:**
- Many-to-one with Users (optional)
- Many-to-many with DocumentPackages (via RequestApprovalHistory)

---

### 4. DocumentPackages (MODIFIED)
Central submission entity.

**Modified Columns:**
- `AgencyId` (Guid, FK → Agency) - REQUIRED
- `State` (enum) - Updated values: Uploaded, Extracting, Validating, PendingASM, ASMRejected, PendingRA, RARejected, Approved
- `VersionNumber` (int) - Tracks resubmission version (starts at 1)

**Removed Columns:**
- Remove all ASM/HQ specific review fields (moved to RequestApprovalHistory)
- Remove `ReviewedByUserId`, `ReviewedAt`, `ReviewNotes`
- Remove `ASMReviewedByUserId`, `ASMReviewedAt`, `ASMReviewNotes`
- Remove `HQReviewedByUserId`, `HQReviewedAt`, `HQReviewNotes`
- Remove `ResubmissionCount`, `HQResubmissionCount`
- Remove campaign-specific fields (moved to Teams)
- Remove enquiry document fields (moved to EnquiryDocument table)

**Existing Columns:**
- `Id` (Guid, PK)
- `SubmittedByUserId` (Guid, FK → Users)
- `CreatedAt`, `UpdatedAt`, `CreatedBy`, `UpdatedBy`, `IsDeleted`

**Indexes:**
- PK on `Id`
- Index on `AgencyId`
- Index on `SubmittedByUserId`
- Index on `State`
- Index on `VersionNumber`
- Composite index on (`AgencyId`, `State`)
- Composite index on (`SubmittedByUserId`, `CreatedAt`)

**Relationships:**
- Many-to-one with Agency
- Many-to-one with Users (submitter)
- One-to-one with PO
- One-to-many with Invoices
- One-to-one with CostSummary
- One-to-one with ActivitySummary
- One-to-one with EnquiryDocument
- One-to-many with AdditionalDocuments
- One-to-many with Teams
- One-to-many with RequestApprovalHistory
- One-to-many with RequestComments
- One-to-one with Recommendation
- One-to-one with ConfidenceScore
- One-to-many with Notifications
- One-to-many with AuditLogs

---

### 5. PO (NEW - replaces Document with Type=PO)
Purchase Order document (one per package).

**Columns:**
- `Id` (Guid, PK)
- `PackageId` (Guid, FK → DocumentPackages, unique)
- `AgencyId` (Guid, FK → Agency)
- `PONumber` (string?) - Extracted PO number
- `PODate` (DateTime?) - PO date
- `VendorName` (string?)
- `TotalAmount` (decimal?)
- `FileName` (string)
- `BlobUrl` (string)
- `FileSizeBytes` (long)
- `ContentType` (string)
- `ExtractedDataJson` (string?) - Full extracted data
- `ExtractionConfidence` (double?)
- `IsFlaggedForReview` (bool)
- `VersionNumber` (int) - Matches parent package version
- `CreatedAt`, `UpdatedAt`, `CreatedBy`, `UpdatedBy`, `IsDeleted`

**Indexes:**
- PK on `Id`
- Unique index on `PackageId`
- Index on `AgencyId`
- Index on `PONumber`
- Index on `VersionNumber`

**Relationships:**
- One-to-one with DocumentPackages
- Many-to-one with Agency
- One-to-one with ValidationResult

---

### 6. Invoices (MODIFIED - replaces Invoice table)
Invoice documents (many per package).

**Modified Columns:**
- `PackageId` (Guid, FK → DocumentPackages) - Direct link to package
- `VersionNumber` (int) - Matches parent package version

**Removed Columns:**
- Remove `PODocumentId` (no longer needed)

**Existing Columns:**
- `Id` (Guid, PK)
- `InvoiceNumber`, `InvoiceDate`, `VendorName`, `GSTNumber`
- `SubTotal`, `TaxAmount`, `TotalAmount`
- `FileName`, `BlobUrl`, `FileSizeBytes`, `ContentType`
- `ExtractedDataJson`, `ExtractionConfidence`, `IsFlaggedForReview`
- `CreatedAt`, `UpdatedAt`, `CreatedBy`, `UpdatedBy`, `IsDeleted`

**Indexes:**
- PK on `Id`
- Index on `PackageId`
- Index on `InvoiceNumber`
- Index on `VersionNumber`

**Relationships:**
- Many-to-one with DocumentPackages
- One-to-one with ValidationResult

---

### 7. CostSummary (NEW - replaces Campaign cost summary fields)
Cost summary document (one per package).

**Columns:**
- `Id` (Guid, PK)
- `PackageId` (Guid, FK → DocumentPackages, unique)
- `TotalCost` (decimal?)
- `CostBreakdownJson` (string?) - Detailed cost breakdown
- `FileName` (string)
- `BlobUrl` (string)
- `FileSizeBytes` (long)
- `ContentType` (string)
- `ExtractedDataJson` (string?)
- `ExtractionConfidence` (double?)
- `IsFlaggedForReview` (bool)
- `VersionNumber` (int)
- `CreatedAt`, `UpdatedAt`, `CreatedBy`, `UpdatedBy`, `IsDeleted`

**Indexes:**
- PK on `Id`
- Unique index on `PackageId`
- Index on `VersionNumber`

**Relationships:**
- One-to-one with DocumentPackages
- One-to-one with ValidationResult

---

### 8. ActivitySummary (NEW - replaces Campaign activity summary fields)
Activity summary document (one per package).

**Columns:**
- `Id` (Guid, PK)
- `PackageId` (Guid, FK → DocumentPackages, unique)
- `ActivityDescription` (string?)
- `FileName` (string)
- `BlobUrl` (string)
- `FileSizeBytes` (long)
- `ContentType` (string)
- `ExtractedDataJson` (string?)
- `ExtractionConfidence` (double?)
- `IsFlaggedForReview` (bool)
- `VersionNumber` (int)
- `CreatedAt`, `UpdatedAt`, `CreatedBy`, `UpdatedBy`, `IsDeleted`

**Indexes:**
- PK on `Id`
- Unique index on `PackageId`
- Index on `VersionNumber`

**Relationships:**
- One-to-one with DocumentPackages
- One-to-one with ValidationResult

---

### 9. EnquiryDocument (NEW - replaces DocumentPackage enquiry fields)
Enquiry document (one per package).

**Columns:**
- `Id` (Guid, PK)
- `PackageId` (Guid, FK → DocumentPackages, unique)
- `FileName` (string)
- `BlobUrl` (string)
- `FileSizeBytes` (long)
- `ContentType` (string)
- `ExtractedDataJson` (string?)
- `ExtractionConfidence` (double?)
- `IsFlaggedForReview` (bool)
- `VersionNumber` (int)
- `CreatedAt`, `UpdatedAt`, `CreatedBy`, `UpdatedBy`, `IsDeleted`

**Indexes:**
- PK on `Id`
- Unique index on `PackageId`
- Index on `VersionNumber`

**Relationships:**
- One-to-one with DocumentPackages
- One-to-one with ValidationResult

---

### 10. AdditionalDocuments (NEW)
Any additional supporting documents (many per package).

**Columns:**
- `Id` (Guid, PK)
- `PackageId` (Guid, FK → DocumentPackages)
- `DocumentType` (string) - User-defined type
- `Description` (string?)
- `FileName` (string)
- `BlobUrl` (string)
- `FileSizeBytes` (long)
- `ContentType` (string)
- `VersionNumber` (int)
- `CreatedAt`, `UpdatedAt`, `CreatedBy`, `UpdatedBy`, `IsDeleted`

**Indexes:**
- PK on `Id`
- Index on `PackageId`
- Index on `VersionNumber`

**Relationships:**
- Many-to-one with DocumentPackages

---

### 11. Teams (MODIFIED - replaces Campaign)
Team/campaign information (many per package).

**Modified Columns:**
- Remove cost summary fields (moved to CostSummary table)
- Remove activity summary fields (moved to ActivitySummary table)

**Existing Columns:**
- `Id` (Guid, PK)
- `PackageId` (Guid, FK → DocumentPackages)
- `CampaignName`, `TeamCode`
- `StartDate`, `EndDate`, `WorkingDays`
- `DealershipName`, `DealershipAddress`, `GPSLocation`, `State`
- `TeamsJson` (string?) - Team members data
- `VersionNumber` (int) - NEW
- `CreatedAt`, `UpdatedAt`, `CreatedBy`, `UpdatedBy`, `IsDeleted`

**Indexes:**
- PK on `Id`
- Index on `PackageId`
- Index on `TeamCode`
- Index on `VersionNumber`

**Relationships:**
- Many-to-one with DocumentPackages
- One-to-many with TeamPhotos

---

### 12. TeamPhotos (MODIFIED - replaces CampaignPhoto)
Photos linked to teams (many per team).

**Modified Columns:**
- Remove `CampaignId` → rename to `TeamId`
- Add `VersionNumber` (int)

**Existing Columns:**
- `Id` (Guid, PK)
- `TeamId` (Guid, FK → Teams) - renamed from CampaignId
- `PackageId` (Guid, FK → DocumentPackages)
- `FileName`, `BlobUrl`, `FileSizeBytes`, `ContentType`
- `Caption`, `PhotoTimestamp`, `Latitude`, `Longitude`, `DeviceModel`
- `ExtractedMetadataJson`, `ExtractionConfidence`, `IsFlaggedForReview`
- `DisplayOrder`
- `CreatedAt`, `UpdatedAt`, `CreatedBy`, `UpdatedBy`, `IsDeleted`

**Indexes:**
- PK on `Id`
- Index on `TeamId`
- Index on `PackageId`
- Index on `VersionNumber`

**Relationships:**
- Many-to-one with Teams
- Many-to-one with DocumentPackages
- One-to-one with ValidationResult

---

### 13. ValidationResult (MODIFIED)
Document-level validation results.

**Modified Columns:**
- Remove `PackageId` (validation is per document now)
- Add polymorphic relationship fields:
  - `DocumentType` (enum: PO, Invoice, CostSummary, ActivitySummary, EnquiryDocument, TeamPhoto)
  - `DocumentId` (Guid) - ID of the specific document

**Existing Columns:**
- `Id` (Guid, PK)
- `SapVerificationPassed`, `AmountConsistencyPassed`, `LineItemMatchingPassed`
- `CompletenessCheckPassed`, `DateValidationPassed`, `VendorMatchingPassed`
- `AllValidationsPassed`
- `ValidationDetailsJson`, `FailureReason`
- `CreatedAt`, `UpdatedAt`, `CreatedBy`, `UpdatedBy`, `IsDeleted`

**Indexes:**
- PK on `Id`
- Composite index on (`DocumentType`, `DocumentId`)
- Index on `AllValidationsPassed`

**Relationships:**
- One-to-one with PO
- One-to-one with Invoice
- One-to-one with CostSummary
- One-to-one with ActivitySummary
- One-to-one with EnquiryDocument
- One-to-one with TeamPhoto

---

### 14. RequestApprovalHistory (NEW)
Complete approval workflow tracking.

**Columns:**
- `Id` (Guid, PK) - ApprovalId
- `PackageId` (Guid, FK → DocumentPackages)
- `ApproverId` (Guid, FK → Users)
- `ApproverRole` (enum: Agency, ASM, RA, Admin)
- `Action` (enum: Submitted, Approved, Rejected, Resubmitted)
- `Comments` (string?)
- `ActionDate` (DateTime)
- `VersionNumber` (int) - Package version at time of action
- `CreatedAt`, `UpdatedAt`, `CreatedBy`, `UpdatedBy`, `IsDeleted`

**Indexes:**
- PK on `Id`
- Index on `PackageId`
- Index on `ApproverId`
- Index on `ApproverRole`
- Index on `ActionDate`
- Composite index on (`PackageId`, `VersionNumber`)
- Composite index on (`PackageId`, `ActionDate`)

**Relationships:**
- Many-to-one with DocumentPackages
- Many-to-one with Users (approver)

---

### 15. RequestComments (NEW)
Comments on submissions with versioning.

**Columns:**
- `Id` (Guid, PK) - CommentId
- `PackageId` (Guid, FK → DocumentPackages)
- `UserId` (Guid, FK → Users)
- `UserRole` (enum: Agency, ASM, RA, Admin)
- `CommentText` (string)
- `CommentDate` (DateTime)
- `VersionNumber` (int) - Package version when comment was made
- `CreatedAt`, `UpdatedAt`, `CreatedBy`, `UpdatedBy`, `IsDeleted`

**Indexes:**
- PK on `Id`
- Index on `PackageId`
- Index on `UserId`
- Index on `CommentDate`
- Composite index on (`PackageId`, `VersionNumber`)

**Relationships:**
- Many-to-one with DocumentPackages
- Many-to-one with Users

---

### 16. ConfidenceScore (KEEP AS IS)
AI confidence scores remain unchanged.

**Existing Structure:**
- `Id`, `PackageId`, `PoConfidence`, `InvoiceConfidence`, `CostSummaryConfidence`
- `ActivityConfidence`, `PhotosConfidence`, `OverallConfidence`, `IsFlaggedForReview`

**Relationships:**
- One-to-one with DocumentPackages

---

### 17. Recommendation (KEEP AS IS)
AI recommendations remain unchanged.

**Existing Structure:**
- `Id`, `PackageId`, `Type`, `Evidence`, `ValidationIssuesJson`, `ConfidenceScore`

**Relationships:**
- One-to-one with DocumentPackages

---

### 18. Notification (KEEP AS IS)
Notifications remain unchanged.

**Relationships:**
- Many-to-one with Users
- Many-to-one with DocumentPackages

---

### 19. AuditLog (KEEP AS IS)
Audit logs remain unchanged.

**Relationships:**
- Many-to-one with Users

---

### 20. Conversation (KEEP AS IS)
Chat conversations remain unchanged.

---

### 21. ConversationMessage (KEEP AS IS)
Chat messages remain unchanged.

---

## Enums

### UserRole (MODIFIED)
```csharp
public enum UserRole
{
    Agency = 1,
    ASM = 2,
    RA = 3,
    Admin = 4
}
```

### PackageState (MODIFIED)
```csharp
public enum PackageState
{
    Uploaded = 1,
    Extracting = 2,
    Validating = 3,
    PendingASM = 4,
    ASMRejected = 5,
    PendingRA = 6,
    RARejected = 7,
    Approved = 8
}
```

### ApprovalAction (NEW)
```csharp
public enum ApprovalAction
{
    Submitted = 1,
    Approved = 2,
    Rejected = 3,
    Resubmitted = 4
}
```

### DocumentType (NEW - for ValidationResult)
```csharp
public enum DocumentType
{
    PO = 1,
    Invoice = 2,
    CostSummary = 3,
    ActivitySummary = 4,
    EnquiryDocument = 5,
    TeamPhoto = 6
}
```

## State Transition Rules

```
Uploaded → Extracting → Validating → PendingASM
PendingASM → Approved (by ASM, goes to PendingRA)
PendingASM → ASMRejected (by ASM)
ASMRejected → Uploaded (resubmission, increment VersionNumber)

PendingRA → Approved (by RA, final approval)
PendingRA → RARejected (by RA)
RARejected → Uploaded (resubmission, increment VersionNumber)
```

## Performance Indexes

### Critical Indexes
1. `DocumentPackages`: (`AgencyId`, `State`), (`SubmittedByUserId`, `CreatedAt`)
2. `RequestApprovalHistory`: (`PackageId`, `VersionNumber`), (`PackageId`, `ActionDate`)
3. `ValidationResult`: (`DocumentType`, `DocumentId`)
4. `Agency`: Unique on `SupplierCode`
5. All foreign keys automatically indexed

### Query Optimization
- Composite indexes support common query patterns
- Covering indexes for list views
- Filtered indexes on `IsDeleted = 0` for active records

## Migration Strategy

### Phase 1: Schema Creation
1. Create new tables: Agency, ASM, PO, CostSummary, ActivitySummary, EnquiryDocument, AdditionalDocuments, RequestApprovalHistory, RequestComments
2. Modify existing tables: Users, DocumentPackages, Invoices, Teams, TeamPhotos, ValidationResult
3. Create new enums and update existing ones

### Phase 2: Data Migration (Separate Task)
1. Migrate existing data to new structure
2. Populate Agency table from existing data
3. Split Document table into specific document types
4. Migrate approval history to RequestApprovalHistory
5. Set initial VersionNumber = 1 for all existing records

### Phase 3: Cleanup (Separate Task)
1. Remove obsolete columns from DocumentPackages
2. Drop old Document table
3. Drop old Campaign/CampaignInvoice/CampaignPhoto tables

## Correctness Properties

### Property 1: Referential Integrity
- All foreign keys must reference existing records
- Cascading deletes configured to prevent orphaned records
- Soft deletes preserve referential integrity

### Property 2: Version Consistency
- All documents in a package must have matching VersionNumber
- VersionNumber increments on resubmission
- Approval history tracks actions per version

### Property 3: State Validity
- PackageState transitions follow defined rules
- State changes logged in RequestApprovalHistory
- Invalid transitions rejected at application layer

### Property 4: Validation Completeness
- Each document type can have exactly one ValidationResult
- ValidationResult.DocumentType matches actual document type
- ValidationResult.DocumentId references valid document

### Property 5: Approval Chain
- ASM approval required before RA review
- Rejection returns to Agency for resubmission
- Approval history immutable (no updates, only inserts)

## Security Considerations

1. **Row-Level Security**: Users can only access packages from their agency (except ASM/RA/Admin)
2. **Audit Trail**: All state changes logged with user, timestamp, and version
3. **Soft Deletes**: Documents marked as deleted, not physically removed
4. **Version Control**: Previous versions retained for audit purposes

## Testing Strategy

### Unit Tests
- Entity validation rules
- State transition logic
- Version number incrementing

### Integration Tests
- Foreign key constraints
- Cascading deletes
- Query performance with indexes

### Property-Based Tests
- Version consistency across related entities
- State transition validity
- Referential integrity maintenance
