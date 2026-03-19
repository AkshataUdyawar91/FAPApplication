-- =============================================
-- Migration: Add missing columns to TeamPhotos
-- Purpose:   EF Core entity has BlueTshirtPresent, DateVisible,
--            PhotoDateOverlay, ThreeWheelerPresent but DB does not.
-- Date:      2026-03-19
-- Rollback:  ALTER TABLE TeamPhotos DROP COLUMN BlueTshirtPresent, DateVisible, PhotoDateOverlay, ThreeWheelerPresent;
-- =============================================
BEGIN TRANSACTION;

BEGIN TRY

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'TeamPhotos' AND COLUMN_NAME = 'BlueTshirtPresent'
    )
    BEGIN
        ALTER TABLE [TeamPhotos] ADD [BlueTshirtPresent] BIT NULL;
        PRINT 'Added BlueTshirtPresent to TeamPhotos';
    END
    ELSE PRINT 'BlueTshirtPresent already exists — skipping';

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'TeamPhotos' AND COLUMN_NAME = 'DateVisible'
    )
    BEGIN
        ALTER TABLE [TeamPhotos] ADD [DateVisible] BIT NULL;
        PRINT 'Added DateVisible to TeamPhotos';
    END
    ELSE PRINT 'DateVisible already exists — skipping';

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'TeamPhotos' AND COLUMN_NAME = 'PhotoDateOverlay'
    )
    BEGIN
        ALTER TABLE [TeamPhotos] ADD [PhotoDateOverlay] NVARCHAR(100) NULL;
        PRINT 'Added PhotoDateOverlay to TeamPhotos';
    END
    ELSE PRINT 'PhotoDateOverlay already exists — skipping';

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'TeamPhotos' AND COLUMN_NAME = 'ThreeWheelerPresent'
    )
    BEGIN
        ALTER TABLE [TeamPhotos] ADD [ThreeWheelerPresent] BIT NULL;
        PRINT 'Added ThreeWheelerPresent to TeamPhotos';
    END
    ELSE PRINT 'ThreeWheelerPresent already exists — skipping';

    COMMIT TRANSACTION;
    PRINT 'Migration complete.';
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    THROW;
END CATCH;
