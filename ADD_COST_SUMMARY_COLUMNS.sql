-- =============================================
-- Migration: Add missing columns to CostSummaries table
-- Purpose:   Add ElementWiseCostsJson, ElementWiseQuantityJson, NumberOfActivations,
--            NumberOfDays, NumberOfTeams, PlaceOfSupply columns
-- Date:      2026-03-18
-- Database:  BajajDocumentProcessing on localhost\SQLEXPRESS
-- =============================================
BEGIN TRANSACTION;

BEGIN TRY

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'CostSummaries' AND COLUMN_NAME = 'PlaceOfSupply'
    )
    BEGIN
        ALTER TABLE CostSummaries ADD PlaceOfSupply NVARCHAR(500) NULL;
        PRINT 'Added PlaceOfSupply column';
    END
    ELSE PRINT 'PlaceOfSupply already exists — skipping';

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'CostSummaries' AND COLUMN_NAME = 'NumberOfDays'
    )
    BEGIN
        ALTER TABLE CostSummaries ADD NumberOfDays INT NULL;
        PRINT 'Added NumberOfDays column';
    END
    ELSE PRINT 'NumberOfDays already exists — skipping';

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'CostSummaries' AND COLUMN_NAME = 'NumberOfActivations'
    )
    BEGIN
        ALTER TABLE CostSummaries ADD NumberOfActivations INT NULL;
        PRINT 'Added NumberOfActivations column';
    END
    ELSE PRINT 'NumberOfActivations already exists — skipping';

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'CostSummaries' AND COLUMN_NAME = 'NumberOfTeams'
    )
    BEGIN
        ALTER TABLE CostSummaries ADD NumberOfTeams INT NULL;
        PRINT 'Added NumberOfTeams column';
    END
    ELSE PRINT 'NumberOfTeams already exists — skipping';

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'CostSummaries' AND COLUMN_NAME = 'ElementWiseCostsJson'
    )
    BEGIN
        ALTER TABLE CostSummaries ADD ElementWiseCostsJson NVARCHAR(MAX) NULL;
        PRINT 'Added ElementWiseCostsJson column';
    END
    ELSE PRINT 'ElementWiseCostsJson already exists — skipping';

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'CostSummaries' AND COLUMN_NAME = 'ElementWiseQuantityJson'
    )
    BEGIN
        ALTER TABLE CostSummaries ADD ElementWiseQuantityJson NVARCHAR(MAX) NULL;
        PRINT 'Added ElementWiseQuantityJson column';
    END
    ELSE PRINT 'ElementWiseQuantityJson already exists — skipping';

    COMMIT TRANSACTION;
    PRINT 'All CostSummaries columns added successfully';
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    THROW;
END CATCH;
