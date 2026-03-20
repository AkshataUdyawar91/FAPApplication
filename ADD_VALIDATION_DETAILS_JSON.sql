-- =============================================
-- Migration: Re-add ValidationDetailsJson column to ValidationResults
-- Purpose:   Store both proactive and reactive validation results as structured JSON
-- Date:      2026-03-20
-- Rollback:  ALTER TABLE ValidationResults DROP COLUMN ValidationDetailsJson;
-- =============================================
BEGIN TRANSACTION;

BEGIN TRY
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'ValidationResults' AND COLUMN_NAME = 'ValidationDetailsJson'
    )
    BEGIN
        ALTER TABLE ValidationResults
        ADD ValidationDetailsJson NVARCHAR(MAX) NULL;

        PRINT 'Column ValidationDetailsJson added to ValidationResults';
    END
    ELSE
    BEGIN
        PRINT 'Column ValidationDetailsJson already exists — skipping';
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    THROW;
END CATCH;
