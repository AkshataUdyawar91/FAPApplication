-- =============================================
-- Purpose: Add missing columns to POs table that EF Core model expects
-- Run against: BajajDocumentProcessing on localhost\SQLEXPRESS
-- =============================================

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'POs' AND COLUMN_NAME = 'RefreshedAt'
)
BEGIN
    ALTER TABLE [POs] ADD [RefreshedAt] datetime2 NULL;
    PRINT 'Added RefreshedAt column to POs table';
END
ELSE
BEGIN
    PRINT 'RefreshedAt column already exists — skipping';
END;

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'POs' AND COLUMN_NAME = 'RemainingBalance'
)
BEGIN
    ALTER TABLE [POs] ADD [RemainingBalance] decimal(18,2) NULL;
    PRINT 'Added RemainingBalance column to POs table';
END
ELSE
BEGIN
    PRINT 'RemainingBalance column already exists — skipping';
END;
