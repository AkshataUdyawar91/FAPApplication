-- =============================================
-- PART 2: DOCUMENT ENTITY TABLES
-- Target: Azure Synapse Analytics Dedicated SQL Pool
-- Database: Balsynwsdev | Prefix: BDP_
-- =============================================

-- POs: Purchase Order documents (one per package)
-- Added: VendorCode, POStatus, RemainingBalance, RefreshedAt
-- Logical FK: PackageId -> BDP_DocumentPackages.Id, AgencyId -> BDP_Agencies.Id
CREATE TABLE dbo.BDP_POs
(
    Id                      UNIQUEIDENTIFIER    NOT NULL,
    PackageId               UNIQUEIDENTIFIER    NOT NULL,
    AgencyId                UNIQUEIDENTIFIER    NOT NULL,
    PONumber                NVARCHAR(100)       NULL,
    PODate                  DATETIME2           NULL,
    VendorName              NVARCHAR(500)       NULL,
    VendorCode              NVARCHAR(50)        NULL,
    TotalAmount             DECIMAL(18, 2)      NULL,
    RemainingBalance        DECIMAL(18, 2)      NULL,
    POStatus                NVARCHAR(50)        NULL,
    RefreshedAt             DATETIME2           NULL,
    FileName                NVARCHAR(500)       NOT NULL,
    BlobUrl                 NVARCHAR(2000)      NOT NULL,
    FileSizeBytes           BIGINT              NOT NULL,
    ContentType             NVARCHAR(200)       NOT NULL,
    ExtractedDataJson       NVARCHAR(4000)      NULL,
    ExtractionConfidence    FLOAT               NULL,
    IsFlaggedForReview      BIT                 NOT NULL,
    VersionNumber           INT                 NOT NULL,
    IsDeleted               BIT                 NOT NULL,
    CreatedAt               DATETIME2           NOT NULL,
    UpdatedAt               DATETIME2           NULL,
    CreatedBy               NVARCHAR(256)       NULL,
    UpdatedBy               NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = HASH(PackageId),
    CLUSTERED COLUMNSTORE INDEX
);

-- POSyncLogs: Audit log for PO sync operations from SAP/external source
-- Logical FK: POId -> BDP_POs.Id, AgencyId -> BDP_Agencies.Id
CREATE TABLE dbo.BDP_POSyncLogs
(
    Id              UNIQUEIDENTIFIER    NOT NULL,
    POId            UNIQUEIDENTIFIER    NULL,
    AgencyId        UNIQUEIDENTIFIER    NULL,
    FileName        NVARCHAR(500)       NOT NULL,
    SourceSystem    NVARCHAR(200)       NOT NULL,
    Status          NVARCHAR(100)       NOT NULL,
    ImportedRecords NVARCHAR(4000)      NULL,
    ErrorMessage    NVARCHAR(4000)      NULL,
    ProcessedAt     DATETIME2           NOT NULL,
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

-- POBalanceLogs: Audit log for every PO balance check call to SAP
CREATE TABLE dbo.BDP_POBalanceLogs
(
    Id              UNIQUEIDENTIFIER    NOT NULL,
    PoNum           NVARCHAR(50)        NOT NULL,
    CompanyCode     NVARCHAR(20)        NOT NULL,
    Balance         DECIMAL(18, 2)      NULL,
    Currency        NVARCHAR(10)        NULL,
    IsSuccess       BIT                 NOT NULL,
    ErrorMessage    NVARCHAR(4000)      NULL,
    RequestedBy     NVARCHAR(450)       NULL,
    CorrelationId   NVARCHAR(100)       NULL,
    RequestedAt     DATETIME2           NOT NULL,
    SapCalledAt     DATETIME2           NULL,
    SapRespondedAt  DATETIME2           NULL,
    SapHttpStatus   INT                 NULL,
    SapRequestBody  NVARCHAR(4000)      NULL,
    SapResponseBody NVARCHAR(4000)      NULL,
    ElapsedMs       BIGINT              NOT NULL
)
WITH
(
    DISTRIBUTION = ROUND_ROBIN,
    CLUSTERED COLUMNSTORE INDEX
);

-- CostSummaries: Cost summary documents (one per package)
-- Removed: CostBreakdownJson
-- Added: ElementWiseCostsJson, ElementWiseQuantityJson, NumberOfActivations, NumberOfDays, NumberOfTeams, PlaceOfSupply
-- Logical FK: PackageId -> BDP_DocumentPackages.Id
CREATE TABLE dbo.BDP_CostSummaries
(
    Id                      UNIQUEIDENTIFIER    NOT NULL,
    PackageId               UNIQUEIDENTIFIER    NOT NULL,
    TotalCost               DECIMAL(18, 2)      NULL,
    ElementWiseCostsJson    NVARCHAR(4000)      NULL,
    ElementWiseQuantityJson NVARCHAR(4000)      NULL,
    NumberOfActivations     INT                 NULL,
    NumberOfDays            INT                 NULL,
    NumberOfTeams           INT                 NULL,
    PlaceOfSupply           NVARCHAR(500)       NULL,
    FileName                NVARCHAR(500)       NOT NULL,
    BlobUrl                 NVARCHAR(2000)      NOT NULL,
    FileSizeBytes           BIGINT              NOT NULL,
    ContentType             NVARCHAR(200)       NOT NULL,
    ExtractedDataJson       NVARCHAR(4000)      NULL,
    ExtractionConfidence    FLOAT               NULL,
    IsFlaggedForReview      BIT                 NOT NULL,
    VersionNumber           INT                 NOT NULL,
    IsDeleted               BIT                 NOT NULL,
    CreatedAt               DATETIME2           NOT NULL,
    UpdatedAt               DATETIME2           NULL,
    CreatedBy               NVARCHAR(256)       NULL,
    UpdatedBy               NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = HASH(PackageId),
    CLUSTERED COLUMNSTORE INDEX
);

-- ActivitySummaries: Activity summary documents (one per package)
-- Added: DealerName, TotalDays, TotalWorkingDays
-- Logical FK: PackageId -> BDP_DocumentPackages.Id
CREATE TABLE dbo.BDP_ActivitySummaries
(
    Id                      UNIQUEIDENTIFIER    NOT NULL,
    PackageId               UNIQUEIDENTIFIER    NOT NULL,
    ActivityDescription     NVARCHAR(2000)      NULL,
    DealerName              NVARCHAR(500)       NULL,
    TotalDays               INT                 NULL,
    TotalWorkingDays        INT                 NULL,
    FileName                NVARCHAR(500)       NOT NULL,
    BlobUrl                 NVARCHAR(2000)      NOT NULL,
    FileSizeBytes           BIGINT              NOT NULL,
    ContentType             NVARCHAR(200)       NOT NULL,
    ExtractedDataJson       NVARCHAR(4000)      NULL,
    ExtractionConfidence    FLOAT               NULL,
    IsFlaggedForReview      BIT                 NOT NULL,
    VersionNumber           INT                 NOT NULL,
    IsDeleted               BIT                 NOT NULL,
    CreatedAt               DATETIME2           NOT NULL,
    UpdatedAt               DATETIME2           NULL,
    CreatedBy               NVARCHAR(256)       NULL,
    UpdatedBy               NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = HASH(PackageId),
    CLUSTERED COLUMNSTORE INDEX
);

-- EnquiryDocuments: Enquiry documents (one per package)
-- Logical FK: PackageId -> BDP_DocumentPackages.Id
CREATE TABLE dbo.BDP_EnquiryDocuments
(
    Id                      UNIQUEIDENTIFIER    NOT NULL,
    PackageId               UNIQUEIDENTIFIER    NOT NULL,
    FileName                NVARCHAR(500)       NOT NULL,
    BlobUrl                 NVARCHAR(2000)      NOT NULL,
    FileSizeBytes           BIGINT              NOT NULL,
    ContentType             NVARCHAR(200)       NOT NULL,
    ExtractedDataJson       NVARCHAR(4000)      NULL,
    ExtractionConfidence    FLOAT               NULL,
    IsFlaggedForReview      BIT                 NOT NULL,
    VersionNumber           INT                 NOT NULL,
    IsDeleted               BIT                 NOT NULL,
    CreatedAt               DATETIME2           NOT NULL,
    UpdatedAt               DATETIME2           NULL,
    CreatedBy               NVARCHAR(256)       NULL,
    UpdatedBy               NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = HASH(PackageId),
    CLUSTERED COLUMNSTORE INDEX
);

-- AdditionalDocuments: Supporting documents (multiple per package)
-- Logical FK: PackageId -> BDP_DocumentPackages.Id
CREATE TABLE dbo.BDP_AdditionalDocuments
(
    Id                  UNIQUEIDENTIFIER    NOT NULL,
    PackageId           UNIQUEIDENTIFIER    NOT NULL,
    DocumentType        NVARCHAR(100)       NOT NULL,
    Description         NVARCHAR(500)       NULL,
    FileName            NVARCHAR(255)       NOT NULL,
    BlobUrl             NVARCHAR(1000)      NOT NULL,
    FileSizeBytes       BIGINT              NOT NULL,
    ContentType         NVARCHAR(100)       NOT NULL,
    VersionNumber       INT                 NOT NULL,
    IsDeleted           BIT                 NOT NULL,
    CreatedAt           DATETIME2           NOT NULL,
    UpdatedAt           DATETIME2           NULL,
    CreatedBy           NVARCHAR(256)       NULL,
    UpdatedBy           NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = HASH(PackageId),
    CLUSTERED COLUMNSTORE INDEX
);

-- Invoices: Invoice documents (multiple per package)
-- Logical FK: PackageId -> BDP_DocumentPackages.Id, POId -> BDP_POs.Id
CREATE TABLE dbo.BDP_Invoices
(
    Id                      UNIQUEIDENTIFIER    NOT NULL,
    PackageId               UNIQUEIDENTIFIER    NOT NULL,
    POId                    UNIQUEIDENTIFIER    NOT NULL,
    VersionNumber           INT                 NOT NULL,
    InvoiceNumber           NVARCHAR(100)       NULL,
    InvoiceDate             DATETIME2           NULL,
    VendorName              NVARCHAR(500)       NULL,
    GSTNumber               NVARCHAR(50)        NULL,
    SubTotal                DECIMAL(18, 2)      NULL,
    TaxAmount               DECIMAL(18, 2)      NULL,
    TotalAmount             DECIMAL(18, 2)      NULL,
    FileName                NVARCHAR(512)       NOT NULL,
    BlobUrl                 NVARCHAR(2048)      NOT NULL,
    FileSizeBytes           BIGINT              NOT NULL,
    ContentType             NVARCHAR(128)       NOT NULL,
    ExtractedDataJson       NVARCHAR(4000)      NULL,
    ExtractionConfidence    FLOAT               NULL,
    IsFlaggedForReview      BIT                 NOT NULL,
    IsDeleted               BIT                 NOT NULL,
    CreatedAt               DATETIME2           NOT NULL,
    UpdatedAt               DATETIME2           NULL,
    CreatedBy               NVARCHAR(256)       NULL,
    UpdatedBy               NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = HASH(PackageId),
    CLUSTERED COLUMNSTORE INDEX
);

-- Teams: Campaign/Team entities (multiple per package)
-- Removed: TeamsJson (dropped from domain)
-- Logical FK: PackageId -> BDP_DocumentPackages.Id
CREATE TABLE dbo.BDP_Teams
(
    Id                  UNIQUEIDENTIFIER    NOT NULL,
    PackageId           UNIQUEIDENTIFIER    NOT NULL,
    CampaignName        NVARCHAR(500)       NULL,
    TeamCode            NVARCHAR(100)       NULL,
    StartDate           DATETIME2           NULL,
    EndDate             DATETIME2           NULL,
    WorkingDays         INT                 NULL,
    DealershipName      NVARCHAR(500)       NULL,
    DealershipAddress   NVARCHAR(1000)      NULL,
    GPSLocation         NVARCHAR(100)       NULL,
    State               NVARCHAR(100)       NULL,
    VersionNumber       INT                 NOT NULL,
    IsDeleted           BIT                 NOT NULL,
    CreatedAt           DATETIME2           NOT NULL,
    UpdatedAt           DATETIME2           NULL,
    CreatedBy           NVARCHAR(256)       NULL,
    UpdatedBy           NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = HASH(PackageId),
    CLUSTERED COLUMNSTORE INDEX
);

-- TeamPhotos: Photos linked to Teams (multiple per team)
-- Logical FK: TeamId -> BDP_Teams.Id, PackageId -> BDP_DocumentPackages.Id
CREATE TABLE dbo.BDP_TeamPhotos
(
    Id                      UNIQUEIDENTIFIER    NOT NULL,
    TeamId                  UNIQUEIDENTIFIER    NOT NULL,
    PackageId               UNIQUEIDENTIFIER    NOT NULL,
    FileName                NVARCHAR(500)       NOT NULL,
    BlobUrl                 NVARCHAR(2000)      NOT NULL,
    FileSizeBytes           BIGINT              NOT NULL,
    ContentType             NVARCHAR(100)       NOT NULL,
    Caption                 NVARCHAR(1000)      NULL,
    PhotoTimestamp          DATETIME2           NULL,
    Latitude                FLOAT               NULL,
    Longitude               FLOAT               NULL,
    DeviceModel             NVARCHAR(200)       NULL,
    ExtractedMetadataJson   NVARCHAR(4000)      NULL,
    ExtractionConfidence    FLOAT               NULL,
    IsFlaggedForReview      BIT                 NOT NULL,
    DisplayOrder            INT                 NOT NULL,
    VersionNumber           INT                 NOT NULL,
    IsDeleted               BIT                 NOT NULL,
    CreatedAt               DATETIME2           NOT NULL,
    UpdatedAt               DATETIME2           NULL,
    CreatedBy               NVARCHAR(256)       NULL,
    UpdatedBy               NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = HASH(PackageId),
    CLUSTERED COLUMNSTORE INDEX
);
