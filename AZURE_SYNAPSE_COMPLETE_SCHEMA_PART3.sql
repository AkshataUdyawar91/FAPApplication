-- =============================================
-- PART 3: VALIDATION, SCORING, WORKFLOW, NOTIFICATION, AUDIT & CHAT TABLES
-- Target: Azure Synapse Analytics Dedicated SQL Pool
-- Database: Balsynwsdev | Prefix: BDP_
-- =============================================

-- ValidationResults: Polymorphic validation results for documents
-- Removed: ValidationDetailsJson
-- Added: RuleResultsJson (matches current domain entity)
-- Logical unique pair: DocumentType + DocumentId
CREATE TABLE dbo.BDP_ValidationResults
(
    Id                          UNIQUEIDENTIFIER    NOT NULL,
    DocumentType                INT                 NOT NULL,
    DocumentId                  UNIQUEIDENTIFIER    NOT NULL,
    SapVerificationPassed       BIT                 NOT NULL,
    AmountConsistencyPassed     BIT                 NOT NULL,
    LineItemMatchingPassed      BIT                 NOT NULL,
    CompletenessCheckPassed     BIT                 NOT NULL,
    DateValidationPassed        BIT                 NOT NULL,
    VendorMatchingPassed        BIT                 NOT NULL,
    AllValidationsPassed        BIT                 NOT NULL,
    RuleResultsJson             NVARCHAR(4000)      NULL,
    FailureReason               NVARCHAR(2000)      NULL,
    IsDeleted                   BIT                 NOT NULL,
    CreatedAt                   DATETIME2           NOT NULL,
    UpdatedAt                   DATETIME2           NULL,
    CreatedBy                   NVARCHAR(256)       NULL,
    UpdatedBy                   NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = ROUND_ROBIN,
    CLUSTERED COLUMNSTORE INDEX
);

-- ConfidenceScores: AI-generated confidence scores (one per package)
-- Weights: PO 30%, Invoice 30%, CostSummary 20%, Activity 10%, Photos 10%
-- Logical FK: PackageId -> BDP_DocumentPackages.Id
CREATE TABLE dbo.BDP_ConfidenceScores
(
    Id                          UNIQUEIDENTIFIER    NOT NULL,
    PackageId                   UNIQUEIDENTIFIER    NOT NULL,
    PoConfidence                DECIMAL(5, 2)       NOT NULL,
    InvoiceConfidence           DECIMAL(5, 2)       NOT NULL,
    CostSummaryConfidence       DECIMAL(5, 2)       NOT NULL,
    ActivityConfidence          DECIMAL(5, 2)       NOT NULL,
    PhotosConfidence            DECIMAL(5, 2)       NOT NULL,
    OverallConfidence           DECIMAL(5, 2)       NOT NULL,
    IsFlaggedForReview          BIT                 NOT NULL,
    IsDeleted                   BIT                 NOT NULL,
    CreatedAt                   DATETIME2           NOT NULL,
    UpdatedAt                   DATETIME2           NULL,
    CreatedBy                   NVARCHAR(256)       NULL,
    UpdatedBy                   NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = HASH(PackageId),
    CLUSTERED COLUMNSTORE INDEX
);

-- Recommendations: AI-generated approval recommendations (one per package)
-- Logical FK: PackageId -> BDP_DocumentPackages.Id
CREATE TABLE dbo.BDP_Recommendations
(
    Id                      UNIQUEIDENTIFIER    NOT NULL,
    PackageId               UNIQUEIDENTIFIER    NOT NULL,
    Type                    INT                 NOT NULL,
    Evidence                NVARCHAR(4000)      NOT NULL,
    ValidationIssuesJson    NVARCHAR(4000)      NULL,
    ConfidenceScore         DECIMAL(5, 2)       NOT NULL,
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

-- RequestApprovalHistory: Approval workflow history
-- ApproverRole: 1=CircleHead(ASM), 2=RA(HQ)
-- Logical FK: PackageId -> BDP_DocumentPackages.Id, ApproverId -> BDP_Users.Id
CREATE TABLE dbo.BDP_RequestApprovalHistory
(
    Id              UNIQUEIDENTIFIER    NOT NULL,
    PackageId       UNIQUEIDENTIFIER    NOT NULL,
    ApproverId      UNIQUEIDENTIFIER    NOT NULL,
    ApproverRole    INT                 NOT NULL,
    Action          INT                 NOT NULL,
    Comments        NVARCHAR(2000)      NULL,
    ActionDate      DATETIME2           NOT NULL,
    VersionNumber   INT                 NOT NULL,
    IsDeleted       BIT                 NOT NULL,
    CreatedAt       DATETIME2           NOT NULL,
    UpdatedAt       DATETIME2           NULL,
    CreatedBy       NVARCHAR(256)       NULL,
    UpdatedBy       NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = HASH(PackageId),
    CLUSTERED COLUMNSTORE INDEX
);

-- RequestComments: Comments on packages
-- Logical FK: PackageId -> BDP_DocumentPackages.Id, UserId -> BDP_Users.Id
CREATE TABLE dbo.BDP_RequestComments
(
    Id              UNIQUEIDENTIFIER    NOT NULL,
    PackageId       UNIQUEIDENTIFIER    NOT NULL,
    UserId          UNIQUEIDENTIFIER    NOT NULL,
    UserRole        INT                 NOT NULL,
    CommentText     NVARCHAR(2000)      NOT NULL,
    CommentDate     DATETIME2           NOT NULL,
    VersionNumber   INT                 NOT NULL,
    IsDeleted       BIT                 NOT NULL,
    CreatedAt       DATETIME2           NOT NULL,
    UpdatedAt       DATETIME2           NULL,
    CreatedBy       NVARCHAR(256)       NULL,
    UpdatedBy       NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = HASH(PackageId),
    CLUSTERED COLUMNSTORE INDEX
);

-- Notifications: In-app notifications for users
-- Logical FK: UserId -> BDP_Users.Id, RelatedEntityId -> BDP_DocumentPackages.Id
CREATE TABLE dbo.BDP_Notifications
(
    Id                  UNIQUEIDENTIFIER    NOT NULL,
    UserId              UNIQUEIDENTIFIER    NOT NULL,
    Type                INT                 NOT NULL,
    Title               NVARCHAR(256)       NOT NULL,
    Message             NVARCHAR(2000)      NOT NULL,
    IsRead              BIT                 NOT NULL,
    ReadAt              DATETIME2           NULL,
    RelatedEntityId     UNIQUEIDENTIFIER    NULL,
    IsDeleted           BIT                 NOT NULL,
    CreatedAt           DATETIME2           NOT NULL,
    UpdatedAt           DATETIME2           NULL,
    CreatedBy           NVARCHAR(256)       NULL,
    UpdatedBy           NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = HASH(UserId),
    CLUSTERED COLUMNSTORE INDEX
);

-- EmailDeliveryLogs: Audit record for every email send attempt
-- Logical FK: PackageId -> BDP_DocumentPackages.Id
CREATE TABLE dbo.BDP_EmailDeliveryLogs
(
    Id              UNIQUEIDENTIFIER    NOT NULL,
    PackageId       UNIQUEIDENTIFIER    NOT NULL,
    RecipientEmail  NVARCHAR(500)       NOT NULL,
    TemplateName    NVARCHAR(200)       NOT NULL,
    Subject         NVARCHAR(500)       NOT NULL,
    Success         BIT                 NOT NULL,
    MessageId       NVARCHAR(200)       NULL,
    ErrorMessage    NVARCHAR(2000)      NULL,
    AttemptsCount   INT                 NOT NULL,
    SentAt          DATETIME2           NOT NULL,
    IsDeleted       BIT                 NOT NULL,
    CreatedAt       DATETIME2           NOT NULL,
    UpdatedAt       DATETIME2           NULL,
    CreatedBy       NVARCHAR(256)       NULL,
    UpdatedBy       NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = HASH(PackageId),
    CLUSTERED COLUMNSTORE INDEX
);

-- AuditLogs: Audit trail for compliance and security
-- Note: OldValuesJson removed (dropped from domain); NewValuesJson retained
-- Logical FK: UserId -> BDP_Users.Id
CREATE TABLE dbo.BDP_AuditLogs
(
    Id              UNIQUEIDENTIFIER    NOT NULL,
    UserId          UNIQUEIDENTIFIER    NOT NULL,
    Action          NVARCHAR(128)       NOT NULL,
    EntityType      NVARCHAR(128)       NOT NULL,
    EntityId        UNIQUEIDENTIFIER    NULL,
    NewValuesJson   NVARCHAR(4000)      NULL,
    IpAddress       NVARCHAR(45)        NOT NULL,
    UserAgent       NVARCHAR(512)       NOT NULL,
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

-- Conversations: Chat conversations
-- Logical FK: UserId -> BDP_Users.Id
CREATE TABLE dbo.BDP_Conversations
(
    Id              UNIQUEIDENTIFIER    NOT NULL,
    UserId          UNIQUEIDENTIFIER    NOT NULL,
    LastMessageAt   DATETIME2           NOT NULL,
    IsDeleted       BIT                 NOT NULL,
    CreatedAt       DATETIME2           NOT NULL,
    UpdatedAt       DATETIME2           NULL,
    CreatedBy       NVARCHAR(256)       NULL,
    UpdatedBy       NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = HASH(UserId),
    CLUSTERED COLUMNSTORE INDEX
);

-- ConversationMessages: Individual messages in conversations
-- Logical FK: ConversationId -> BDP_Conversations.Id
CREATE TABLE dbo.BDP_ConversationMessages
(
    Id              UNIQUEIDENTIFIER    NOT NULL,
    ConversationId  UNIQUEIDENTIFIER    NOT NULL,
    Role            NVARCHAR(50)        NOT NULL,
    Content         NVARCHAR(4000)      NOT NULL,
    IsDeleted       BIT                 NOT NULL,
    CreatedAt       DATETIME2           NOT NULL,
    UpdatedAt       DATETIME2           NULL,
    CreatedBy       NVARCHAR(256)       NULL,
    UpdatedBy       NVARCHAR(256)       NULL
)
WITH
(
    DISTRIBUTION = HASH(ConversationId),
    CLUSTERED COLUMNSTORE INDEX
);
