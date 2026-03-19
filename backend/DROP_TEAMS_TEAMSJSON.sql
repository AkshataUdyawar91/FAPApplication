-- =============================================
-- Migration: Drop TeamsJson column from Teams table
-- Purpose:   TeamsJson was a write-only dead column — never read back by any
--            service, DTO, or response. Structured fields (CampaignName, TeamCode,
--            StartDate, EndDate, WorkingDays, DealershipName, DealershipAddress,
--            GPSLocation, State) cover all required data.
-- Date:      2026-03-18
-- Rollback:  ALTER TABLE Teams ADD TeamsJson NVARCHAR(MAX) NULL;
-- =============================================
BEGIN TRANSACTION;

BEGIN TRY
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'Teams' AND COLUMN_NAME = 'TeamsJson'
    )
    BEGIN
        ALTER TABLE Teams DROP COLUMN TeamsJson;
        PRINT 'Column TeamsJson dropped from Teams';
    END
    ELSE
    BEGIN
        PRINT 'Column TeamsJson does not exist — skipping';
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    THROW;
END CATCH;
