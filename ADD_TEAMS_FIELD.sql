-- =============================================
-- Migration: Add TeamsJson column to DocumentPackages
-- Purpose: Store teams/campaign members data as JSON
-- Date: 2026-03-09
-- =============================================

-- Add TeamsJson column if it doesn't exist
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'TeamsJson'
)
BEGIN
    ALTER TABLE DocumentPackages
    ADD TeamsJson NVARCHAR(MAX) NULL;
    
    PRINT 'Column TeamsJson added to DocumentPackages';
END
ELSE
BEGIN
    PRINT 'Column TeamsJson already exists - skipping';
END
GO
