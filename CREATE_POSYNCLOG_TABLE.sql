-- =============================================
-- Migration: Create POSyncLogs Table
-- Purpose:   Audit log for SAP PO file sync operations
--            Tracks every inbound SAP file with agency/PO resolution
--            status and raw imported CSV data as JSON
-- Date:      2026-03-17
-- Rollback:  DROP TABLE IF EXISTS POSyncLogs
-- =============================================

BEGIN TRANSACTION;

BEGIN TRY

    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'POSyncLogs')
    BEGIN
        CREATE TABLE POSyncLogs (
            Id              UNIQUEIDENTIFIER    NOT NULL PRIMARY KEY DEFAULT NEWID(),
            SourceSystem    NVARCHAR(50)        NOT NULL DEFAULT 'SAP',
            FileName        NVARCHAR(512)       NOT NULL,
            AgencyId        UNIQUEIDENTIFIER    NULL,           -- NULL if agency not found
            POId            UNIQUEIDENTIFIER    NULL,           -- NULL if PO already existed or insert failed
            Status          NVARCHAR(50)        NOT NULL,       -- 'AgencyNotFound' | 'POAlreadyExists' | 'Success' | 'Failed'
            ErrorMessage    NVARCHAR(1000)      NULL,
            ProcessedAt     DATETIME2           NOT NULL DEFAULT GETUTCDATE(),
            CreatedBy       NVARCHAR(256)       NULL,
            IsDeleted       BIT                 NOT NULL DEFAULT 0,
            ImportedRecords NVARCHAR(MAX)       NULL            -- Raw JSON extracted from the CSV file
        );

        -- Index for agency-based lookups
        CREATE INDEX IX_POSyncLogs_AgencyId
            ON POSyncLogs(AgencyId);

        -- Index for PO-based lookups
        CREATE INDEX IX_POSyncLogs_POId
            ON POSyncLogs(POId);

        -- Index for filtering by sync status
        CREATE INDEX IX_POSyncLogs_Status
            ON POSyncLogs(Status);

        -- Index for time-based queries and reporting
        CREATE INDEX IX_POSyncLogs_ProcessedAt
            ON POSyncLogs(ProcessedAt DESC);

        PRINT 'Created POSyncLogs table with indexes';
    END
    ELSE
    BEGIN
        PRINT 'POSyncLogs table already exists — skipping';
    END

    COMMIT TRANSACTION;
    PRINT 'Migration completed successfully';

END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    PRINT 'Migration failed: ' + ERROR_MESSAGE();
    THROW;
END CATCH
