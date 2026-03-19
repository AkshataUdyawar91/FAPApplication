-- =============================================
-- FIX_DATABASE.sql
-- Purpose: Fix all database sync issues in one go
-- Run against: BajajDocumentProcessing on localhost\SQLEXPRESS
-- 1. Creates __EFMigrationsHistory if missing
-- 2. Marks all migrations as applied
-- 3. Adds any missing columns to existing tables
-- =============================================

PRINT '=== Step 1: Fix Migration History ===';

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = '__EFMigrationsHistory')
BEGIN
    CREATE TABLE [__EFMigrationsHistory] (
        [MigrationId] nvarchar(150) NOT NULL,
        [ProductVersion] nvarchar(32) NOT NULL,
        CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY ([MigrationId])
    );
    PRINT 'Created __EFMigrationsHistory table';
END;

INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
SELECT m.MigrationId, '8.0.0'
FROM (VALUES
    ('20260312082915_DatabaseRedesign'),
    ('20260312155638_RemoveLegacyDocumentsTable'),
    ('20260313082520_AddReferenceDataTables'),
    ('20260316143447_SeedStateGstData'),
    ('20260316145553_ReplaceGstCodeWithGstRate'),
    ('20260316145644_AddGstRateColumn'),
    ('20260317000001_AddActivitySummaryExtractedColumns'),
    ('20260317000002_AddCostSummaryExtractedColumns'),
    ('20260317101710_AddPoBalanceLogs'),
    ('20260318073114_AddRAUserIdToStateMappings')
) AS m(MigrationId)
WHERE NOT EXISTS (
    SELECT 1 FROM [__EFMigrationsHistory] h WHERE h.MigrationId = m.MigrationId
);

PRINT 'Migration history synchronized';

PRINT '=== Step 2: Add Missing PO Columns ===';

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'POs' AND COLUMN_NAME = 'RefreshedAt')
BEGIN
    ALTER TABLE [POs] ADD [RefreshedAt] datetime2 NULL;
    PRINT 'Added RefreshedAt to POs';
END
ELSE PRINT 'RefreshedAt already exists';

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'POs' AND COLUMN_NAME = 'RemainingBalance')
BEGIN
    ALTER TABLE [POs] ADD [RemainingBalance] decimal(18,2) NULL;
    PRINT 'Added RemainingBalance to POs';
END
ELSE PRINT 'RemainingBalance already exists';

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'POs' AND COLUMN_NAME = 'VendorCode')
BEGIN
    ALTER TABLE [POs] ADD [VendorCode] nvarchar(max) NULL;
    PRINT 'Added VendorCode to POs';
END
ELSE PRINT 'VendorCode already exists';

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'POs' AND COLUMN_NAME = 'POStatus')
BEGIN
    ALTER TABLE [POs] ADD [POStatus] nvarchar(max) NULL;
    PRINT 'Added POStatus to POs';
END
ELSE PRINT 'POStatus already exists';

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'POs' AND COLUMN_NAME = 'VersionNumber')
BEGIN
    ALTER TABLE [POs] ADD [VersionNumber] int NOT NULL DEFAULT 1;
    PRINT 'Added VersionNumber to POs';
END
ELSE PRINT 'VersionNumber already exists';

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'POs' AND COLUMN_NAME = 'IsFlaggedForReview')
BEGIN
    ALTER TABLE [POs] ADD [IsFlaggedForReview] bit NOT NULL DEFAULT 0;
    PRINT 'Added IsFlaggedForReview to POs';
END
ELSE PRINT 'IsFlaggedForReview already exists';

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'POs' AND COLUMN_NAME = 'ExtractionConfidence')
BEGIN
    ALTER TABLE [POs] ADD [ExtractionConfidence] float NULL;
    PRINT 'Added ExtractionConfidence to POs';
END
ELSE PRINT 'ExtractionConfidence already exists';

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'POs' AND COLUMN_NAME = 'ExtractedDataJson')
BEGIN
    ALTER TABLE [POs] ADD [ExtractedDataJson] nvarchar(max) NULL;
    PRINT 'Added ExtractedDataJson to POs';
END
ELSE PRINT 'ExtractedDataJson already exists';

PRINT '=== Step 3: Verify ===';
SELECT * FROM [__EFMigrationsHistory] ORDER BY [MigrationId];
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'POs' ORDER BY ORDINAL_POSITION;

PRINT '=== Done ===';
