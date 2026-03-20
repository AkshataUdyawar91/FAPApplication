-- =============================================
-- Script: Create CampaignInvoices table
-- Purpose: Add the CampaignInvoices table for campaign-level invoices linked to Teams
-- Date: 2026-03-19
-- Idempotent: Yes — safe to run multiple times
-- =============================================

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CampaignInvoices')
BEGIN
    CREATE TABLE [CampaignInvoices] (
        [Id]                    UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
        [CampaignId]            UNIQUEIDENTIFIER NOT NULL,
        [PackageId]             UNIQUEIDENTIFIER NOT NULL,
        [InvoiceNumber]         NVARCHAR(100)    NULL,
        [InvoiceDate]           DATETIME2        NULL,
        [VendorName]            NVARCHAR(500)    NULL,
        [GSTNumber]             NVARCHAR(50)     NULL,
        [SubTotal]              DECIMAL(18, 2)   NULL,
        [TaxAmount]             DECIMAL(18, 2)   NULL,
        [TotalAmount]           DECIMAL(18, 2)   NULL,
        [FileName]              NVARCHAR(500)    NOT NULL,
        [BlobUrl]               NVARCHAR(2000)   NOT NULL,
        [FileSizeBytes]         BIGINT           NOT NULL DEFAULT 0,
        [ContentType]           NVARCHAR(100)    NOT NULL,
        [ExtractedDataJson]     NVARCHAR(MAX)    NULL,
        [ExtractionConfidence]  FLOAT            NULL,
        [IsFlaggedForReview]    BIT              NOT NULL DEFAULT 0,
        [CreatedAt]             DATETIME2        NOT NULL DEFAULT GETUTCDATE(),
        [UpdatedAt]             DATETIME2        NULL,
        [CreatedBy]             NVARCHAR(450)    NULL,
        [UpdatedBy]             NVARCHAR(450)    NULL,
        [IsDeleted]             BIT              NOT NULL DEFAULT 0,

        CONSTRAINT [PK_CampaignInvoices] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_CampaignInvoices_Teams] FOREIGN KEY ([CampaignId])
            REFERENCES [Teams]([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_CampaignInvoices_DocumentPackages] FOREIGN KEY ([PackageId])
            REFERENCES [DocumentPackages]([Id]) ON DELETE NO ACTION
    );

    CREATE INDEX [IX_CampaignInvoices_CampaignId] ON [CampaignInvoices]([CampaignId]);
    CREATE INDEX [IX_CampaignInvoices_PackageId] ON [CampaignInvoices]([PackageId]);
    CREATE INDEX [IX_CampaignInvoices_InvoiceNumber] ON [CampaignInvoices]([InvoiceNumber]);

    PRINT 'CampaignInvoices table created successfully.';
END
ELSE
BEGIN
    PRINT 'CampaignInvoices table already exists — skipping.';
END;
