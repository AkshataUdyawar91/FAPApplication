-- =============================================
-- Bajaj Document Processing - Azure Synapse Analytics Schema
-- Target: Azure Synapse Analytics Dedicated SQL Pool
-- Database: Balsynwsdev
-- Table Prefix: BDP_
-- =============================================
-- Synapse Dedicated SQL Pool Constraints:
--   No FOREIGN KEY, No UNIQUE, No DEFAULT on columns
--   No DROP TABLE IF EXISTS syntax
--   No CREATE INDEX (use CLUSTERED COLUMNSTORE INDEX)
--   NVARCHAR(MAX) replaced with NVARCHAR(4000)
-- =============================================

-- ENUM REFERENCE (stored as INT)
-- UserRole:             0=Agency, 1=CircleHead(ASM), 2=RA(HQ), 3=Admin
-- DocumentType:         0=PO, 1=Invoice, 2=CostSummary, 3=ActivitySummary, 4=EnquiryDocument, 5=TeamPhoto
-- PackageState:         0=Uploaded, 1=Extracting, 2=Validating, 3=PendingASM, 4=ASMRejected, 5=PendingRA, 6=RARejected, 7=Approved
-- NotificationType:     0=SubmissionReceived, 1=FlaggedForReview, 2=Approved, 3=Rejected, 4=ReuploadRequested
-- RecommendationType:   0=Approve, 1=Review, 2=Reject
-- ApprovalAction:       0=Submitted, 1=Approved, 2=Rejected, 3=Resubmitted

-- =============================================
-- DROP EXISTING TABLES (reverse dependency order)
-- =============================================

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_ConversationMessages') AND type = N'U')
    DROP TABLE dbo.BDP_ConversationMessages;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_Conversations') AND type = N'U')
    DROP TABLE dbo.BDP_Conversations;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_RequestComments') AND type = N'U')
    DROP TABLE dbo.BDP_RequestComments;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_RequestApprovalHistory') AND type = N'U')
    DROP TABLE dbo.BDP_RequestApprovalHistory;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_TeamPhotos') AND type = N'U')
    DROP TABLE dbo.BDP_TeamPhotos;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_Teams') AND type = N'U')
    DROP TABLE dbo.BDP_Teams;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_Invoices') AND type = N'U')
    DROP TABLE dbo.BDP_Invoices;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_AuditLogs') AND type = N'U')
    DROP TABLE dbo.BDP_AuditLogs;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_EmailDeliveryLogs') AND type = N'U')
    DROP TABLE dbo.BDP_EmailDeliveryLogs;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_Notifications') AND type = N'U')
    DROP TABLE dbo.BDP_Notifications;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_Recommendations') AND type = N'U')
    DROP TABLE dbo.BDP_Recommendations;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_ConfidenceScores') AND type = N'U')
    DROP TABLE dbo.BDP_ConfidenceScores;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_ValidationResults') AND type = N'U')
    DROP TABLE dbo.BDP_ValidationResults;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_ActivitySummaries') AND type = N'U')
    DROP TABLE dbo.BDP_ActivitySummaries;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_EnquiryDocuments') AND type = N'U')
    DROP TABLE dbo.BDP_EnquiryDocuments;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_AdditionalDocuments') AND type = N'U')
    DROP TABLE dbo.BDP_AdditionalDocuments;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_CostSummaries') AND type = N'U')
    DROP TABLE dbo.BDP_CostSummaries;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_POBalanceLogs') AND type = N'U')
    DROP TABLE dbo.BDP_POBalanceLogs;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_POSyncLogs') AND type = N'U')
    DROP TABLE dbo.BDP_POSyncLogs;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_POs') AND type = N'U')
    DROP TABLE dbo.BDP_POs;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_DocumentPackages') AND type = N'U')
    DROP TABLE dbo.BDP_DocumentPackages;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_SubmissionSequences') AND type = N'U')
    DROP TABLE dbo.BDP_SubmissionSequences;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_Users') AND type = N'U')
    DROP TABLE dbo.BDP_Users;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_Agencies') AND type = N'U')
    DROP TABLE dbo.BDP_Agencies;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_StateMappings') AND type = N'U')
    DROP TABLE dbo.BDP_StateMappings;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_Dealers') AND type = N'U')
    DROP TABLE dbo.BDP_Dealers;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_StateCities') AND type = N'U')
    DROP TABLE dbo.BDP_StateCities;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_CostMasterStateRates') AND type = N'U')
    DROP TABLE dbo.BDP_CostMasterStateRates;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_CostMasters') AND type = N'U')
    DROP TABLE dbo.BDP_CostMasters;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_HsnMasters') AND type = N'U')
    DROP TABLE dbo.BDP_HsnMasters;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BDP_StateGstMasters') AND type = N'U')
    DROP TABLE dbo.BDP_StateGstMasters;

-- =============================================
-- PART 1: REFERENCE DATA TABLES
-- =============================================

-- StateGstMaster: GST state code to state name mapping
-- Note: GstCode removed; GstPercentage added (matches current domain entity)
CREATE TABLE dbo.BDP_StateGstMasters
(
    Id              UNIQUEIDENTIFIER    NOT NULL,
    StateCode       NVARCHAR(10)        NOT NULL,
    StateName       NVARCHAR(100)       NOT NULL,
    GstPercentage   DECIMAL(5, 2)       NOT NULL,
    IsActive        BIT                 NOT NULL,
    IsDeleted       BIT                 NOT NULL,
    CreatedAt       DATETIME2           NOT NULL,
    UpdatedAt       DATETIME2           NULL,
    CreatedBy       NVARCHAR(256)       NULL,
    UpdatedBy       NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = ROUND_ROBIN,
    CLUSTERED COLUMNSTORE INDEX
);

-- HsnMaster: HSN/SAC code reference data
CREATE TABLE dbo.BDP_HsnMasters
(
    Id              UNIQUEIDENTIFIER    NOT NULL,
    Code            NVARCHAR(20)        NOT NULL,
    Description     NVARCHAR(500)       NOT NULL,
    IsActive        BIT                 NOT NULL,
    IsDeleted       BIT                 NOT NULL,
    CreatedAt       DATETIME2           NOT NULL,
    UpdatedAt       DATETIME2           NULL,
    CreatedBy       NVARCHAR(256)       NULL,
    UpdatedBy       NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = ROUND_ROBIN,
    CLUSTERED COLUMNSTORE INDEX
);

-- CostMaster: Cost element definition with expense nature
CREATE TABLE dbo.BDP_CostMasters
(
    Id              UNIQUEIDENTIFIER    NOT NULL,
    ElementName     NVARCHAR(200)       NOT NULL,
    ExpenseNature   NVARCHAR(50)        NOT NULL,
    IsActive        BIT                 NOT NULL,
    IsDeleted       BIT                 NOT NULL,
    CreatedAt       DATETIME2           NOT NULL,
    UpdatedAt       DATETIME2           NULL,
    CreatedBy       NVARCHAR(256)       NULL,
    UpdatedBy       NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = ROUND_ROBIN,
    CLUSTERED COLUMNSTORE INDEX
);

-- CostMasterStateRate: State-wise cost rate for a cost element
CREATE TABLE dbo.BDP_CostMasterStateRates
(
    Id              UNIQUEIDENTIFIER    NOT NULL,
    StateCode       NVARCHAR(50)        NOT NULL,
    ElementName     NVARCHAR(200)       NOT NULL,
    RateValue       DECIMAL(18, 2)      NOT NULL,
    RateType        NVARCHAR(20)        NOT NULL,
    IsActive        BIT                 NOT NULL,
    IsDeleted       BIT                 NOT NULL,
    CreatedAt       DATETIME2           NOT NULL,
    UpdatedAt       DATETIME2           NULL,
    CreatedBy       NVARCHAR(256)       NULL,
    UpdatedBy       NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = ROUND_ROBIN,
    CLUSTERED COLUMNSTORE INDEX
);

-- StateMappings: Maps a state to its assigned CircleHead (ASM) and RA (HQ) users
CREATE TABLE dbo.BDP_StateMappings
(
    Id                  UNIQUEIDENTIFIER    NOT NULL,
    State               NVARCHAR(100)       NOT NULL,
    CircleHeadUserId    UNIQUEIDENTIFIER    NULL,   -- Logical FK -> BDP_Users.Id (CircleHead/ASM role)
    RAUserId            UNIQUEIDENTIFIER    NULL,   -- Logical FK -> BDP_Users.Id (RA/HQ role)
    IsActive            BIT                 NOT NULL,
    IsDeleted           BIT                 NOT NULL,
    CreatedAt           DATETIME2           NOT NULL,
    UpdatedAt           DATETIME2           NULL,
    CreatedBy           NVARCHAR(256)       NULL,
    UpdatedBy           NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = ROUND_ROBIN,
    CLUSTERED COLUMNSTORE INDEX
);

-- Dealers: Dealer master data (replaces old DealerCode/DealerName on StateMapping)
CREATE TABLE dbo.BDP_Dealers
(
    Id              UNIQUEIDENTIFIER    NOT NULL,
    DealerCode      NVARCHAR(50)        NOT NULL,
    DealerName      NVARCHAR(200)       NOT NULL,
    State           NVARCHAR(100)       NOT NULL,
    City            NVARCHAR(100)       NULL,
    IsActive        BIT                 NOT NULL,
    IsDeleted       BIT                 NOT NULL,
    CreatedAt       DATETIME2           NOT NULL,
    UpdatedAt       DATETIME2           NULL,
    CreatedBy       NVARCHAR(256)       NULL,
    UpdatedBy       NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = ROUND_ROBIN,
    CLUSTERED COLUMNSTORE INDEX
);

-- StateCities: Valid state/city combinations for dropdown population
CREATE TABLE dbo.BDP_StateCities
(
    Id              UNIQUEIDENTIFIER    NOT NULL,
    State           NVARCHAR(100)       NOT NULL,
    City            NVARCHAR(100)       NOT NULL,
    IsActive        BIT                 NOT NULL,
    IsDeleted       BIT                 NOT NULL,
    CreatedAt       DATETIME2           NOT NULL,
    UpdatedAt       DATETIME2           NULL,
    CreatedBy       NVARCHAR(256)       NULL,
    UpdatedBy       NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = ROUND_ROBIN,
    CLUSTERED COLUMNSTORE INDEX
);

-- =============================================
-- PART 1: CORE ENTITY TABLES
-- =============================================

-- Agencies: Supplier/Agency entities
CREATE TABLE dbo.BDP_Agencies
(
    Id              UNIQUEIDENTIFIER    NOT NULL,
    SupplierCode    NVARCHAR(100)       NOT NULL,
    SupplierName    NVARCHAR(256)       NOT NULL,
    IsDeleted       BIT                 NOT NULL,
    CreatedAt       DATETIME2           NOT NULL,
    UpdatedAt       DATETIME2           NULL,
    CreatedBy       NVARCHAR(256)       NULL,
    UpdatedBy       NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = ROUND_ROBIN,
    CLUSTERED COLUMNSTORE INDEX
);

-- Users: System users with role-based access
-- Role: 0=Agency, 1=CircleHead(ASM), 2=RA(HQ), 3=Admin
-- Logical FK: AgencyId -> BDP_Agencies.Id
CREATE TABLE dbo.BDP_Users
(
    Id              UNIQUEIDENTIFIER    NOT NULL,
    Email           NVARCHAR(256)       NOT NULL,
    PasswordHash    NVARCHAR(512)       NOT NULL,
    FullName        NVARCHAR(256)       NOT NULL,
    Role            INT                 NOT NULL,
    AgencyId        UNIQUEIDENTIFIER    NULL,
    PhoneNumber     NVARCHAR(20)        NULL,
    IsActive        BIT                 NOT NULL,
    LastLoginAt     DATETIME2           NULL,
    IsDeleted       BIT                 NOT NULL,
    CreatedAt       DATETIME2           NOT NULL,
    UpdatedAt       DATETIME2           NULL,
    CreatedBy       NVARCHAR(256)       NULL,
    UpdatedBy       NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = ROUND_ROBIN,
    CLUSTERED COLUMNSTORE INDEX
);

-- SubmissionSequences: Tracks last used submission number per year (CIQ-YYYY-XXXXX format)
CREATE TABLE dbo.BDP_SubmissionSequences
(
    Year        INT     NOT NULL,
    LastNumber  INT     NOT NULL
)
WITH
(
    DISTRIBUTION = ROUND_ROBIN,
    CLUSTERED COLUMNSTORE INDEX
);

-- DocumentPackages: Main submission package entity
-- AssignedCircleHeadUserId: set at submission time (CircleHead/ASM for the agency's state)
-- AssignedRAUserId: set when CircleHead approves (RA/HQ for the state)
-- Logical FK: AgencyId -> BDP_Agencies.Id, SubmittedByUserId -> BDP_Users.Id
CREATE TABLE dbo.BDP_DocumentPackages
(
    Id                          UNIQUEIDENTIFIER    NOT NULL,
    AgencyId                    UNIQUEIDENTIFIER    NOT NULL,
    SubmittedByUserId           UNIQUEIDENTIFIER    NOT NULL,
    SubmissionNumber            NVARCHAR(20)        NULL,
    VersionNumber               INT                 NOT NULL,
    State                       INT                 NOT NULL,
    CurrentStep                 INT                 NOT NULL,
    ActivityState               NVARCHAR(100)       NULL,
    AssignedCircleHeadUserId    UNIQUEIDENTIFIER    NULL,
    AssignedRAUserId            UNIQUEIDENTIFIER    NULL,
    SelectedPOId                UNIQUEIDENTIFIER    NULL,
    IsDeleted                   BIT                 NOT NULL,
    CreatedAt                   DATETIME2           NOT NULL,
    UpdatedAt                   DATETIME2           NULL,
    CreatedBy                   NVARCHAR(256)       NULL,
    UpdatedBy                   NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = HASH(AgencyId),
    CLUSTERED COLUMNSTORE INDEX
);
