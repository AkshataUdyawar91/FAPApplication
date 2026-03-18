-- =============================================
-- Migration: Add RefreshedAt column to POs table
-- Purpose:   Stores the CalculatedAt timestamp from the SAP PO balance API response,
--            indicating when RemainingBalance was last refreshed.
-- Date:      2026-03-17
-- Rollback:  ALTER TABLE POs DROP COLUMN RefreshedAt;
-- =============================================
BEGIN TRANSACTION;

BEGIN TRY
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'POs' AND COLUMN_NAME = 'RefreshedAt'
    )
    BEGIN
        ALTER TABLE POs
        ADD RefreshedAt DATETIME2(7) NULL;

        PRINT 'Column RefreshedAt added to POs table.';
    END
    ELSE
    BEGIN
        PRINT 'Column RefreshedAt already exists — skipping.';
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    THROW;
END CATCH;
