-- =============================================
-- Migration: Drop ValidationDetailsJson from ValidationResults
-- Date: 2026-03-18
-- Author: Kiro
-- Purpose: Remove ValidationDetailsJson column — superseded by RuleResultsJson
--          which stores per-rule results with full detail.
--          The six boolean columns (SapVerificationPassed etc.) are retained
--          as they are still read by RecommendationAgent and EnhancedValidationReportService.
-- Rollback: Add back: ALTER TABLE ValidationResults ADD ValidationDetailsJson NVARCHAR(MAX) NULL;
-- Safe to run multiple times (idempotent)
-- =============================================

BEGIN TRANSACTION;

BEGIN TRY

    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'ValidationResults' AND COLUMN_NAME = 'ValidationDetailsJson'
    )
    BEGIN
        ALTER TABLE ValidationResults DROP COLUMN ValidationDetailsJson;
        PRINT 'Dropped column: ValidationResults.ValidationDetailsJson';
    END
    ELSE
        PRINT 'Column ValidationDetailsJson does not exist — skipping';

    PRINT 'DROP_VALIDATIONRESULTS_DETAILSJSON: completed successfully.';

    COMMIT TRANSACTION;

END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
