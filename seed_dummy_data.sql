-- =============================================
-- Script: seed_dummy_data.sql
-- Purpose: Populate development database with representative seed data
--          covering all PackageState values (1-8) and all required child tables
--          so every screen is reachable and functional in a local dev environment.
-- Environment: DEVELOPMENT ONLY — do not run in production
-- Dependencies: Four default users must exist (agency@bajaj.com, asm@bajaj.com,
--               ra@bajaj.com, admin@bajaj.com) — seeded by ApplicationDbContextSeed
-- Idempotency: Uses IF NOT EXISTS guards on fixed GUIDs — safe to run multiple times
-- Bug_Condition: isBugCondition(db) = NOT EXISTS (SELECT 1 FROM DocumentPackages WHERE IsDeleted = 0)
-- Expected_Behavior: After script runs — 1 Agency, 1 ASM, 8 DocumentPackages (States 1-8),
--                    all child tables populated per design Property 1
-- Preservation: INSERT only; never modifies schema or existing rows except
--               AgencyId on agency@bajaj.com when NULL
-- =============================================
SET NOCOUNT ON;

BEGIN TRY
BEGIN TRANSACTION;

-- =========================================================
-- 1. Agencies
-- =========================================================
IF NOT EXISTS (SELECT 1 FROM [Agencies] WHERE [Id] = 'A1000000-0000-0000-0000-000000000001')
BEGIN
    INSERT INTO [Agencies] ([Id], [SupplierCode], [SupplierName], [IsDeleted], [CreatedAt], [UpdatedAt])
    VALUES ('A1000000-0000-0000-0000-000000000001','SUP001','Bajaj Seed Agency',0,GETUTCDATE(),GETUTCDATE());
    PRINT 'Inserted Agency: Bajaj Seed Agency';
END
ELSE
    PRINT 'Agency already exists — skipping';

-- =========================================================
-- 2. Link agency@bajaj.com to the Agency (idempotent UPDATE)
-- =========================================================
UPDATE [Users]
SET [AgencyId] = 'A1000000-0000-0000-0000-000000000001',
    [UpdatedAt] = GETUTCDATE()
WHERE [Email] = 'agency@bajaj.com'
  AND [AgencyId] IS NULL;

IF @@ROWCOUNT > 0
    PRINT 'Linked agency@bajaj.com to Agency';
ELSE
    PRINT 'agency@bajaj.com already linked — skipping';

-- =========================================================
-- 2b. Ensure hq@bajaj.com exists (Role=3/RA, same password as ra@bajaj.com)
-- =========================================================
IF NOT EXISTS (SELECT 1 FROM [Users] WHERE [Email] = 'hq@bajaj.com')
BEGIN
    INSERT INTO [Users] ([Id], [Email], [PasswordHash], [FullName], [Role], [IsActive], [IsDeleted], [CreatedAt], [UpdatedAt])
    SELECT NEWID(), 'hq@bajaj.com', [PasswordHash], 'HQ User', 3, 1, 0, GETUTCDATE(), GETUTCDATE()
    FROM [Users] WHERE [Email] = 'ra@bajaj.com';
    PRINT 'Inserted hq@bajaj.com';
END
ELSE
BEGIN
    UPDATE [Users]
    SET [PasswordHash] = (SELECT [PasswordHash] FROM [Users] WHERE [Email] = 'ra@bajaj.com')
    WHERE [Email] = 'hq@bajaj.com'
      AND [PasswordHash] NOT LIKE '$2a$%';
    PRINT 'hq@bajaj.com already exists — skipping';
END

-- =========================================================
-- 3. ASMs
-- =========================================================
IF NOT EXISTS (SELECT 1 FROM [ASMs] WHERE [Id] = 'B1000000-0000-0000-0000-000000000001')
BEGIN
    INSERT INTO [ASMs] ([Id], [Name], [Location], [UserId], [IsDeleted], [CreatedAt], [UpdatedAt])
    VALUES ('B1000000-0000-0000-0000-000000000001','Seed ASM','Mumbai',
            (SELECT [Id] FROM [Users] WHERE [Email] = 'asm@bajaj.com'),
            0,GETUTCDATE(),GETUTCDATE());
    PRINT 'Inserted ASM: Seed ASM';
END
ELSE
    PRINT 'ASM already exists — skipping';

-- =========================================================
-- 4. DocumentPackages (8 rows, one per PackageState 1-8)
-- =========================================================
DECLARE @AgencyUserId UNIQUEIDENTIFIER = (SELECT [Id] FROM [Users] WHERE [Email] = 'agency@bajaj.com');
DECLARE @AgencyId UNIQUEIDENTIFIER = 'A1000000-0000-0000-0000-000000000001';

IF NOT EXISTS (SELECT 1 FROM [DocumentPackages] WHERE [Id] = 'C1000001-0000-0000-0000-000000000001')
    INSERT INTO [DocumentPackages] ([Id],[AgencyId],[SubmittedByUserId],[VersionNumber],[State],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('C1000001-0000-0000-0000-000000000001', @AgencyId, @AgencyUserId, 1, 1, 0, GETUTCDATE(), GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [DocumentPackages] WHERE [Id] = 'C1000002-0000-0000-0000-000000000001')
    INSERT INTO [DocumentPackages] ([Id],[AgencyId],[SubmittedByUserId],[VersionNumber],[State],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('C1000002-0000-0000-0000-000000000001', @AgencyId, @AgencyUserId, 1, 2, 0, GETUTCDATE(), GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [DocumentPackages] WHERE [Id] = 'C1000003-0000-0000-0000-000000000001')
    INSERT INTO [DocumentPackages] ([Id],[AgencyId],[SubmittedByUserId],[VersionNumber],[State],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('C1000003-0000-0000-0000-000000000001', @AgencyId, @AgencyUserId, 1, 3, 0, GETUTCDATE(), GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [DocumentPackages] WHERE [Id] = 'C1000004-0000-0000-0000-000000000001')
    INSERT INTO [DocumentPackages] ([Id],[AgencyId],[SubmittedByUserId],[VersionNumber],[State],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('C1000004-0000-0000-0000-000000000001', @AgencyId, @AgencyUserId, 1, 4, 0, GETUTCDATE(), GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [DocumentPackages] WHERE [Id] = 'C1000005-0000-0000-0000-000000000001')
    INSERT INTO [DocumentPackages] ([Id],[AgencyId],[SubmittedByUserId],[VersionNumber],[State],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('C1000005-0000-0000-0000-000000000001', @AgencyId, @AgencyUserId, 1, 5, 0, GETUTCDATE(), GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [DocumentPackages] WHERE [Id] = 'C1000006-0000-0000-0000-000000000001')
    INSERT INTO [DocumentPackages] ([Id],[AgencyId],[SubmittedByUserId],[VersionNumber],[State],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('C1000006-0000-0000-0000-000000000001', @AgencyId, @AgencyUserId, 1, 6, 0, GETUTCDATE(), GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [DocumentPackages] WHERE [Id] = 'C1000007-0000-0000-0000-000000000001')
    INSERT INTO [DocumentPackages] ([Id],[AgencyId],[SubmittedByUserId],[VersionNumber],[State],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('C1000007-0000-0000-0000-000000000001', @AgencyId, @AgencyUserId, 1, 7, 0, GETUTCDATE(), GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [DocumentPackages] WHERE [Id] = 'C1000008-0000-0000-0000-000000000001')
    INSERT INTO [DocumentPackages] ([Id],[AgencyId],[SubmittedByUserId],[VersionNumber],[State],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('C1000008-0000-0000-0000-000000000001', @AgencyId, @AgencyUserId, 1, 8, 0, GETUTCDATE(), GETUTCDATE());

PRINT 'DocumentPackages seeded (States 1-8)';

-- =========================================================
-- 5. POs (8 rows, one per package)
-- =========================================================
IF NOT EXISTS (SELECT 1 FROM [POs] WHERE [Id] = 'D1000001-0000-0000-0000-000000000001')
    INSERT INTO [POs] ([Id],[PackageId],[AgencyId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('D1000001-0000-0000-0000-000000000001','C1000001-0000-0000-0000-000000000001',@AgencyId,'po_pkg_001.pdf','https://placeholder.blob.core.windows.net/docs/po_pkg_001.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [POs] WHERE [Id] = 'D1000002-0000-0000-0000-000000000001')
    INSERT INTO [POs] ([Id],[PackageId],[AgencyId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('D1000002-0000-0000-0000-000000000001','C1000002-0000-0000-0000-000000000001',@AgencyId,'po_pkg_002.pdf','https://placeholder.blob.core.windows.net/docs/po_pkg_002.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [POs] WHERE [Id] = 'D1000003-0000-0000-0000-000000000001')
    INSERT INTO [POs] ([Id],[PackageId],[AgencyId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('D1000003-0000-0000-0000-000000000001','C1000003-0000-0000-0000-000000000001',@AgencyId,'po_pkg_003.pdf','https://placeholder.blob.core.windows.net/docs/po_pkg_003.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [POs] WHERE [Id] = 'D1000004-0000-0000-0000-000000000001')
    INSERT INTO [POs] ([Id],[PackageId],[AgencyId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('D1000004-0000-0000-0000-000000000001','C1000004-0000-0000-0000-000000000001',@AgencyId,'po_pkg_004.pdf','https://placeholder.blob.core.windows.net/docs/po_pkg_004.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [POs] WHERE [Id] = 'D1000005-0000-0000-0000-000000000001')
    INSERT INTO [POs] ([Id],[PackageId],[AgencyId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('D1000005-0000-0000-0000-000000000001','C1000005-0000-0000-0000-000000000001',@AgencyId,'po_pkg_005.pdf','https://placeholder.blob.core.windows.net/docs/po_pkg_005.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [POs] WHERE [Id] = 'D1000006-0000-0000-0000-000000000001')
    INSERT INTO [POs] ([Id],[PackageId],[AgencyId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('D1000006-0000-0000-0000-000000000001','C1000006-0000-0000-0000-000000000001',@AgencyId,'po_pkg_006.pdf','https://placeholder.blob.core.windows.net/docs/po_pkg_006.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [POs] WHERE [Id] = 'D1000007-0000-0000-0000-000000000001')
    INSERT INTO [POs] ([Id],[PackageId],[AgencyId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('D1000007-0000-0000-0000-000000000001','C1000007-0000-0000-0000-000000000001',@AgencyId,'po_pkg_007.pdf','https://placeholder.blob.core.windows.net/docs/po_pkg_007.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [POs] WHERE [Id] = 'D1000008-0000-0000-0000-000000000001')
    INSERT INTO [POs] ([Id],[PackageId],[AgencyId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('D1000008-0000-0000-0000-000000000001','C1000008-0000-0000-0000-000000000001',@AgencyId,'po_pkg_008.pdf','https://placeholder.blob.core.windows.net/docs/po_pkg_008.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

PRINT 'POs seeded (8 rows)';

-- =========================================================
-- 6. Invoices (8 rows, one per package, linked to corresponding PO)
-- =========================================================
IF NOT EXISTS (SELECT 1 FROM [Invoices] WHERE [Id] = 'E1000001-0000-0000-0000-000000000001')
    INSERT INTO [Invoices] ([Id],[PackageId],[POId],[VersionNumber],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('E1000001-0000-0000-0000-000000000001','C1000001-0000-0000-0000-000000000001','D1000001-0000-0000-0000-000000000001',1,'invoice_pkg_001.pdf','https://placeholder.blob.core.windows.net/docs/invoice_pkg_001.pdf',102400,'application/pdf',0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [Invoices] WHERE [Id] = 'E1000002-0000-0000-0000-000000000001')
    INSERT INTO [Invoices] ([Id],[PackageId],[POId],[VersionNumber],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('E1000002-0000-0000-0000-000000000001','C1000002-0000-0000-0000-000000000001','D1000002-0000-0000-0000-000000000001',1,'invoice_pkg_002.pdf','https://placeholder.blob.core.windows.net/docs/invoice_pkg_002.pdf',102400,'application/pdf',0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [Invoices] WHERE [Id] = 'E1000003-0000-0000-0000-000000000001')
    INSERT INTO [Invoices] ([Id],[PackageId],[POId],[VersionNumber],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('E1000003-0000-0000-0000-000000000001','C1000003-0000-0000-0000-000000000001','D1000003-0000-0000-0000-000000000001',1,'invoice_pkg_003.pdf','https://placeholder.blob.core.windows.net/docs/invoice_pkg_003.pdf',102400,'application/pdf',0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [Invoices] WHERE [Id] = 'E1000004-0000-0000-0000-000000000001')
    INSERT INTO [Invoices] ([Id],[PackageId],[POId],[VersionNumber],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('E1000004-0000-0000-0000-000000000001','C1000004-0000-0000-0000-000000000001','D1000004-0000-0000-0000-000000000001',1,'invoice_pkg_004.pdf','https://placeholder.blob.core.windows.net/docs/invoice_pkg_004.pdf',102400,'application/pdf',0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [Invoices] WHERE [Id] = 'E1000005-0000-0000-0000-000000000001')
    INSERT INTO [Invoices] ([Id],[PackageId],[POId],[VersionNumber],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('E1000005-0000-0000-0000-000000000001','C1000005-0000-0000-0000-000000000001','D1000005-0000-0000-0000-000000000001',1,'invoice_pkg_005.pdf','https://placeholder.blob.core.windows.net/docs/invoice_pkg_005.pdf',102400,'application/pdf',0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [Invoices] WHERE [Id] = 'E1000006-0000-0000-0000-000000000001')
    INSERT INTO [Invoices] ([Id],[PackageId],[POId],[VersionNumber],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('E1000006-0000-0000-0000-000000000001','C1000006-0000-0000-0000-000000000001','D1000006-0000-0000-0000-000000000001',1,'invoice_pkg_006.pdf','https://placeholder.blob.core.windows.net/docs/invoice_pkg_006.pdf',102400,'application/pdf',0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [Invoices] WHERE [Id] = 'E1000007-0000-0000-0000-000000000001')
    INSERT INTO [Invoices] ([Id],[PackageId],[POId],[VersionNumber],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('E1000007-0000-0000-0000-000000000001','C1000007-0000-0000-0000-000000000001','D1000007-0000-0000-0000-000000000001',1,'invoice_pkg_007.pdf','https://placeholder.blob.core.windows.net/docs/invoice_pkg_007.pdf',102400,'application/pdf',0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [Invoices] WHERE [Id] = 'E1000008-0000-0000-0000-000000000001')
    INSERT INTO [Invoices] ([Id],[PackageId],[POId],[VersionNumber],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('E1000008-0000-0000-0000-000000000001','C1000008-0000-0000-0000-000000000001','D1000008-0000-0000-0000-000000000001',1,'invoice_pkg_008.pdf','https://placeholder.blob.core.windows.net/docs/invoice_pkg_008.pdf',102400,'application/pdf',0,0,GETUTCDATE(),GETUTCDATE());

PRINT 'Invoices seeded (8 rows)';

-- =========================================================
-- 7. CostSummaries (8 rows, one per package)
-- =========================================================
IF NOT EXISTS (SELECT 1 FROM [CostSummaries] WHERE [Id] = 'F1000001-0000-0000-0000-000000000001')
    INSERT INTO [CostSummaries] ([Id],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('F1000001-0000-0000-0000-000000000001','C1000001-0000-0000-0000-000000000001','cost_summary_001.pdf','https://placeholder.blob.core.windows.net/docs/cost_summary_001.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [CostSummaries] WHERE [Id] = 'F1000002-0000-0000-0000-000000000001')
    INSERT INTO [CostSummaries] ([Id],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('F1000002-0000-0000-0000-000000000001','C1000002-0000-0000-0000-000000000001','cost_summary_002.pdf','https://placeholder.blob.core.windows.net/docs/cost_summary_002.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [CostSummaries] WHERE [Id] = 'F1000003-0000-0000-0000-000000000001')
    INSERT INTO [CostSummaries] ([Id],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('F1000003-0000-0000-0000-000000000001','C1000003-0000-0000-0000-000000000001','cost_summary_003.pdf','https://placeholder.blob.core.windows.net/docs/cost_summary_003.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [CostSummaries] WHERE [Id] = 'F1000004-0000-0000-0000-000000000001')
    INSERT INTO [CostSummaries] ([Id],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('F1000004-0000-0000-0000-000000000001','C1000004-0000-0000-0000-000000000001','cost_summary_004.pdf','https://placeholder.blob.core.windows.net/docs/cost_summary_004.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [CostSummaries] WHERE [Id] = 'F1000005-0000-0000-0000-000000000001')
    INSERT INTO [CostSummaries] ([Id],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('F1000005-0000-0000-0000-000000000001','C1000005-0000-0000-0000-000000000001','cost_summary_005.pdf','https://placeholder.blob.core.windows.net/docs/cost_summary_005.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [CostSummaries] WHERE [Id] = 'F1000006-0000-0000-0000-000000000001')
    INSERT INTO [CostSummaries] ([Id],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('F1000006-0000-0000-0000-000000000001','C1000006-0000-0000-0000-000000000001','cost_summary_006.pdf','https://placeholder.blob.core.windows.net/docs/cost_summary_006.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [CostSummaries] WHERE [Id] = 'F1000007-0000-0000-0000-000000000001')
    INSERT INTO [CostSummaries] ([Id],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('F1000007-0000-0000-0000-000000000001','C1000007-0000-0000-0000-000000000001','cost_summary_007.pdf','https://placeholder.blob.core.windows.net/docs/cost_summary_007.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [CostSummaries] WHERE [Id] = 'F1000008-0000-0000-0000-000000000001')
    INSERT INTO [CostSummaries] ([Id],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('F1000008-0000-0000-0000-000000000001','C1000008-0000-0000-0000-000000000001','cost_summary_008.pdf','https://placeholder.blob.core.windows.net/docs/cost_summary_008.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

PRINT 'CostSummaries seeded (8 rows)';

-- =========================================================
-- 8. ActivitySummaries (8 rows, one per package)
-- =========================================================
IF NOT EXISTS (SELECT 1 FROM [ActivitySummaries] WHERE [Id] = '91000001-0000-0000-0000-000000000001')
    INSERT INTO [ActivitySummaries] ([Id],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('91000001-0000-0000-0000-000000000001','C1000001-0000-0000-0000-000000000001','activity_001.pdf','https://placeholder.blob.core.windows.net/docs/activity_001.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ActivitySummaries] WHERE [Id] = '91000002-0000-0000-0000-000000000001')
    INSERT INTO [ActivitySummaries] ([Id],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('91000002-0000-0000-0000-000000000001','C1000002-0000-0000-0000-000000000001','activity_002.pdf','https://placeholder.blob.core.windows.net/docs/activity_002.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ActivitySummaries] WHERE [Id] = '91000003-0000-0000-0000-000000000001')
    INSERT INTO [ActivitySummaries] ([Id],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('91000003-0000-0000-0000-000000000001','C1000003-0000-0000-0000-000000000001','activity_003.pdf','https://placeholder.blob.core.windows.net/docs/activity_003.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ActivitySummaries] WHERE [Id] = '91000004-0000-0000-0000-000000000001')
    INSERT INTO [ActivitySummaries] ([Id],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('91000004-0000-0000-0000-000000000001','C1000004-0000-0000-0000-000000000001','activity_004.pdf','https://placeholder.blob.core.windows.net/docs/activity_004.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ActivitySummaries] WHERE [Id] = '91000005-0000-0000-0000-000000000001')
    INSERT INTO [ActivitySummaries] ([Id],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('91000005-0000-0000-0000-000000000001','C1000005-0000-0000-0000-000000000001','activity_005.pdf','https://placeholder.blob.core.windows.net/docs/activity_005.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ActivitySummaries] WHERE [Id] = '91000006-0000-0000-0000-000000000001')
    INSERT INTO [ActivitySummaries] ([Id],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('91000006-0000-0000-0000-000000000001','C1000006-0000-0000-0000-000000000001','activity_006.pdf','https://placeholder.blob.core.windows.net/docs/activity_006.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ActivitySummaries] WHERE [Id] = '91000007-0000-0000-0000-000000000001')
    INSERT INTO [ActivitySummaries] ([Id],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('91000007-0000-0000-0000-000000000001','C1000007-0000-0000-0000-000000000001','activity_007.pdf','https://placeholder.blob.core.windows.net/docs/activity_007.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ActivitySummaries] WHERE [Id] = '91000008-0000-0000-0000-000000000001')
    INSERT INTO [ActivitySummaries] ([Id],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('91000008-0000-0000-0000-000000000001','C1000008-0000-0000-0000-000000000001','activity_008.pdf','https://placeholder.blob.core.windows.net/docs/activity_008.pdf',102400,'application/pdf',1,0,0,GETUTCDATE(),GETUTCDATE());

PRINT 'ActivitySummaries seeded (8 rows)';

-- =========================================================
-- 9. Teams (8 rows, one per package)
-- =========================================================
IF NOT EXISTS (SELECT 1 FROM [Teams] WHERE [Id] = '81000001-0000-0000-0000-000000000001')
    INSERT INTO [Teams] ([Id],[PackageId],[CampaignName],[TeamCode],[DealershipName],[VersionNumber],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('81000001-0000-0000-0000-000000000001','C1000001-0000-0000-0000-000000000001','Seed Campaign 1','TC-001','Bajaj Dealership Mumbai',1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [Teams] WHERE [Id] = '81000002-0000-0000-0000-000000000001')
    INSERT INTO [Teams] ([Id],[PackageId],[CampaignName],[TeamCode],[DealershipName],[VersionNumber],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('81000002-0000-0000-0000-000000000001','C1000002-0000-0000-0000-000000000001','Seed Campaign 2','TC-002','Bajaj Dealership Pune',1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [Teams] WHERE [Id] = '81000003-0000-0000-0000-000000000001')
    INSERT INTO [Teams] ([Id],[PackageId],[CampaignName],[TeamCode],[DealershipName],[VersionNumber],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('81000003-0000-0000-0000-000000000001','C1000003-0000-0000-0000-000000000001','Seed Campaign 3','TC-003','Bajaj Dealership Delhi',1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [Teams] WHERE [Id] = '81000004-0000-0000-0000-000000000001')
    INSERT INTO [Teams] ([Id],[PackageId],[CampaignName],[TeamCode],[DealershipName],[VersionNumber],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('81000004-0000-0000-0000-000000000001','C1000004-0000-0000-0000-000000000001','Seed Campaign 4','TC-004','Bajaj Dealership Bangalore',1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [Teams] WHERE [Id] = '81000005-0000-0000-0000-000000000001')
    INSERT INTO [Teams] ([Id],[PackageId],[CampaignName],[TeamCode],[DealershipName],[VersionNumber],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('81000005-0000-0000-0000-000000000001','C1000005-0000-0000-0000-000000000001','Seed Campaign 5','TC-005','Bajaj Dealership Chennai',1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [Teams] WHERE [Id] = '81000006-0000-0000-0000-000000000001')
    INSERT INTO [Teams] ([Id],[PackageId],[CampaignName],[TeamCode],[DealershipName],[VersionNumber],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('81000006-0000-0000-0000-000000000001','C1000006-0000-0000-0000-000000000001','Seed Campaign 6','TC-006','Bajaj Dealership Hyderabad',1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [Teams] WHERE [Id] = '81000007-0000-0000-0000-000000000001')
    INSERT INTO [Teams] ([Id],[PackageId],[CampaignName],[TeamCode],[DealershipName],[VersionNumber],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('81000007-0000-0000-0000-000000000001','C1000007-0000-0000-0000-000000000001','Seed Campaign 7','TC-007','Bajaj Dealership Ahmedabad',1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [Teams] WHERE [Id] = '81000008-0000-0000-0000-000000000001')
    INSERT INTO [Teams] ([Id],[PackageId],[CampaignName],[TeamCode],[DealershipName],[VersionNumber],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('81000008-0000-0000-0000-000000000001','C1000008-0000-0000-0000-000000000001','Seed Campaign 8','TC-008','Bajaj Dealership Kolkata',1,0,GETUTCDATE(),GETUTCDATE());

PRINT 'Teams seeded (8 rows)';

-- =========================================================
-- 10. TeamPhotos (8 rows, one per team)
-- =========================================================
IF NOT EXISTS (SELECT 1 FROM [TeamPhotos] WHERE [Id] = '71000001-0000-0000-0000-000000000001')
    INSERT INTO [TeamPhotos] ([Id],[TeamId],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[DisplayOrder],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('71000001-0000-0000-0000-000000000001','81000001-0000-0000-0000-000000000001','C1000001-0000-0000-0000-000000000001','photo_001.jpg','https://placeholder.blob.core.windows.net/docs/photo_001.jpg',204800,'image/jpeg',1,1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [TeamPhotos] WHERE [Id] = '71000002-0000-0000-0000-000000000001')
    INSERT INTO [TeamPhotos] ([Id],[TeamId],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[DisplayOrder],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('71000002-0000-0000-0000-000000000001','81000002-0000-0000-0000-000000000001','C1000002-0000-0000-0000-000000000001','photo_002.jpg','https://placeholder.blob.core.windows.net/docs/photo_002.jpg',204800,'image/jpeg',1,1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [TeamPhotos] WHERE [Id] = '71000003-0000-0000-0000-000000000001')
    INSERT INTO [TeamPhotos] ([Id],[TeamId],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[DisplayOrder],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('71000003-0000-0000-0000-000000000001','81000003-0000-0000-0000-000000000001','C1000003-0000-0000-0000-000000000001','photo_003.jpg','https://placeholder.blob.core.windows.net/docs/photo_003.jpg',204800,'image/jpeg',1,1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [TeamPhotos] WHERE [Id] = '71000004-0000-0000-0000-000000000001')
    INSERT INTO [TeamPhotos] ([Id],[TeamId],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[DisplayOrder],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('71000004-0000-0000-0000-000000000001','81000004-0000-0000-0000-000000000001','C1000004-0000-0000-0000-000000000001','photo_004.jpg','https://placeholder.blob.core.windows.net/docs/photo_004.jpg',204800,'image/jpeg',1,1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [TeamPhotos] WHERE [Id] = '71000005-0000-0000-0000-000000000001')
    INSERT INTO [TeamPhotos] ([Id],[TeamId],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[DisplayOrder],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('71000005-0000-0000-0000-000000000001','81000005-0000-0000-0000-000000000001','C1000005-0000-0000-0000-000000000001','photo_005.jpg','https://placeholder.blob.core.windows.net/docs/photo_005.jpg',204800,'image/jpeg',1,1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [TeamPhotos] WHERE [Id] = '71000006-0000-0000-0000-000000000001')
    INSERT INTO [TeamPhotos] ([Id],[TeamId],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[DisplayOrder],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('71000006-0000-0000-0000-000000000001','81000006-0000-0000-0000-000000000001','C1000006-0000-0000-0000-000000000001','photo_006.jpg','https://placeholder.blob.core.windows.net/docs/photo_006.jpg',204800,'image/jpeg',1,1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [TeamPhotos] WHERE [Id] = '71000007-0000-0000-0000-000000000001')
    INSERT INTO [TeamPhotos] ([Id],[TeamId],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[DisplayOrder],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('71000007-0000-0000-0000-000000000001','81000007-0000-0000-0000-000000000001','C1000007-0000-0000-0000-000000000001','photo_007.jpg','https://placeholder.blob.core.windows.net/docs/photo_007.jpg',204800,'image/jpeg',1,1,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [TeamPhotos] WHERE [Id] = '71000008-0000-0000-0000-000000000001')
    INSERT INTO [TeamPhotos] ([Id],[TeamId],[PackageId],[FileName],[BlobUrl],[FileSizeBytes],[ContentType],[DisplayOrder],[VersionNumber],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('71000008-0000-0000-0000-000000000001','81000008-0000-0000-0000-000000000001','C1000008-0000-0000-0000-000000000001','photo_008.jpg','https://placeholder.blob.core.windows.net/docs/photo_008.jpg',204800,'image/jpeg',1,1,0,0,GETUTCDATE(),GETUTCDATE());

PRINT 'TeamPhotos seeded (8 rows)';

-- =========================================================
-- 11. ValidationResults (24 rows — PKG-003..PKG-008, State>=3, DocumentTypes 1-4)
-- DocumentType: PO=1, Invoice=2, CostSummary=3, ActivitySummary=4
-- =========================================================
-- PKG-003
IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A300001-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A300001-0000-0000-0000-000000000001',1,'D1000003-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A300002-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A300002-0000-0000-0000-000000000001',2,'E1000003-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A300003-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A300003-0000-0000-0000-000000000001',3,'F1000003-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A300004-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A300004-0000-0000-0000-000000000001',4,'91000003-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

-- PKG-004
IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A400001-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A400001-0000-0000-0000-000000000001',1,'D1000004-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A400002-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A400002-0000-0000-0000-000000000001',2,'E1000004-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A400003-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A400003-0000-0000-0000-000000000001',3,'F1000004-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A400004-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A400004-0000-0000-0000-000000000001',4,'91000004-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

-- PKG-005
IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A500001-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A500001-0000-0000-0000-000000000001',1,'D1000005-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A500002-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A500002-0000-0000-0000-000000000001',2,'E1000005-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A500003-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A500003-0000-0000-0000-000000000001',3,'F1000005-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A500004-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A500004-0000-0000-0000-000000000001',4,'91000005-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

-- PKG-006
IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A600001-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A600001-0000-0000-0000-000000000001',1,'D1000006-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A600002-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A600002-0000-0000-0000-000000000001',2,'E1000006-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A600003-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A600003-0000-0000-0000-000000000001',3,'F1000006-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A600004-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A600004-0000-0000-0000-000000000001',4,'91000006-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

-- PKG-007
IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A700001-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A700001-0000-0000-0000-000000000001',1,'D1000007-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A700002-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A700002-0000-0000-0000-000000000001',2,'E1000007-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A700003-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A700003-0000-0000-0000-000000000001',3,'F1000007-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A700004-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A700004-0000-0000-0000-000000000001',4,'91000007-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

-- PKG-008
IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A800001-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A800001-0000-0000-0000-000000000001',1,'D1000008-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A800002-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A800002-0000-0000-0000-000000000001',2,'E1000008-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A800003-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A800003-0000-0000-0000-000000000001',3,'F1000008-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ValidationResults] WHERE [Id] = '3A800004-0000-0000-0000-000000000001')
    INSERT INTO [ValidationResults] ([Id],[DocumentType],[DocumentId],[SapVerificationPassed],[AmountConsistencyPassed],[LineItemMatchingPassed],[CompletenessCheckPassed],[DateValidationPassed],[VendorMatchingPassed],[AllValidationsPassed],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3A800004-0000-0000-0000-000000000001',4,'91000008-0000-0000-0000-000000000001',1,1,1,1,1,1,1,0,GETUTCDATE(),GETUTCDATE());

PRINT 'ValidationResults seeded (24 rows)';

-- =========================================================
-- 12. ConfidenceScores (5 rows — PKG-004..PKG-008, State>=4)
-- OverallConfidence = Po*0.30 + Invoice*0.30 + CostSummary*0.20 + Activity*0.10 + Photos*0.10
-- = 85*0.30 + 80*0.30 + 75*0.20 + 70*0.10 + 90*0.10 = 25.5+24.0+15.0+7.0+9.0 = 80.5
-- =========================================================
IF NOT EXISTS (SELECT 1 FROM [ConfidenceScores] WHERE [Id] = '3B400001-0000-0000-0000-000000000001')
    INSERT INTO [ConfidenceScores] ([Id],[PackageId],[PoConfidence],[InvoiceConfidence],[CostSummaryConfidence],[ActivityConfidence],[PhotosConfidence],[OverallConfidence],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3B400001-0000-0000-0000-000000000001','C1000004-0000-0000-0000-000000000001',85.0,80.0,75.0,70.0,90.0,80.5,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ConfidenceScores] WHERE [Id] = '3B500001-0000-0000-0000-000000000001')
    INSERT INTO [ConfidenceScores] ([Id],[PackageId],[PoConfidence],[InvoiceConfidence],[CostSummaryConfidence],[ActivityConfidence],[PhotosConfidence],[OverallConfidence],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3B500001-0000-0000-0000-000000000001','C1000005-0000-0000-0000-000000000001',85.0,80.0,75.0,70.0,90.0,80.5,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ConfidenceScores] WHERE [Id] = '3B600001-0000-0000-0000-000000000001')
    INSERT INTO [ConfidenceScores] ([Id],[PackageId],[PoConfidence],[InvoiceConfidence],[CostSummaryConfidence],[ActivityConfidence],[PhotosConfidence],[OverallConfidence],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3B600001-0000-0000-0000-000000000001','C1000006-0000-0000-0000-000000000001',85.0,80.0,75.0,70.0,90.0,80.5,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ConfidenceScores] WHERE [Id] = '3B700001-0000-0000-0000-000000000001')
    INSERT INTO [ConfidenceScores] ([Id],[PackageId],[PoConfidence],[InvoiceConfidence],[CostSummaryConfidence],[ActivityConfidence],[PhotosConfidence],[OverallConfidence],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3B700001-0000-0000-0000-000000000001','C1000007-0000-0000-0000-000000000001',85.0,80.0,75.0,70.0,90.0,80.5,0,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [ConfidenceScores] WHERE [Id] = '3B800001-0000-0000-0000-000000000001')
    INSERT INTO [ConfidenceScores] ([Id],[PackageId],[PoConfidence],[InvoiceConfidence],[CostSummaryConfidence],[ActivityConfidence],[PhotosConfidence],[OverallConfidence],[IsFlaggedForReview],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3B800001-0000-0000-0000-000000000001','C1000008-0000-0000-0000-000000000001',85.0,80.0,75.0,70.0,90.0,80.5,0,0,GETUTCDATE(),GETUTCDATE());

PRINT 'ConfidenceScores seeded (5 rows)';

-- =========================================================
-- 13. Recommendations (5 rows — PKG-004..PKG-008)
-- RecommendationType: Approve=1, Review=2, Reject=3
-- =========================================================
IF NOT EXISTS (SELECT 1 FROM [Recommendations] WHERE [Id] = '3C400001-0000-0000-0000-000000000001')
    INSERT INTO [Recommendations] ([Id],[PackageId],[Type],[Evidence],[ConfidenceScore],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3C400001-0000-0000-0000-000000000001','C1000004-0000-0000-0000-000000000001',1,'All documents validated successfully. Amounts consistent across PO, Invoice, and Cost Summary.',80.5,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [Recommendations] WHERE [Id] = '3C500001-0000-0000-0000-000000000001')
    INSERT INTO [Recommendations] ([Id],[PackageId],[Type],[Evidence],[ConfidenceScore],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3C500001-0000-0000-0000-000000000001','C1000005-0000-0000-0000-000000000001',3,'Amount discrepancy detected between Invoice and Cost Summary. Manual review required.',80.5,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [Recommendations] WHERE [Id] = '3C600001-0000-0000-0000-000000000001')
    INSERT INTO [Recommendations] ([Id],[PackageId],[Type],[Evidence],[ConfidenceScore],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3C600001-0000-0000-0000-000000000001','C1000006-0000-0000-0000-000000000001',2,'Documents appear valid but require secondary review for compliance.',80.5,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [Recommendations] WHERE [Id] = '3C700001-0000-0000-0000-000000000001')
    INSERT INTO [Recommendations] ([Id],[PackageId],[Type],[Evidence],[ConfidenceScore],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3C700001-0000-0000-0000-000000000001','C1000007-0000-0000-0000-000000000001',2,'Minor inconsistencies found. Recommend review before final approval.',80.5,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [Recommendations] WHERE [Id] = '3C800001-0000-0000-0000-000000000001')
    INSERT INTO [Recommendations] ([Id],[PackageId],[Type],[Evidence],[ConfidenceScore],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3C800001-0000-0000-0000-000000000001','C1000008-0000-0000-0000-000000000001',1,'All validations passed. Package approved by both ASM and RA.',80.5,0,GETUTCDATE(),GETUTCDATE());

PRINT 'Recommendations seeded (5 rows)';

-- =========================================================
-- 14. RequestApprovalHistory
-- ApprovalAction: Submitted=1, Approved=2, Rejected=3
-- UserRole: Agency=1, ASM=2, RA=3
-- =========================================================
DECLARE @AgencyUserIdH  UNIQUEIDENTIFIER = (SELECT [Id] FROM [Users] WHERE [Email] = 'agency@bajaj.com');
DECLARE @AsmUserId      UNIQUEIDENTIFIER = (SELECT [Id] FROM [Users] WHERE [Email] = 'asm@bajaj.com');
DECLARE @RaUserId       UNIQUEIDENTIFIER = (SELECT [Id] FROM [Users] WHERE [Email] = 'ra@bajaj.com');

-- Submitted rows (all 8 packages)
IF NOT EXISTS (SELECT 1 FROM [RequestApprovalHistory] WHERE [Id] = '3D100001-0000-0000-0000-000000000001')
    INSERT INTO [RequestApprovalHistory] ([Id],[PackageId],[ApproverId],[ApproverRole],[Action],[ActionDate],[VersionNumber],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3D100001-0000-0000-0000-000000000001','C1000001-0000-0000-0000-000000000001',@AgencyUserIdH,1,1,GETUTCDATE(),1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [RequestApprovalHistory] WHERE [Id] = '3D200001-0000-0000-0000-000000000001')
    INSERT INTO [RequestApprovalHistory] ([Id],[PackageId],[ApproverId],[ApproverRole],[Action],[ActionDate],[VersionNumber],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3D200001-0000-0000-0000-000000000001','C1000002-0000-0000-0000-000000000001',@AgencyUserIdH,1,1,GETUTCDATE(),1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [RequestApprovalHistory] WHERE [Id] = '3D300001-0000-0000-0000-000000000001')
    INSERT INTO [RequestApprovalHistory] ([Id],[PackageId],[ApproverId],[ApproverRole],[Action],[ActionDate],[VersionNumber],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3D300001-0000-0000-0000-000000000001','C1000003-0000-0000-0000-000000000001',@AgencyUserIdH,1,1,GETUTCDATE(),1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [RequestApprovalHistory] WHERE [Id] = '3D400001-0000-0000-0000-000000000001')
    INSERT INTO [RequestApprovalHistory] ([Id],[PackageId],[ApproverId],[ApproverRole],[Action],[ActionDate],[VersionNumber],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3D400001-0000-0000-0000-000000000001','C1000004-0000-0000-0000-000000000001',@AgencyUserIdH,1,1,GETUTCDATE(),1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [RequestApprovalHistory] WHERE [Id] = '3D500001-0000-0000-0000-000000000001')
    INSERT INTO [RequestApprovalHistory] ([Id],[PackageId],[ApproverId],[ApproverRole],[Action],[ActionDate],[VersionNumber],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3D500001-0000-0000-0000-000000000001','C1000005-0000-0000-0000-000000000001',@AgencyUserIdH,1,1,GETUTCDATE(),1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [RequestApprovalHistory] WHERE [Id] = '3D600001-0000-0000-0000-000000000001')
    INSERT INTO [RequestApprovalHistory] ([Id],[PackageId],[ApproverId],[ApproverRole],[Action],[ActionDate],[VersionNumber],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3D600001-0000-0000-0000-000000000001','C1000006-0000-0000-0000-000000000001',@AgencyUserIdH,1,1,GETUTCDATE(),1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [RequestApprovalHistory] WHERE [Id] = '3D700001-0000-0000-0000-000000000001')
    INSERT INTO [RequestApprovalHistory] ([Id],[PackageId],[ApproverId],[ApproverRole],[Action],[ActionDate],[VersionNumber],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3D700001-0000-0000-0000-000000000001','C1000007-0000-0000-0000-000000000001',@AgencyUserIdH,1,1,GETUTCDATE(),1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [RequestApprovalHistory] WHERE [Id] = '3D800001-0000-0000-0000-000000000001')
    INSERT INTO [RequestApprovalHistory] ([Id],[PackageId],[ApproverId],[ApproverRole],[Action],[ActionDate],[VersionNumber],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3D800001-0000-0000-0000-000000000001','C1000008-0000-0000-0000-000000000001',@AgencyUserIdH,1,1,GETUTCDATE(),1,0,GETUTCDATE(),GETUTCDATE());

-- PKG-005: ASM Rejected
IF NOT EXISTS (SELECT 1 FROM [RequestApprovalHistory] WHERE [Id] = '3D500002-0000-0000-0000-000000000001')
    INSERT INTO [RequestApprovalHistory] ([Id],[PackageId],[ApproverId],[ApproverRole],[Action],[Comments],[ActionDate],[VersionNumber],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3D500002-0000-0000-0000-000000000001','C1000005-0000-0000-0000-000000000001',@AsmUserId,2,3,'Amount discrepancy detected. Please resubmit with corrected invoice.',GETUTCDATE(),1,0,GETUTCDATE(),GETUTCDATE());

-- PKG-006: ASM Approved
IF NOT EXISTS (SELECT 1 FROM [RequestApprovalHistory] WHERE [Id] = '3D600002-0000-0000-0000-000000000001')
    INSERT INTO [RequestApprovalHistory] ([Id],[PackageId],[ApproverId],[ApproverRole],[Action],[Comments],[ActionDate],[VersionNumber],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3D600002-0000-0000-0000-000000000001','C1000006-0000-0000-0000-000000000001',@AsmUserId,2,2,'Documents verified. Forwarding to RA for final approval.',GETUTCDATE(),1,0,GETUTCDATE(),GETUTCDATE());

-- PKG-007: ASM Approved + RA Rejected
IF NOT EXISTS (SELECT 1 FROM [RequestApprovalHistory] WHERE [Id] = '3D700002-0000-0000-0000-000000000001')
    INSERT INTO [RequestApprovalHistory] ([Id],[PackageId],[ApproverId],[ApproverRole],[Action],[Comments],[ActionDate],[VersionNumber],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3D700002-0000-0000-0000-000000000001','C1000007-0000-0000-0000-000000000001',@AsmUserId,2,2,'Approved by ASM. Forwarding to RA.',GETUTCDATE(),1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [RequestApprovalHistory] WHERE [Id] = '3D700003-0000-0000-0000-000000000001')
    INSERT INTO [RequestApprovalHistory] ([Id],[PackageId],[ApproverId],[ApproverRole],[Action],[Comments],[ActionDate],[VersionNumber],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3D700003-0000-0000-0000-000000000001','C1000007-0000-0000-0000-000000000001',@RaUserId,3,3,'Compliance issue found. Package rejected at RA level.',GETUTCDATE(),1,0,GETUTCDATE(),GETUTCDATE());

-- PKG-008: ASM Approved + RA Approved
IF NOT EXISTS (SELECT 1 FROM [RequestApprovalHistory] WHERE [Id] = '3D800002-0000-0000-0000-000000000001')
    INSERT INTO [RequestApprovalHistory] ([Id],[PackageId],[ApproverId],[ApproverRole],[Action],[Comments],[ActionDate],[VersionNumber],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3D800002-0000-0000-0000-000000000001','C1000008-0000-0000-0000-000000000001',@AsmUserId,2,2,'All documents verified and approved by ASM.',GETUTCDATE(),1,0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [RequestApprovalHistory] WHERE [Id] = '3D800003-0000-0000-0000-000000000001')
    INSERT INTO [RequestApprovalHistory] ([Id],[PackageId],[ApproverId],[ApproverRole],[Action],[Comments],[ActionDate],[VersionNumber],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3D800003-0000-0000-0000-000000000001','C1000008-0000-0000-0000-000000000001',@RaUserId,3,2,'Final approval granted. Package fully approved.',GETUTCDATE(),1,0,GETUTCDATE(),GETUTCDATE());

PRINT 'RequestApprovalHistory seeded (13 rows)';

-- =========================================================
-- 15. Notifications (3 rows for agency user)
-- NotificationType: SubmissionReceived=1, Approved=3, Rejected=4
-- =========================================================
DECLARE @AgencyUserIdN UNIQUEIDENTIFIER = (SELECT [Id] FROM [Users] WHERE [Email] = 'agency@bajaj.com');

IF NOT EXISTS (SELECT 1 FROM [Notifications] WHERE [Id] = '3E100001-0000-0000-0000-000000000001')
    INSERT INTO [Notifications] ([Id],[UserId],[Type],[Title],[Message],[IsRead],[RelatedEntityId],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3E100001-0000-0000-0000-000000000001',@AgencyUserIdN,1,'Submission Received','Your document package PKG-001 has been received and is being processed.',0,'C1000001-0000-0000-0000-000000000001',0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [Notifications] WHERE [Id] = '3E100002-0000-0000-0000-000000000001')
    INSERT INTO [Notifications] ([Id],[UserId],[Type],[Title],[Message],[IsRead],[RelatedEntityId],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3E100002-0000-0000-0000-000000000001',@AgencyUserIdN,4,'Package Rejected','Your document package PKG-005 has been rejected by the ASM. Please review the comments and resubmit.',0,'C1000005-0000-0000-0000-000000000001',0,GETUTCDATE(),GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM [Notifications] WHERE [Id] = '3E100003-0000-0000-0000-000000000001')
    INSERT INTO [Notifications] ([Id],[UserId],[Type],[Title],[Message],[IsRead],[RelatedEntityId],[IsDeleted],[CreatedAt],[UpdatedAt])
    VALUES ('3E100003-0000-0000-0000-000000000001',@AgencyUserIdN,3,'Package Approved','Congratulations! Your document package PKG-008 has been fully approved.',1,'C1000008-0000-0000-0000-000000000001',0,GETUTCDATE(),GETUTCDATE());

PRINT 'Notifications seeded (3 rows)';

-- =========================================================
-- Summary
-- =========================================================
PRINT '----------------------------------------------------';
PRINT 'seed_dummy_data.sql completed successfully.';
PRINT 'Seeded: 1 Agency, 1 ASM, 8 DocumentPackages (States 1-8),';
PRINT '        8 POs, 8 Invoices, 8 CostSummaries, 8 ActivitySummaries,';
PRINT '        8 Teams, 8 TeamPhotos, 24 ValidationResults,';
PRINT '        5 ConfidenceScores, 5 Recommendations,';
PRINT '        13 RequestApprovalHistory rows, 3 Notifications.';
PRINT 'agency@bajaj.com linked to Agency (if not already linked).';
PRINT '----------------------------------------------------';

COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    DECLARE @ErrorMessage  NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT            = ERROR_SEVERITY();
    DECLARE @ErrorState    INT            = ERROR_STATE();

    PRINT 'ERROR: seed_dummy_data.sql failed - transaction rolled back.';
    PRINT @ErrorMessage;
    RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
END CATCH;
