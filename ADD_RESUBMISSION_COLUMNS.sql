-- Add missing ResubmissionCount and HQResubmissionCount columns
-- Run this if you get "Invalid column name" errors

USE BajajDocumentProcessing;
GO

-- Check if columns exist before adding
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[DocumentPackages]') AND name = 'ResubmissionCount')
BEGIN
    ALTER TABLE DocumentPackages
    ADD ResubmissionCount INT NULL DEFAULT 0;
    
    PRINT 'Added ResubmissionCount column';
END
ELSE
BEGIN
    PRINT 'ResubmissionCount column already exists';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[DocumentPackages]') AND name = 'HQResubmissionCount')
BEGIN
    ALTER TABLE DocumentPackages
    ADD HQResubmissionCount INT NULL DEFAULT 0;
    
    PRINT 'Added HQResubmissionCount column';
END
ELSE
BEGIN
    PRINT 'HQResubmissionCount column already exists';
END
GO

-- Update existing records to have 0 for these counts
UPDATE DocumentPackages
SET ResubmissionCount = 0
WHERE ResubmissionCount IS NULL;

UPDATE DocumentPackages
SET HQResubmissionCount = 0
WHERE HQResubmissionCount IS NULL;
GO

PRINT 'Resubmission columns added successfully!';
GO
