-- =============================================
-- Fix: Add missing Notifications columns + Create CampaignInvoices table
-- Date: 2026-03-20
-- Purpose: Sync database schema with EF Core entity model
-- Issues fixed:
--   1. Notifications table missing: Channel, DeliveryStatus, ExternalMessageId, FailureReason, SentAt, RetryCount
--   2. CampaignInvoices table does not exist
-- =============================================

BEGIN TRANSACTION;

BEGIN TRY

    -- =============================================
    -- PART 1: Add missing columns to Notifications
    -- =============================================

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'Notifications' AND COLUMN_NAME = 'Channel'
    )
    BEGIN
        ALTER TABLE [Notifications] ADD [Channel] INT NOT NULL DEFAULT 1;
        PRINT 'Added Column: Notifications.Channel (default InApp=1)';
    END
    ELSE PRINT 'Column Notifications.Channel already exists — skipping';

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'Notifications' AND COLUMN_NAME = 'DeliveryStatus'
    )
    BEGIN
        ALTER TABLE [Notifications] ADD [DeliveryStatus] INT NOT NULL DEFAULT 2;
        PRINT 'Added Column: Notifications.DeliveryStatus (default Sent=2)';
    END
    ELSE PRINT 'Column Notifications.DeliveryStatus already exists — skipping';

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'Notifications' AND COLUMN_NAME = 'RetryCount'
    )
    BEGIN
        ALTER TABLE [Notifications] ADD [RetryCount] INT NOT NULL DEFAULT 0;
        PRINT 'Added Column: Notifications.RetryCount (default 0)';
    END
    ELSE PRINT 'Column Notifications.RetryCount already exists — skipping';

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'Notifications' AND COLUMN_NAME = 'SentAt'
    )
    BEGIN
        ALTER TABLE [Notifications] ADD [SentAt] DATETIME2 NULL;
        PRINT 'Added Column: Notifications.SentAt';
    END
    ELSE PRINT 'Column Notifications.SentAt already exists — skipping';

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'Notifications' AND COLUMN_NAME = 'ExternalMessageId'
    )
    BEGIN
        ALTER TABLE [Notifications] ADD [ExternalMessageId] NVARCHAR(500) NULL;
        PRINT 'Added Column: Notifications.ExternalMessageId';
    END
    ELSE PRINT 'Column Notifications.ExternalMessageId already exists — skipping';

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'Notifications' AND COLUMN_NAME = 'FailureReason'
    )
    BEGIN
        ALTER TABLE [Notifications] ADD [FailureReason] NVARCHAR(2000) NULL;
        PRINT 'Added Column: Notifications.FailureReason';
    END
    ELSE PRINT 'Column Notifications.FailureReason already exists — skipping';

    -- =============================================
    -- PART 2: Create CampaignInvoices table
    -- =============================================

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_NAME = 'CampaignInvoices'
    )
    BEGIN
        CREATE TABLE [CampaignInvoices] (
            [Id]                   UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
            [CampaignId]           UNIQUEIDENTIFIER NOT NULL,
            [PackageId]            UNIQUEIDENTIFIER NOT NULL,
            [InvoiceNumber]        NVARCHAR(256)    NULL,
            [InvoiceDate]          DATETIME2        NULL,
            [VendorName]           NVARCHAR(500)    NULL,
            [GSTNumber]            NVARCHAR(256)    NULL,
            [SubTotal]             DECIMAL(18,2)    NULL,
            [TaxAmount]            DECIMAL(18,2)    NULL,
            [TotalAmount]          DECIMAL(18,2)    NULL,
            [FileName]             NVARCHAR(500)    NOT NULL DEFAULT N'',
            [BlobUrl]              NVARCHAR(2000)   NOT NULL DEFAULT N'',
            [FileSizeBytes]        BIGINT           NOT NULL DEFAULT 0,
            [ContentType]          NVARCHAR(256)    NOT NULL DEFAULT N'',
            [ExtractedDataJson]    NVARCHAR(MAX)    NULL,
            [ExtractionConfidence] FLOAT            NULL,
            [IsFlaggedForReview]   BIT              NOT NULL DEFAULT 0,
            [CreatedAt]            DATETIME2        NOT NULL DEFAULT GETUTCDATE(),
            [UpdatedAt]            DATETIME2        NULL,
            [CreatedBy]            NVARCHAR(256)    NULL,
            [UpdatedBy]            NVARCHAR(256)    NULL,
            [IsDeleted]            BIT              NOT NULL DEFAULT 0,
            CONSTRAINT [PK_CampaignInvoices] PRIMARY KEY ([Id]),
            CONSTRAINT [FK_CampaignInvoices_Teams] FOREIGN KEY ([CampaignId])
                REFERENCES [Teams] ([Id]),
            CONSTRAINT [FK_CampaignInvoices_DocumentPackages] FOREIGN KEY ([PackageId])
                REFERENCES [DocumentPackages] ([Id])
        );

        PRINT 'Created Table: CampaignInvoices';

        -- Index on foreign keys for query performance
        CREATE NONCLUSTERED INDEX [IX_CampaignInvoices_CampaignId]
            ON [CampaignInvoices] ([CampaignId]);

        CREATE NONCLUSTERED INDEX [IX_CampaignInvoices_PackageId]
            ON [CampaignInvoices] ([PackageId]);

        PRINT 'Created Indexes: IX_CampaignInvoices_CampaignId, IX_CampaignInvoices_PackageId';
    END
    ELSE PRINT 'Table CampaignInvoices already exists — skipping';

    COMMIT TRANSACTION;
    PRINT '';
    PRINT '=== Schema fix applied successfully ===';

END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
