-- =============================================
-- Migration: Create ConversationAuditLogs table with ResolvedScope column
-- Purpose:   Audit log for all conversational AI interactions (Req 2.5, 11.1, 11.2)
-- Date:      2026-03-23
-- Rollback:  DROP TABLE ConversationAuditLogs;
-- =============================================

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'ConversationAuditLogs')
BEGIN
    CREATE TABLE ConversationAuditLogs (
        Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        UserId UNIQUEIDENTIFIER NOT NULL,
        UserRole NVARCHAR(50) NOT NULL DEFAULT '',
        Channel NVARCHAR(50) NOT NULL DEFAULT '',
        UserMessage NVARCHAR(MAX) NOT NULL DEFAULT '',
        BotResponse NVARCHAR(MAX) NOT NULL DEFAULT '',
        Intent NVARCHAR(100) NULL,
        ResolvedScope NVARCHAR(500) NULL,
        [Timestamp] DATETIME2 NOT NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt DATETIME2 NULL,
        CreatedBy NVARCHAR(MAX) NULL,
        UpdatedBy NVARCHAR(MAX) NULL,
        IsDeleted BIT NOT NULL DEFAULT 0
    );

    CREATE INDEX IX_ConversationAuditLogs_UserId_Timestamp
        ON ConversationAuditLogs (UserId, [Timestamp]);

    CREATE INDEX IX_ConversationAuditLogs_Channel
        ON ConversationAuditLogs (Channel);

    PRINT 'Table ConversationAuditLogs created successfully';
END
ELSE
BEGIN
    -- Table exists, just add ResolvedScope if missing
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'ConversationAuditLogs' AND COLUMN_NAME = 'ResolvedScope'
    )
    BEGIN
        ALTER TABLE ConversationAuditLogs ADD ResolvedScope NVARCHAR(500) NULL;
        PRINT 'Column ResolvedScope added to ConversationAuditLogs';
    END
    ELSE
    BEGIN
        PRINT 'Column ResolvedScope already exists — skipping';
    END;
END;
