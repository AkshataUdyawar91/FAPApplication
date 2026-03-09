-- =============================================
-- Migration: Add Dealership Fields to DocumentPackages
-- Date: 2026-03-09
-- Purpose: Add DealershipName, DealershipAddress, and GPSLocation columns
-- =============================================

BEGIN TRANSACTION;

BEGIN TRY
    -- Add DealershipName column
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'DealershipName'
    )
    BEGIN
        ALTER TABLE DocumentPackages
        ADD DealershipName NVARCHAR(255) NULL;
        
        PRINT 'Column DealershipName added to DocumentPackages';
    END
    ELSE
    BEGIN
        PRINT 'Column DealershipName already exists — skipping';
    END;
    
    -- Add DealershipAddress column
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'DealershipAddress'
    )
    BEGIN
        ALTER TABLE DocumentPackages
        ADD DealershipAddress NVARCHAR(500) NULL;
        
        PRINT 'Column DealershipAddress added to DocumentPackages';
    END
    ELSE
    BEGIN
        PRINT 'Column DealershipAddress already exists — skipping';
    END;
    
    -- Add GPSLocation column
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'GPSLocation'
    )
    BEGIN
        ALTER TABLE DocumentPackages
        ADD GPSLocation NVARCHAR(100) NULL;
        
        PRINT 'Column GPSLocation added to DocumentPackages';
    END
    ELSE
    BEGIN
        PRINT 'Column GPSLocation already exists — skipping';
    END;
    
    COMMIT TRANSACTION;
    PRINT 'Dealership fields migration completed successfully';
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    PRINT 'Error occurred during migration:';
    PRINT ERROR_MESSAGE();
    THROW;
END CATCH;
