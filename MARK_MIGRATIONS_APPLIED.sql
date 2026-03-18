-- =============================================
-- Purpose: Mark existing EF Core migrations as applied
-- Run against: BajajDocumentProcessing on localhost\SQLEXPRESS
-- Why: The database tables already exist but __EFMigrationsHistory
--      is missing entries, causing MigrateAsync() to fail with
--      "There is already an object named 'Agencies' in the database"
-- =============================================

-- First ensure the history table exists
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = '__EFMigrationsHistory')
BEGIN
    CREATE TABLE [__EFMigrationsHistory] (
        [MigrationId] nvarchar(150) NOT NULL,
        [ProductVersion] nvarchar(32) NOT NULL,
        CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY ([MigrationId])
    );
    PRINT 'Created __EFMigrationsHistory table';
END;

-- Insert all migration records that are missing
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

-- Verify
SELECT * FROM [__EFMigrationsHistory] ORDER BY [MigrationId];
