-- =============================================
-- Migration: Add EmailDeliveryLogs table
-- Purpose:   Audit log for all outbound email delivery attempts
-- Date:      2026-03-18
-- Rollback:  DROP TABLE IF EXISTS EmailDeliveryLogs;
-- =============================================
BEGIN TRANSACTION;

BEGIN TRY
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_NAME = 'EmailDeliveryLogs'
    )
    BEGIN
        CREATE TABLE EmailDeliveryLogs (
            Id                UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID() PRIMARY KEY,
            PackageId         UNIQUEIDENTIFIER NOT NULL,
            TemplateName      NVARCHAR(100)    NOT NULL,
            RecipientEmail    NVARCHAR(MAX)    NOT NULL,  -- semicolon-separated when multiple recipients
            Subject           NVARCHAR(500)    NOT NULL,
            Success           BIT              NOT NULL DEFAULT 0,
            AttemptsCount     INT              NOT NULL DEFAULT 0,
            MessageId         NVARCHAR(256)    NULL,
            ErrorMessage      NVARCHAR(MAX)    NULL,
            SentAt            DATETIME2        NOT NULL DEFAULT GETUTCDATE(),
            CreatedAt         DATETIME2        NOT NULL DEFAULT GETUTCDATE(),
            UpdatedAt         DATETIME2        NULL,
            CreatedBy         NVARCHAR(256)    NULL,
            UpdatedBy         NVARCHAR(256)    NULL,
            IsDeleted         BIT              NOT NULL DEFAULT 0
        );

        -- Index for querying logs by package
        CREATE INDEX IX_EmailDeliveryLogs_PackageId
            ON EmailDeliveryLogs (PackageId);

        -- Index for querying failed deliveries
        CREATE INDEX IX_EmailDeliveryLogs_Success_SentAt
            ON EmailDeliveryLogs (Success, SentAt DESC);

        PRINT 'EmailDeliveryLogs table created successfully';
    END
    ELSE
    BEGIN
        PRINT 'EmailDeliveryLogs table already exists — skipping';
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    THROW;
END CATCH;
