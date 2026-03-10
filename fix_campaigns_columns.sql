-- Add missing columns to Campaigns table
-- The migration only created a subset; the entity has more fields

-- TeamCode
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Campaigns' AND COLUMN_NAME='TeamCode')
    ALTER TABLE [Campaigns] ADD [TeamCode] nvarchar(100) NULL;
GO

-- CostSummaryContentType
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Campaigns' AND COLUMN_NAME='CostSummaryContentType')
    ALTER TABLE [Campaigns] ADD [CostSummaryContentType] nvarchar(128) NULL;
GO

-- CostSummaryFileSizeBytes
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Campaigns' AND COLUMN_NAME='CostSummaryFileSizeBytes')
    ALTER TABLE [Campaigns] ADD [CostSummaryFileSizeBytes] bigint NULL;
GO

-- Activity Summary fields
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Campaigns' AND COLUMN_NAME='ActivitySummaryFileName')
    ALTER TABLE [Campaigns] ADD [ActivitySummaryFileName] nvarchar(512) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Campaigns' AND COLUMN_NAME='ActivitySummaryBlobUrl')
    ALTER TABLE [Campaigns] ADD [ActivitySummaryBlobUrl] nvarchar(2048) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Campaigns' AND COLUMN_NAME='ActivitySummaryContentType')
    ALTER TABLE [Campaigns] ADD [ActivitySummaryContentType] nvarchar(128) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Campaigns' AND COLUMN_NAME='ActivitySummaryFileSizeBytes')
    ALTER TABLE [Campaigns] ADD [ActivitySummaryFileSizeBytes] bigint NULL;
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Campaigns' AND COLUMN_NAME='ActivitySummaryExtractedDataJson')
    ALTER TABLE [Campaigns] ADD [ActivitySummaryExtractedDataJson] nvarchar(max) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Campaigns' AND COLUMN_NAME='ActivitySummaryExtractionConfidence')
    ALTER TABLE [Campaigns] ADD [ActivitySummaryExtractionConfidence] float NULL;
GO

-- BaseEntity fields for Campaigns
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Campaigns' AND COLUMN_NAME='CreatedBy')
    ALTER TABLE [Campaigns] ADD [CreatedBy] nvarchar(max) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Campaigns' AND COLUMN_NAME='UpdatedBy')
    ALTER TABLE [Campaigns] ADD [UpdatedBy] nvarchar(max) NULL;
GO

-- Remove InvoiceId FK from Campaigns (entity doesn't have it, migration added it incorrectly)
-- Campaign links to Package, not to Invoice. Invoices link to Campaign.
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Campaigns' AND COLUMN_NAME='InvoiceId')
BEGIN
    -- Drop FK constraint first
    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Campaigns_Invoices_InvoiceId')
        ALTER TABLE [Campaigns] DROP CONSTRAINT [FK_Campaigns_Invoices_InvoiceId];
    -- Drop index
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Campaigns_InvoiceId' AND object_id = OBJECT_ID('Campaigns'))
        DROP INDEX IX_Campaigns_InvoiceId ON [Campaigns];
    -- Make column nullable since existing rows may have values
    ALTER TABLE [Campaigns] ALTER COLUMN [InvoiceId] uniqueidentifier NULL;
END
GO
