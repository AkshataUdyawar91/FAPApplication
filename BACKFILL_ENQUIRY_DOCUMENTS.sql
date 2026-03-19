-- =============================================
-- Migration: Backfill NULL fields in EnquiryDocuments
-- Purpose:   Populate CreatedBy, UpdatedBy from parent DocumentPackage.SubmittedByUserId
-- Date:      2026-03-19
-- Rollback:  No rollback needed (fills NULLs only, does not overwrite existing data)
-- =============================================
BEGIN TRANSACTION;

BEGIN TRY

    -- 1. Backfill CreatedBy from the parent package's SubmittedByUserId
    UPDATE ed
    SET ed.CreatedBy = CAST(dp.SubmittedByUserId AS NVARCHAR(36))
    FROM EnquiryDocuments ed
    INNER JOIN DocumentPackages dp ON dp.Id = ed.PackageId
    WHERE ed.CreatedBy IS NULL
      AND dp.SubmittedByUserId IS NOT NULL;

    PRINT 'Backfilled CreatedBy: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows';

    -- 2. Backfill UpdatedBy from the parent package's SubmittedByUserId
    UPDATE ed
    SET ed.UpdatedBy = CAST(dp.SubmittedByUserId AS NVARCHAR(36))
    FROM EnquiryDocuments ed
    INNER JOIN DocumentPackages dp ON dp.Id = ed.PackageId
    WHERE ed.UpdatedBy IS NULL
      AND dp.SubmittedByUserId IS NOT NULL;

    PRINT 'Backfilled UpdatedBy: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows';

    -- 3. Backfill UpdatedAt where NULL (set to CreatedAt)
    UPDATE EnquiryDocuments
    SET UpdatedAt = CreatedAt
    WHERE UpdatedAt IS NULL;

    PRINT 'Backfilled UpdatedAt: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows';

    COMMIT TRANSACTION;
    PRINT 'Backfill completed successfully.';

END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    THROW;
END CATCH;
