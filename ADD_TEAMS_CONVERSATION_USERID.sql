-- =============================================
-- Migration: Add UserId FK and LastActivityAt to TeamsConversations
-- Date: 2026-03-16
-- Purpose: Adds UserId FK to Users table and LastActivityAt column
--          per design_v2_corrected.md TeamsConversation schema.
-- Idempotent: Safe to run multiple times.
-- =============================================
SET QUOTED_IDENTIFIER ON;
GO
SET ANSI_NULLS ON;
GO

BEGIN TRANSACTION;

BEGIN TRY
    -- 1. Add UserId column (nullable FK to Users)
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'TeamsConversations' AND COLUMN_NAME = 'UserId'
    )
    BEGIN
        ALTER TABLE TeamsConversations
        ADD UserId UNIQUEIDENTIFIER NULL;

        PRINT 'Added UserId column to TeamsConversations';
    END
    ELSE
    BEGIN
        PRINT 'UserId column already exists — skipping';
    END;

    -- 2. Add FK constraint
    IF NOT EXISTS (
        SELECT 1 FROM sys.foreign_keys
        WHERE name = 'FK_TeamsConversations_Users'
    )
    BEGIN
        ALTER TABLE TeamsConversations
        ADD CONSTRAINT FK_TeamsConversations_Users
        FOREIGN KEY (UserId) REFERENCES Users(Id)
        ON DELETE SET NULL;

        PRINT 'Added FK_TeamsConversations_Users constraint';
    END
    ELSE
    BEGIN
        PRINT 'FK_TeamsConversations_Users already exists — skipping';
    END;

    -- 3. Add index on UserId for active conversations
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE name = 'IX_TeamsConversations_UserId' AND object_id = OBJECT_ID('TeamsConversations')
    )
    BEGIN
        CREATE INDEX IX_TeamsConversations_UserId
        ON TeamsConversations (UserId)
        WHERE IsActive = 1;

        PRINT 'Added IX_TeamsConversations_UserId index';
    END
    ELSE
    BEGIN
        PRINT 'IX_TeamsConversations_UserId already exists — skipping';
    END;

    -- 4. Add LastActivityAt column
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'TeamsConversations' AND COLUMN_NAME = 'LastActivityAt'
    )
    BEGIN
        ALTER TABLE TeamsConversations
        ADD LastActivityAt DATETIME2 NULL;

        PRINT 'Added LastActivityAt column to TeamsConversations';
    END
    ELSE
    BEGIN
        PRINT 'LastActivityAt column already exists — skipping';
    END;

    COMMIT TRANSACTION;
    PRINT 'Migration completed successfully.';
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    PRINT 'Migration failed — rolled back.';
    THROW;
END CATCH;
