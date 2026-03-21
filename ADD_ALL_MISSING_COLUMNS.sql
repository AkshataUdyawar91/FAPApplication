-- =============================================
-- Script: ADD_ALL_MISSING_COLUMNS.sql
-- Purpose: Comprehensive catch-up script to add ALL missing columns
--          across all tables after merge. Safe to run multiple times (idempotent).
-- Date: 2026-03-20
-- Tables affected: Notifications, RequestApprovalHistory, Users,
--                  Teams, TeamPhotos, StateMappings, ValidationResults,
--                  EmailDeliveryLogs
-- =============================================

PRINT '=== Starting comprehensive column catch-up script ===';
PRINT '';

-- =============================================
-- 1. Notifications — multi-channel delivery tracking
-- =============================================
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Notifications' AND COLUMN_NAME = 'Channel')
BEGIN
    ALTER TABLE [Notifications] ADD [Channel] int NOT NULL DEFAULT 1;
    PRINT 'Added Notifications.Channel (default: 1 = InApp)';
END
ELSE PRINT 'Notifications.Channel already exists — skipping';

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Notifications' AND COLUMN_NAME = 'DeliveryStatus')
BEGIN
    ALTER TABLE [Notifications] ADD [DeliveryStatus] int NOT NULL DEFAULT 2;
    PRINT 'Added Notifications.DeliveryStatus (default: 2 = Sent)';
END
ELSE PRINT 'Notifications.DeliveryStatus already exists — skipping';

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Notifications' AND COLUMN_NAME = 'RetryCount')
BEGIN
    ALTER TABLE [Notifications] ADD [RetryCount] int NOT NULL DEFAULT 0;
    PRINT 'Added Notifications.RetryCount';
END
ELSE PRINT 'Notifications.RetryCount already exists — skipping';

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Notifications' AND COLUMN_NAME = 'SentAt')
BEGIN
    ALTER TABLE [Notifications] ADD [SentAt] datetime2 NULL;
    PRINT 'Added Notifications.SentAt';
END
ELSE PRINT 'Notifications.SentAt already exists — skipping';

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Notifications' AND COLUMN_NAME = 'ExternalMessageId')
BEGIN
    ALTER TABLE [Notifications] ADD [ExternalMessageId] nvarchar(500) NULL;
    PRINT 'Added Notifications.ExternalMessageId';
END
ELSE PRINT 'Notifications.ExternalMessageId already exists — skipping';

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Notifications' AND COLUMN_NAME = 'FailureReason')
BEGIN
    ALTER TABLE [Notifications] ADD [FailureReason] nvarchar(2000) NULL;
    PRINT 'Added Notifications.FailureReason';
END
ELSE PRINT 'Notifications.FailureReason already exists — skipping';

-- Notification composite indexes
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Notifications_UserId_Channel_DeliveryStatus')
BEGIN
    CREATE INDEX [IX_Notifications_UserId_Channel_DeliveryStatus]
    ON [Notifications] ([UserId], [Channel], [DeliveryStatus]);
    PRINT 'Created index IX_Notifications_UserId_Channel_DeliveryStatus';
END
ELSE PRINT 'Index IX_Notifications_UserId_Channel_DeliveryStatus already exists — skipping';

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Notifications_RelatedEntityId_Channel')
BEGIN
    CREATE INDEX [IX_Notifications_RelatedEntityId_Channel]
    ON [Notifications] ([RelatedEntityId], [Channel]);
    PRINT 'Created index IX_Notifications_RelatedEntityId_Channel';
END
ELSE PRINT 'Index IX_Notifications_RelatedEntityId_Channel already exists — skipping';

PRINT '';

-- =============================================
-- 2. RequestApprovalHistory — Channel column
-- =============================================
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'RequestApprovalHistory' AND COLUMN_NAME = 'Channel')
BEGIN
    ALTER TABLE [RequestApprovalHistory] ADD [Channel] nvarchar(50) NULL;
    PRINT 'Added RequestApprovalHistory.Channel';
END
ELSE PRINT 'RequestApprovalHistory.Channel already exists — skipping';

PRINT '';

-- =============================================
-- 3. Users — AadObjectId column
-- =============================================
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Users' AND COLUMN_NAME = 'AadObjectId')
BEGIN
    ALTER TABLE [Users] ADD [AadObjectId] nvarchar(256) NULL;
    PRINT 'Added Users.AadObjectId';
END
ELSE PRINT 'Users.AadObjectId already exists — skipping';

PRINT '';

-- =============================================
-- 4. Teams — TeamNumber column
-- =============================================
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Teams' AND COLUMN_NAME = 'TeamNumber')
BEGIN
    ALTER TABLE [Teams] ADD [TeamNumber] int NULL;
    PRINT 'Added Teams.TeamNumber';
END
ELSE PRINT 'Teams.TeamNumber already exists — skipping';

PRINT '';

-- =============================================
-- 5. TeamPhotos — missing columns + Caption widening
-- =============================================
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'TeamPhotos' AND COLUMN_NAME = 'BlueTshirtPresent')
BEGIN
    ALTER TABLE [TeamPhotos] ADD [BlueTshirtPresent] bit NULL;
    PRINT 'Added TeamPhotos.BlueTshirtPresent';
END
ELSE PRINT 'TeamPhotos.BlueTshirtPresent already exists — skipping';

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'TeamPhotos' AND COLUMN_NAME = 'DateVisible')
BEGIN
    ALTER TABLE [TeamPhotos] ADD [DateVisible] bit NULL;
    PRINT 'Added TeamPhotos.DateVisible';
END
ELSE PRINT 'TeamPhotos.DateVisible already exists — skipping';

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'TeamPhotos' AND COLUMN_NAME = 'PhotoDateOverlay')
BEGIN
    ALTER TABLE [TeamPhotos] ADD [PhotoDateOverlay] nvarchar(100) NULL;
    PRINT 'Added TeamPhotos.PhotoDateOverlay';
END
ELSE PRINT 'TeamPhotos.PhotoDateOverlay already exists — skipping';

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'TeamPhotos' AND COLUMN_NAME = 'ThreeWheelerPresent')
BEGIN
    ALTER TABLE [TeamPhotos] ADD [ThreeWheelerPresent] bit NULL;
    PRINT 'Added TeamPhotos.ThreeWheelerPresent';
END
ELSE PRINT 'TeamPhotos.ThreeWheelerPresent already exists — skipping';

-- Widen Caption from nvarchar(1000) to nvarchar(max) for EXIF metadata JSON
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'TeamPhotos' AND COLUMN_NAME = 'Caption'
      AND CHARACTER_MAXIMUM_LENGTH <> -1
)
BEGIN
    ALTER TABLE [TeamPhotos] ALTER COLUMN [Caption] NVARCHAR(MAX) NULL;
    PRINT 'Widened TeamPhotos.Caption to NVARCHAR(MAX)';
END
ELSE PRINT 'TeamPhotos.Caption already NVARCHAR(MAX) — skipping';

PRINT '';

-- =============================================
-- 6. StateMappings — missing columns
-- =============================================
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'StateMappings' AND COLUMN_NAME = 'City')
BEGIN
    ALTER TABLE [StateMappings] ADD [City] nvarchar(max) NULL;
    PRINT 'Added StateMappings.City';
END
ELSE PRINT 'StateMappings.City already exists — skipping';

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'StateMappings' AND COLUMN_NAME = 'DealerCode')
BEGIN
    ALTER TABLE [StateMappings] ADD [DealerCode] nvarchar(max) NULL;
    PRINT 'Added StateMappings.DealerCode';
END
ELSE PRINT 'StateMappings.DealerCode already exists — skipping';

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'StateMappings' AND COLUMN_NAME = 'DealerName')
BEGIN
    ALTER TABLE [StateMappings] ADD [DealerName] nvarchar(max) NULL;
    PRINT 'Added StateMappings.DealerName';
END
ELSE PRINT 'StateMappings.DealerName already exists — skipping';

PRINT '';

-- =============================================
-- 7. ValidationResults — ValidationDetailsJson
-- =============================================
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'ValidationResults' AND COLUMN_NAME = 'ValidationDetailsJson')
BEGIN
    ALTER TABLE [ValidationResults] ADD [ValidationDetailsJson] nvarchar(max) NULL;
    PRINT 'Added ValidationResults.ValidationDetailsJson';
END
ELSE PRINT 'ValidationResults.ValidationDetailsJson already exists — skipping';

PRINT '';

-- =============================================
-- 8. EmailDeliveryLogs table
-- =============================================
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'EmailDeliveryLogs')
BEGIN
    CREATE TABLE [EmailDeliveryLogs] (
        [Id] uniqueidentifier NOT NULL,
        [PackageId] uniqueidentifier NOT NULL,
        [RecipientEmail] nvarchar(2000) NOT NULL,
        [TemplateName] nvarchar(100) NOT NULL,
        [Subject] nvarchar(500) NOT NULL,
        [Success] bit NOT NULL,
        [MessageId] nvarchar(200) NULL,
        [ErrorMessage] nvarchar(2000) NULL,
        [AttemptsCount] int NOT NULL,
        [SentAt] datetime2 NOT NULL,
        [CreatedAt] datetime2 NOT NULL,
        [UpdatedAt] datetime2 NULL,
        [CreatedBy] nvarchar(max) NULL,
        [UpdatedBy] nvarchar(max) NULL,
        [IsDeleted] bit NOT NULL,
        CONSTRAINT [PK_EmailDeliveryLogs] PRIMARY KEY ([Id])
    );
    CREATE INDEX [IX_EmailDeliveryLogs_PackageId] ON [EmailDeliveryLogs] ([PackageId]);
    CREATE INDEX [IX_EmailDeliveryLogs_TemplateName] ON [EmailDeliveryLogs] ([TemplateName]);
    PRINT 'Created EmailDeliveryLogs table with indexes';
END
ELSE PRINT 'EmailDeliveryLogs table already exists — skipping';

PRINT '';

-- =============================================
-- 9. TeamsConversations table
-- =============================================
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'TeamsConversations')
BEGIN
    CREATE TABLE [TeamsConversations] (
        [Id] uniqueidentifier NOT NULL,
        [UserId] uniqueidentifier NULL,
        [TeamsUserId] nvarchar(256) NOT NULL,
        [TeamsUserName] nvarchar(max) NOT NULL,
        [ConversationId] nvarchar(256) NOT NULL,
        [ServiceUrl] nvarchar(512) NOT NULL,
        [ChannelId] nvarchar(64) NOT NULL,
        [BotId] nvarchar(max) NOT NULL,
        [BotName] nvarchar(max) NOT NULL,
        [TenantId] nvarchar(max) NULL,
        [ConversationReferenceJson] nvarchar(max) NOT NULL,
        [IsActive] bit NOT NULL DEFAULT 1,
        [LastActivityAt] datetime2 NULL,
        [LastMessageSentAt] datetime2 NULL,
        [CreatedAt] datetime2 NOT NULL,
        [UpdatedAt] datetime2 NULL,
        [CreatedBy] nvarchar(max) NULL,
        [UpdatedBy] nvarchar(max) NULL,
        [IsDeleted] bit NOT NULL DEFAULT 0,
        CONSTRAINT [PK_TeamsConversations] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_TeamsConversations_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users]([Id]) ON DELETE SET NULL
    );
    CREATE INDEX [IX_TeamsConversations_TeamsUserId] ON [TeamsConversations] ([TeamsUserId]);
    CREATE INDEX [IX_TeamsConversations_ConversationId] ON [TeamsConversations] ([ConversationId]);
    CREATE INDEX [IX_TeamsConversations_UserId] ON [TeamsConversations] ([UserId]) WHERE IsActive = 1;
    PRINT 'Created TeamsConversations table with indexes';
END
ELSE PRINT 'TeamsConversations table already exists — skipping';

PRINT '';

-- =============================================
-- 10. CampaignInvoices table
-- =============================================
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CampaignInvoices')
BEGIN
    CREATE TABLE [CampaignInvoices] (
        [Id] uniqueidentifier NOT NULL,
        [CampaignId] uniqueidentifier NOT NULL,
        [PackageId] uniqueidentifier NOT NULL,
        [InvoiceNumber] nvarchar(100) NULL,
        [InvoiceDate] datetime2 NULL,
        [VendorName] nvarchar(500) NULL,
        [GSTNumber] nvarchar(50) NULL,
        [SubTotal] decimal(18,2) NULL,
        [TaxAmount] decimal(18,2) NULL,
        [TotalAmount] decimal(18,2) NULL,
        [FileName] nvarchar(500) NOT NULL,
        [BlobUrl] nvarchar(2000) NOT NULL,
        [FileSizeBytes] bigint NOT NULL,
        [ContentType] nvarchar(100) NOT NULL,
        [ExtractedDataJson] nvarchar(max) NULL,
        [ExtractionConfidence] float NULL,
        [IsFlaggedForReview] bit NOT NULL DEFAULT 0,
        [CreatedAt] datetime2 NOT NULL,
        [UpdatedAt] datetime2 NULL,
        [CreatedBy] nvarchar(max) NULL,
        [UpdatedBy] nvarchar(max) NULL,
        [IsDeleted] bit NOT NULL DEFAULT 0,
        CONSTRAINT [PK_CampaignInvoices] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_CampaignInvoices_Teams_CampaignId] FOREIGN KEY ([CampaignId]) REFERENCES [Teams]([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_CampaignInvoices_DocumentPackages_PackageId] FOREIGN KEY ([PackageId]) REFERENCES [DocumentPackages]([Id]) ON DELETE CASCADE
    );
    CREATE INDEX [IX_CampaignInvoices_CampaignId] ON [CampaignInvoices] ([CampaignId]);
    CREATE INDEX [IX_CampaignInvoices_InvoiceNumber] ON [CampaignInvoices] ([InvoiceNumber]);
    CREATE INDEX [IX_CampaignInvoices_PackageId] ON [CampaignInvoices] ([PackageId]);
    PRINT 'Created CampaignInvoices table with indexes';
END
ELSE PRINT 'CampaignInvoices table already exists — skipping';

PRINT '';
PRINT '=== Comprehensive column catch-up script complete ===';
