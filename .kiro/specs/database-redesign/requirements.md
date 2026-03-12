# Database Redesign Requirements

## Overview
Redesign the database schema to support a cleaner, more normalized structure with proper document-level validation, agency management, ASM tracking, and comprehensive approval history.

## System Roles
The system supports exactly 4 user roles:
1. **Agency** - Submits document packages
2. **ASM** (Area Sales Manager) - First level approval
3. **RA** (Regional Administrator) - Second level approval  
4. **Admin** - System administration

## User Stories

### US-1: Agency Management
**As a** system administrator  
**I want** agencies to be first-class entities with their own suppliers and users  
**So that** we can properly track and manage agency relationships

**Acceptance Criteria:**
- Agency table exists with SupplierCode and SupplierName
- Users belong to an Agency
- DocumentPackages are linked to an Agency
- POs are linked to an Agency

### US-2: Document-Level Validation
**As a** validation system  
**I want** each document type to have its own validation result  
**So that** we can track validation status per document independently

**Acceptance Criteria:**
- ValidationResults table supports multiple document types
- Each PO, Invoice, CostSummary, ActivitySummary, EnquiryDocument, and TeamPhoto can have validation results
- Validation results are properly linked via foreign keys

### US-3: Structured Document Relationships
**As a** system architect  
**I want** clear one-to-one and one-to-many relationships for documents  
**So that** the data model is normalized and maintainable

**Acceptance Criteria:**
- DocumentPackage → 1 PO (one-to-one)
- DocumentPackage → many Invoices (one-to-many)
- DocumentPackage → 1 CostSummary (one-to-one)
- DocumentPackage → 1 ActivitySummary (one-to-one)
- DocumentPackage → 1 EnquiryDocument (one-to-one)
- DocumentPackage → many AdditionalDocuments (one-to-many)
- DocumentPackage → many Teams (one-to-many)
- Teams → many TeamPhotos (one-to-many)

### US-4: ASM Management
**As a** system administrator  
**I want** ASMs to be tracked with their name and location  
**So that** we can properly assign and track ASM assignments

**Acceptance Criteria:**
- ASM table exists with Name and Location columns
- Many-to-many relationship between ASM and DocumentPackages
- ASM assignments are tracked in approval history

### US-5: Approval History Tracking
**As a** compliance officer  
**I want** complete approval history with versioning  
**So that** we can audit all approval actions over time

**Acceptance Criteria:**
- RequestApprovalHistory table tracks all approval actions
- Supports ApproverRole (Agency / ASM / RA / Admin)
- Tracks Action (Submitted / Approved / Rejected / Resubmitted)
- Includes Comments, ActionDate, and VersionNumber
- Full audit trail maintained

### US-6: Comments System
**As a** reviewer  
**I want** to add comments to submissions with versioning  
**So that** communication history is preserved across resubmissions

**Acceptance Criteria:**
- RequestComments table exists
- Links to DocumentPackages with PackageId
- Tracks UserId, UserRole (Agency / ASM / RA / Admin), CommentText, CommentDate
- Supports VersionNumber for tracking across resubmissions

### US-7: Document Versioning
**As an** agency user  
**I want** to delete and re-upload documents during resubmission  
**So that** I can correct issues identified by reviewers

**Acceptance Criteria:**
- All document tables support VersionNumber
- Documents can be soft-deleted and replaced
- History is maintained for audit purposes

### US-8: Workflow Status Tracking
**As a** system  
**I want** to track workflow status through the approval chain  
**So that** users know where submissions are in the process

**Acceptance Criteria:**
- PackageState enum supports: Uploaded, Extracting, Validating, PendingASM, ASMRejected, PendingRA, RARejected, Approved
- State transitions are validated
- State changes are logged in audit history

## Non-Functional Requirements

### NFR-1: Data Integrity
- All foreign key relationships must be enforced
- Cascading deletes configured appropriately
- Referential integrity maintained

### NFR-2: Performance
- Indexes on all foreign keys
- Indexes on frequently queried columns (State, AgencyId, VersionNumber)
- Composite indexes for common query patterns

### NFR-3: Auditability
- All state changes logged
- Approval history immutable
- Soft deletes for documents (IsDeleted flag)

### NFR-4: Normalization
- No redundant columns across tables
- Proper third normal form (3NF)
- Clear separation of concerns

## Out of Scope
- Migration of existing data (will be handled separately)
- UI changes (backend schema only)
- API endpoint modifications (will be handled in separate tasks)

## Success Criteria
- [ ] All entity classes updated with new relationships
- [ ] EF Core configurations created for all relationships
- [ ] Migration generated successfully
- [ ] Schema validates against requirements
- [ ] No compilation errors
- [ ] All existing tests updated to reflect new schema
