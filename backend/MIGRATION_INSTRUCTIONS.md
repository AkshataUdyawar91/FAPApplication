# Database Migration Instructions

## Prerequisites

- .NET 8 SDK
- SQL Server (SQLEXPRESS or full instance)
- Entity Framework Core tools (`dotnet tool install --global dotnet-ef`)

## Connection String

Default local development connection:
```
Server=localhost\SQLEXPRESS;Database=BajajDocumentProcessing;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=true
```

Configure in `appsettings.Development.json`.

## Apply Migrations

From the repository root:

```bash
dotnet ef database update --project backend/src/BajajDocumentProcessing.Infrastructure --startup-project backend/src/BajajDocumentProcessing.API
```

## Current Migrations

1. `DatabaseRedesign` - Creates the redesigned schema with all new tables
2. `RemoveLegacyDocumentsTable` - Drops the legacy Documents table

## Database Schema (Post-Redesign)

### Core Tables
- **Users** - System users with roles (Agency, ASM, RA, Admin)
- **Agencies** - Agency/supplier entities with SupplierCode
- **ASMs** - Area Sales Manager tracking (Name, Location)
- **DocumentPackages** - Central submission entity with AgencyId, VersionNumber, State

### Document Tables (Dedicated Per-Type)
- **POs** - Purchase Orders (one per package)
- **Invoices** - Invoice documents (many per package)
- **CostSummaries** - Cost summary documents (one per package)
- **ActivitySummaries** - Activity summary documents (one per package)
- **EnquiryDocuments** - Enquiry documents (one per package)
- **AdditionalDocuments** - Supporting documents (many per package)

### Team/Campaign Tables
- **Teams** - Team/campaign info (many per package)
- **TeamPhotos** - Photos linked to teams (many per team)
- **CampaignInvoices** - Campaign-level invoices

### Workflow Tables
- **RequestApprovalHistory** - Approval actions with versioning
- **RequestComments** - Comments with versioning
- **ValidationResults** - Per-document validation (polymorphic via DocumentType + DocumentId)

### AI/Analytics Tables
- **ConfidenceScores** - AI confidence scores (one per package)
- **Recommendations** - AI approval recommendations (one per package)
- **Notifications** - In-app notifications
- **AuditLogs** - Audit trail
- **Conversations** / **ConversationMessages** - Chat history

## Breaking Changes from Redesign

1. **Documents table removed** - All services now use dedicated tables (POs, Invoices, etc.)
2. **UserRole enum updated** - HQ renamed to RA; values: Agency=1, ASM=2, RA=3, Admin=4
3. **PackageState enum updated** - New states: PendingASM, ASMRejected, PendingRA, RARejected
4. **ValidationResult** - Now uses polymorphic (DocumentType, DocumentId) instead of PackageId
5. **DocumentPackage** - Added AgencyId (required), VersionNumber; removed review fields

## State Transitions

```
Uploaded → Extracting → Validating → PendingASM
PendingASM → PendingRA (ASM approves) | ASMRejected (ASM rejects)
ASMRejected → Uploaded (resubmission)
PendingRA → Approved (RA approves) | RARejected (RA rejects)
RARejected → Uploaded (resubmission)
```

## Troubleshooting

If connection string gets overwritten after git pull, update:
1. `backend/src/BajajDocumentProcessing.API/appsettings.json`
2. `backend/src/BajajDocumentProcessing.API/appsettings.Development.json`

Change `SQLEXPRESS01` to `SQLEXPRESS` if needed.
