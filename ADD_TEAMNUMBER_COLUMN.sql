-- =============================================
-- Migration: Add TeamNumber column to Teams table
-- Purpose:   EF Core entity has TeamNumber (int?) but DB does not.
--            Used for ordering and identifying teams within a package.
-- Date:      2026-03-19
-- Idempotent: Safe to run multiple times.
-- Rollback:  ALTER TABLE [Teams] DROP COLUMN [TeamNumber];
-- =============================================
BEGIN TRANSACTION;

BEGIN TRY

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'Teams' AND COLUMN_NAME = 'TeamNumber'
    )
    BEGIN
        ALTER TABLE [Teams] ADD [TeamNumber] INT NULL;
        PRINT 'Added TeamNumber column to Teams';
    END
    ELSE
    BEGIN
        PRINT 'TeamNumber column already exists — skipping';
    END;

    COMMIT TRANSACTION;
    PRINT 'Migration complete.';
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    THROW;
END CATCH;
