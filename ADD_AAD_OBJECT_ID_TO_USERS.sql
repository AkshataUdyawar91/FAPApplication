-- =============================================
-- Migration: Add AadObjectId column to Users table
-- Purpose:   Stores Azure AD Object ID for Teams SSO and pre-linking.
--            Enables seamless bot authentication without login prompts.
-- Date:      2026-03-19
-- Idempotent: Safe to run multiple times.
-- Rollback:  DROP INDEX IX_Users_AadObjectId ON [Users]; ALTER TABLE [Users] DROP COLUMN [AadObjectId];
-- =============================================
SET QUOTED_IDENTIFIER ON;
GO
SET ANSI_NULLS ON;
GO

-- Step 1: Add column
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'Users' AND COLUMN_NAME = 'AadObjectId'
)
BEGIN
    ALTER TABLE [Users] ADD [AadObjectId] NVARCHAR(128) NULL;
    PRINT 'Added AadObjectId column to Users';
END
ELSE
BEGIN
    PRINT 'AadObjectId column already exists — skipping';
END
GO

-- Step 2: Add unique filtered index (separate batch so column exists)
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_Users_AadObjectId' AND object_id = OBJECT_ID('Users')
)
BEGIN
    CREATE UNIQUE INDEX IX_Users_AadObjectId
    ON [Users] ([AadObjectId])
    WHERE [AadObjectId] IS NOT NULL;
    PRINT 'Added IX_Users_AadObjectId unique filtered index';
END
ELSE
BEGIN
    PRINT 'IX_Users_AadObjectId already exists — skipping';
END
GO
