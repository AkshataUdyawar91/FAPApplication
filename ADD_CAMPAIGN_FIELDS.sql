-- =============================================
-- Migration: Add Campaign Fields to DocumentPackages
-- Date: 2026-03-08
-- Purpose: Add CampaignStartDate, CampaignEndDate, and CampaignWorkingDays columns
-- =============================================

BEGIN TRANSACTION;

BEGIN TRY
    -- Add CampaignStartDate column
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'CampaignStartDate'
    )
    BEGIN
        ALTER TABLE DocumentPackages
        ADD CampaignStartDate DATETIME2 NULL;
        
        PRINT 'Column CampaignStartDate added to DocumentPackages';
    END
    ELSE
    BEGIN
        PRINT 'Column CampaignStartDate already exists — skipping';
    END;
    
    -- Add CampaignEndDate column
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'CampaignEndDate'
    )
    BEGIN
        ALTER TABLE DocumentPackages
        ADD CampaignEndDate DATETIME2 NULL;
        
        PRINT 'Column CampaignEndDate added to DocumentPackages';
    END
    ELSE
    BEGIN
        PRINT 'Column CampaignEndDate already exists — skipping';
    END;
    
    -- Add CampaignWorkingDays column
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'CampaignWorkingDays'
    )
    BEGIN
        ALTER TABLE DocumentPackages
        ADD CampaignWorkingDays INT NULL;
        
        PRINT 'Column CampaignWorkingDays added to DocumentPackages';
    END
    ELSE
    BEGIN
        PRINT 'Column CampaignWorkingDays already exists — skipping';
    END;
    
    COMMIT TRANSACTION;
    PRINT 'Campaign fields migration completed successfully';
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    PRINT 'Error occurred during migration:';
    PRINT ERROR_MESSAGE();
    THROW;
END CATCH;
