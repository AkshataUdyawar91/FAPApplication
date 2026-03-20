-- =============================================
-- Seed Script: Teams Bot Testing Data
-- Purpose: Insert test submissions with full related data
--          so the Teams bot can display adaptive cards
-- Database: BajajDocumentProcessing (localhost\SQLEXPRESS)
-- =============================================

SET NOCOUNT ON;

-- Known user IDs from seed data
DECLARE @AgencyUserId UNIQUEIDENTIFIER = '4AED005F-D377-4929-BC22-CAFB35EA6AE2'; -- agency@bajaj.com
DECLARE @ASMUserId    UNIQUEIDENTIFIER = '3418DB05-AAFD-40C0-AE92-EDD11FF49B67'; -- asm@bajaj.com

-- =============================================
-- 1. Agency (if not exists)
-- =============================================
DECLARE @AgencyId UNIQUEIDENTIFIER = 'A1000001-0000-0000-0000-000000000001';

IF NOT EXISTS (SELECT 1 FROM Agencies WHERE Id = @AgencyId)
BEGIN
    INSERT INTO Agencies (Id, SupplierCode, SupplierName, CreatedAt, IsDeleted)
    VALUES (@AgencyId, 'SUP-MH-001', 'Pinnacle Advertising Pvt Ltd', GETUTCDATE(), 0);
    PRINT 'Inserted Agency: Pinnacle Advertising Pvt Ltd';
END

-- =============================================
-- 2. Three DocumentPackages in different states for testing
-- =============================================

-- Package 1: PendingASM, High confidence (Approve recommendation)
DECLARE @Pkg1Id UNIQUEIDENTIFIER = '28C9823C-1111-4000-A000-000000000001';
-- Package 2: PendingASM, Medium confidence (Review recommendation)
DECLARE @Pkg2Id UNIQUEIDENTIFIER = '7F3B45DA-2222-4000-A000-000000000002';
-- Package 3: PendingASM, Low confidence (Reject recommendation)
DECLARE @Pkg3Id UNIQUEIDENTIFIER = 'E5A1C8F2-3333-4000-A000-000000000003';

-- Insert packages (State 4 = PendingASM)
IF NOT EXISTS (SELECT 1 FROM DocumentPackages WHERE Id = @Pkg1Id)
BEGIN
    INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, VersionNumber, State, CreatedAt, IsDeleted)
    VALUES (@Pkg1Id, @AgencyId, @AgencyUserId, 1, 4, DATEADD(HOUR, -2, GETUTCDATE()), 0);
    PRINT 'Inserted Package 1 (High confidence - Approve): FAP-28C9823C';
END

IF NOT EXISTS (SELECT 1 FROM DocumentPackages WHERE Id = @Pkg2Id)
BEGIN
    INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, VersionNumber, State, CreatedAt, IsDeleted)
    VALUES (@Pkg2Id, @AgencyId, @AgencyUserId, 1, 4, DATEADD(HOUR, -1, GETUTCDATE()), 0);
    PRINT 'Inserted Package 2 (Medium confidence - Review): FAP-7F3B45DA';
END

IF NOT EXISTS (SELECT 1 FROM DocumentPackages WHERE Id = @Pkg3Id)
BEGIN
    INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, VersionNumber, State, CreatedAt, IsDeleted)
    VALUES (@Pkg3Id, @AgencyId, @AgencyUserId, 1, 4, DATEADD(MINUTE, -30, GETUTCDATE()), 0);
    PRINT 'Inserted Package 3 (Low confidence - Reject): FAP-E5A1C8F2';
END


-- =============================================
-- 3. POs (one per package)
-- =============================================
DECLARE @PO1Id UNIQUEIDENTIFIER = NEWID();
DECLARE @PO2Id UNIQUEIDENTIFIER = NEWID();
DECLARE @PO3Id UNIQUEIDENTIFIER = NEWID();

IF NOT EXISTS (SELECT 1 FROM POs WHERE PackageId = @Pkg1Id)
BEGIN
    INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount,
                     FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, IsDeleted)
    VALUES (@PO1Id, @Pkg1Id, @AgencyId, 'PO-2026-00451', '2026-02-15', 'Pinnacle Advertising Pvt Ltd', 285000.00,
            'PO_00451.pdf', '/local/PO_00451.pdf', 125000, 'application/pdf', 0, 1, GETUTCDATE(), 0);
    PRINT 'Inserted PO for Package 1: PO-2026-00451';
END

IF NOT EXISTS (SELECT 1 FROM POs WHERE PackageId = @Pkg2Id)
BEGIN
    INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount,
                     FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, IsDeleted)
    VALUES (@PO2Id, @Pkg2Id, @AgencyId, 'PO-2026-00523', '2026-03-01', 'Pinnacle Advertising Pvt Ltd', 175000.00,
            'PO_00523.pdf', '/local/PO_00523.pdf', 98000, 'application/pdf', 0, 1, GETUTCDATE(), 0);
    PRINT 'Inserted PO for Package 2: PO-2026-00523';
END

IF NOT EXISTS (SELECT 1 FROM POs WHERE PackageId = @Pkg3Id)
BEGIN
    INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount,
                     FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, IsDeleted)
    VALUES (@PO3Id, @Pkg3Id, @AgencyId, 'PO-2026-00610', '2026-03-10', 'Pinnacle Advertising Pvt Ltd', 420000.00,
            'PO_00610.pdf', '/local/PO_00610.pdf', 110000, 'application/pdf', 0, 1, GETUTCDATE(), 0);
    PRINT 'Inserted PO for Package 3: PO-2026-00610';
END

-- =============================================
-- 4. Teams (campaign teams) — 3 teams for Pkg1, 2 for Pkg2, 1 for Pkg3
-- =============================================
DECLARE @Team1A UNIQUEIDENTIFIER = NEWID();
DECLARE @Team1B UNIQUEIDENTIFIER = NEWID();
DECLARE @Team1C UNIQUEIDENTIFIER = NEWID();
DECLARE @Team2A UNIQUEIDENTIFIER = NEWID();
DECLARE @Team2B UNIQUEIDENTIFIER = NEWID();
DECLARE @Team3A UNIQUEIDENTIFIER = NEWID();

IF NOT EXISTS (SELECT 1 FROM Teams WHERE PackageId = @Pkg1Id)
BEGIN
    INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, DealershipAddress, State, VersionNumber, CreatedAt, IsDeleted)
    VALUES
        (@Team1A, @Pkg1Id, 'Pulsar NS200 Launch', 'TM-MH-001', '2026-02-01', '2026-02-28', 20, 'Sharma Motors', '123 MG Road, Pune', 'Maharashtra', 1, GETUTCDATE(), 0),
        (@Team1B, @Pkg1Id, 'Pulsar NS200 Launch', 'TM-MH-002', '2026-02-01', '2026-02-28', 18, 'Patil Auto', '456 FC Road, Pune', 'Maharashtra', 1, GETUTCDATE(), 0),
        (@Team1C, @Pkg1Id, 'Pulsar NS200 Launch', 'TM-MH-003', '2026-02-01', '2026-02-28', 22, 'Deshmukh Bajaj', '789 JM Road, Pune', 'Maharashtra', 1, GETUTCDATE(), 0);
    PRINT 'Inserted 3 Teams for Package 1';
END

IF NOT EXISTS (SELECT 1 FROM Teams WHERE PackageId = @Pkg2Id)
BEGIN
    INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, DealershipAddress, State, VersionNumber, CreatedAt, IsDeleted)
    VALUES
        (@Team2A, @Pkg2Id, 'Dominar 400 Promo', 'TM-KA-001', '2026-02-15', '2026-03-15', 15, 'Bangalore Bajaj', '100 Brigade Road, Bangalore', 'Karnataka', 1, GETUTCDATE(), 0),
        (@Team2B, @Pkg2Id, 'Dominar 400 Promo', 'TM-KA-002', '2026-02-15', '2026-03-15', 12, 'Mysore Motors', '200 Sayyaji Rao Road, Mysore', 'Karnataka', 1, GETUTCDATE(), 0);
    PRINT 'Inserted 2 Teams for Package 2';
END

IF NOT EXISTS (SELECT 1 FROM Teams WHERE PackageId = @Pkg3Id)
BEGIN
    INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, DealershipAddress, State, VersionNumber, CreatedAt, IsDeleted)
    VALUES
        (@Team3A, @Pkg3Id, 'CT125X Rural Push', 'TM-RJ-001', '2026-03-01', '2026-03-31', 10, 'Jaipur Bajaj Center', '50 MI Road, Jaipur', 'Rajasthan', 1, GETUTCDATE(), 0);
    PRINT 'Inserted 1 Team for Package 3';
END


-- =============================================
-- 5. CampaignInvoices (one per team)
-- =============================================
-- Need to re-select Team IDs since they were generated with NEWID()
-- Use deterministic approach: query by PackageId

IF NOT EXISTS (SELECT 1 FROM CampaignInvoices WHERE PackageId = @Pkg1Id)
BEGIN
    DECLARE @T1A UNIQUEIDENTIFIER, @T1B UNIQUEIDENTIFIER, @T1C UNIQUEIDENTIFIER;
    SELECT TOP 1 @T1A = Id FROM Teams WHERE PackageId = @Pkg1Id AND TeamCode = 'TM-MH-001';
    SELECT TOP 1 @T1B = Id FROM Teams WHERE PackageId = @Pkg1Id AND TeamCode = 'TM-MH-002';
    SELECT TOP 1 @T1C = Id FROM Teams WHERE PackageId = @Pkg1Id AND TeamCode = 'TM-MH-003';

    INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount,
                                   FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, CreatedAt, IsDeleted)
    VALUES
        (NEWID(), @T1A, @Pkg1Id, 'INV-2026-1001', '2026-03-05', 'Pinnacle Advertising', '27AABCP1234A1Z5', 85000.00, 15300.00, 100300.00,
         'INV_1001.pdf', '/local/INV_1001.pdf', 95000, 'application/pdf', 0, GETUTCDATE(), 0),
        (NEWID(), @T1B, @Pkg1Id, 'INV-2026-1002', '2026-03-05', 'Pinnacle Advertising', '27AABCP1234A1Z5', 78000.00, 14040.00, 92040.00,
         'INV_1002.pdf', '/local/INV_1002.pdf', 88000, 'application/pdf', 0, GETUTCDATE(), 0),
        (NEWID(), @T1C, @Pkg1Id, 'INV-2026-1003', '2026-03-05', 'Pinnacle Advertising', '27AABCP1234A1Z5', 80000.00, 14400.00, 94400.00,
         'INV_1003.pdf', '/local/INV_1003.pdf', 91000, 'application/pdf', 0, GETUTCDATE(), 0);
    PRINT 'Inserted 3 Invoices for Package 1 (total: 286,740)';
END

IF NOT EXISTS (SELECT 1 FROM CampaignInvoices WHERE PackageId = @Pkg2Id)
BEGIN
    DECLARE @T2A UNIQUEIDENTIFIER, @T2B UNIQUEIDENTIFIER;
    SELECT TOP 1 @T2A = Id FROM Teams WHERE PackageId = @Pkg2Id AND TeamCode = 'TM-KA-001';
    SELECT TOP 1 @T2B = Id FROM Teams WHERE PackageId = @Pkg2Id AND TeamCode = 'TM-KA-002';

    INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount,
                                   FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, CreatedAt, IsDeleted)
    VALUES
        (NEWID(), @T2A, @Pkg2Id, 'INV-2026-2001', '2026-03-12', 'Pinnacle Advertising', '27AABCP1234A1Z5', 65000.00, 11700.00, 76700.00,
         'INV_2001.pdf', '/local/INV_2001.pdf', 82000, 'application/pdf', 0, GETUTCDATE(), 0),
        (NEWID(), @T2B, @Pkg2Id, 'INV-2026-2002', '2026-03-12', 'Pinnacle Advertising', '27AABCP1234A1Z5', 55000.00, 9900.00, 64900.00,
         'INV_2002.pdf', '/local/INV_2002.pdf', 78000, 'application/pdf', 0, GETUTCDATE(), 0);
    PRINT 'Inserted 2 Invoices for Package 2 (total: 141,600)';
END

IF NOT EXISTS (SELECT 1 FROM CampaignInvoices WHERE PackageId = @Pkg3Id)
BEGIN
    DECLARE @T3A UNIQUEIDENTIFIER;
    SELECT TOP 1 @T3A = Id FROM Teams WHERE PackageId = @Pkg3Id AND TeamCode = 'TM-RJ-001';

    INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount,
                                   FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, CreatedAt, IsDeleted)
    VALUES
        (NEWID(), @T3A, @Pkg3Id, 'INV-2026-3001', '2026-03-14', 'Pinnacle Advertising', '27AABCP1234A1Z5', 350000.00, 63000.00, 413000.00,
         'INV_3001.pdf', '/local/INV_3001.pdf', 105000, 'application/pdf', 1, GETUTCDATE(), 0);
    PRINT 'Inserted 1 Invoice for Package 3 (total: 413,000 - flagged)';
END

-- =============================================
-- 6. TeamPhotos (varied counts per package)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM TeamPhotos WHERE PackageId = @Pkg1Id)
BEGIN
    DECLARE @TP1A UNIQUEIDENTIFIER;
    SELECT TOP 1 @TP1A = Id FROM Teams WHERE PackageId = @Pkg1Id AND TeamCode = 'TM-MH-001';

    -- 7 photos for team 1A
    DECLARE @i INT = 1;
    WHILE @i <= 7
    BEGIN
        INSERT INTO TeamPhotos (Id, TeamId, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, Caption, IsFlaggedForReview, DisplayOrder, VersionNumber, CreatedAt, IsDeleted)
        VALUES (NEWID(), @TP1A, @Pkg1Id, 'photo_1A_' + CAST(@i AS VARCHAR) + '.jpg', '/local/photo_1A_' + CAST(@i AS VARCHAR) + '.jpg',
                250000, 'image/jpeg', 'Event photo ' + CAST(@i AS VARCHAR), 0, @i, 1, GETUTCDATE(), 0);
        SET @i = @i + 1;
    END

    -- 6 photos for team 1B
    DECLARE @TP1B UNIQUEIDENTIFIER;
    SELECT TOP 1 @TP1B = Id FROM Teams WHERE PackageId = @Pkg1Id AND TeamCode = 'TM-MH-002';
    SET @i = 1;
    WHILE @i <= 6
    BEGIN
        INSERT INTO TeamPhotos (Id, TeamId, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, Caption, IsFlaggedForReview, DisplayOrder, VersionNumber, CreatedAt, IsDeleted)
        VALUES (NEWID(), @TP1B, @Pkg1Id, 'photo_1B_' + CAST(@i AS VARCHAR) + '.jpg', '/local/photo_1B_' + CAST(@i AS VARCHAR) + '.jpg',
                230000, 'image/jpeg', 'Event photo ' + CAST(@i AS VARCHAR), 0, @i, 1, GETUTCDATE(), 0);
        SET @i = @i + 1;
    END

    -- 6 photos for team 1C
    DECLARE @TP1C UNIQUEIDENTIFIER;
    SELECT TOP 1 @TP1C = Id FROM Teams WHERE PackageId = @Pkg1Id AND TeamCode = 'TM-MH-003';
    SET @i = 1;
    WHILE @i <= 6
    BEGIN
        INSERT INTO TeamPhotos (Id, TeamId, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, Caption, IsFlaggedForReview, DisplayOrder, VersionNumber, CreatedAt, IsDeleted)
        VALUES (NEWID(), @TP1C, @Pkg1Id, 'photo_1C_' + CAST(@i AS VARCHAR) + '.jpg', '/local/photo_1C_' + CAST(@i AS VARCHAR) + '.jpg',
                240000, 'image/jpeg', 'Event photo ' + CAST(@i AS VARCHAR), 0, @i, 1, GETUTCDATE(), 0);
        SET @i = @i + 1;
    END
    PRINT 'Inserted 19 photos for Package 1 (3 teams)';
END

IF NOT EXISTS (SELECT 1 FROM TeamPhotos WHERE PackageId = @Pkg2Id)
BEGIN
    DECLARE @TP2A UNIQUEIDENTIFIER;
    SELECT TOP 1 @TP2A = Id FROM Teams WHERE PackageId = @Pkg2Id AND TeamCode = 'TM-KA-001';
    SET @i = 1;
    WHILE @i <= 5
    BEGIN
        INSERT INTO TeamPhotos (Id, TeamId, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, Caption, IsFlaggedForReview, DisplayOrder, VersionNumber, CreatedAt, IsDeleted)
        VALUES (NEWID(), @TP2A, @Pkg2Id, 'photo_2A_' + CAST(@i AS VARCHAR) + '.jpg', '/local/photo_2A_' + CAST(@i AS VARCHAR) + '.jpg',
                220000, 'image/jpeg', 'Promo photo ' + CAST(@i AS VARCHAR), 0, @i, 1, GETUTCDATE(), 0);
        SET @i = @i + 1;
    END

    DECLARE @TP2B UNIQUEIDENTIFIER;
    SELECT TOP 1 @TP2B = Id FROM Teams WHERE PackageId = @Pkg2Id AND TeamCode = 'TM-KA-002';
    SET @i = 1;
    WHILE @i <= 3
    BEGIN
        INSERT INTO TeamPhotos (Id, TeamId, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, Caption, IsFlaggedForReview, DisplayOrder, VersionNumber, CreatedAt, IsDeleted)
        VALUES (NEWID(), @TP2B, @Pkg2Id, 'photo_2B_' + CAST(@i AS VARCHAR) + '.jpg', '/local/photo_2B_' + CAST(@i AS VARCHAR) + '.jpg',
                210000, 'image/jpeg', 'Promo photo ' + CAST(@i AS VARCHAR), 0, @i, 1, GETUTCDATE(), 0);
        SET @i = @i + 1;
    END
    PRINT 'Inserted 8 photos for Package 2 (2 teams)';
END

IF NOT EXISTS (SELECT 1 FROM TeamPhotos WHERE PackageId = @Pkg3Id)
BEGIN
    DECLARE @TP3A UNIQUEIDENTIFIER;
    SELECT TOP 1 @TP3A = Id FROM Teams WHERE PackageId = @Pkg3Id AND TeamCode = 'TM-RJ-001';
    SET @i = 1;
    WHILE @i <= 2
    BEGIN
        INSERT INTO TeamPhotos (Id, TeamId, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, Caption, IsFlaggedForReview, DisplayOrder, VersionNumber, CreatedAt, IsDeleted)
        VALUES (NEWID(), @TP3A, @Pkg3Id, 'photo_3A_' + CAST(@i AS VARCHAR) + '.jpg', '/local/photo_3A_' + CAST(@i AS VARCHAR) + '.jpg',
                200000, 'image/jpeg', 'Rural event ' + CAST(@i AS VARCHAR), 0, @i, 1, GETUTCDATE(), 0);
        SET @i = @i + 1;
    END
    PRINT 'Inserted 2 photos for Package 3 (1 team - suspiciously few)';
END


-- =============================================
-- 7. ConfidenceScores (one per package)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM ConfidenceScores WHERE PackageId = @Pkg1Id)
BEGIN
    INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, IsDeleted)
    VALUES (NEWID(), @Pkg1Id, 92.0, 88.0, 85.0, 90.0, 95.0, 89.5, 0, GETUTCDATE(), 0);
    PRINT 'Inserted ConfidenceScore for Package 1: 89.5% (High)';
END

IF NOT EXISTS (SELECT 1 FROM ConfidenceScores WHERE PackageId = @Pkg2Id)
BEGIN
    INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, IsDeleted)
    VALUES (NEWID(), @Pkg2Id, 75.0, 68.0, 70.0, 65.0, 72.0, 70.2, 1, GETUTCDATE(), 0);
    PRINT 'Inserted ConfidenceScore for Package 2: 70.2% (Medium)';
END

IF NOT EXISTS (SELECT 1 FROM ConfidenceScores WHERE PackageId = @Pkg3Id)
BEGIN
    INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, IsDeleted)
    VALUES (NEWID(), @Pkg3Id, 45.0, 38.0, 40.0, 30.0, 25.0, 38.5, 1, GETUTCDATE(), 0);
    PRINT 'Inserted ConfidenceScore for Package 3: 38.5% (Low)';
END

-- =============================================
-- 8. Recommendations (Approve / Review / Reject)
-- Type: 1=Approve, 2=Review, 3=Reject
-- =============================================
IF NOT EXISTS (SELECT 1 FROM Recommendations WHERE PackageId = @Pkg1Id)
BEGIN
    INSERT INTO Recommendations (Id, PackageId, Type, Evidence, ValidationIssuesJson, ConfidenceScore, CreatedAt, IsDeleted)
    VALUES (NEWID(), @Pkg1Id, 1,
            'All documents verified. PO amount matches invoice totals. Vendor details consistent across documents. Activity photos confirm event execution at all 3 dealerships.',
            NULL, 89.5, GETUTCDATE(), 0);
    PRINT 'Inserted Recommendation for Package 1: APPROVE';
END

IF NOT EXISTS (SELECT 1 FROM Recommendations WHERE PackageId = @Pkg2Id)
BEGIN
    INSERT INTO Recommendations (Id, PackageId, Type, Evidence, ValidationIssuesJson, ConfidenceScore, CreatedAt, IsDeleted)
    VALUES (NEWID(), @Pkg2Id, 2,
            'PO verified but invoice amounts show minor discrepancy (2.3% variance). Date validation flagged: invoice date precedes campaign end date. Recommend manual review of invoice line items.',
            '[{"severity":"Warning","description":"Invoice amount variance of 2.3% exceeds 1% threshold"},{"severity":"Warning","description":"Invoice INV-2026-2001 dated before campaign end date"},{"severity":"Info","description":"Photo count below average for 2-team campaign"}]',
            70.2, GETUTCDATE(), 0);
    PRINT 'Inserted Recommendation for Package 2: REVIEW';
END

IF NOT EXISTS (SELECT 1 FROM Recommendations WHERE PackageId = @Pkg3Id)
BEGIN
    INSERT INTO Recommendations (Id, PackageId, Type, Evidence, ValidationIssuesJson, ConfidenceScore, CreatedAt, IsDeleted)
    VALUES (NEWID(), @Pkg3Id, 3,
            'Multiple critical issues found. Invoice amount (413,000) significantly exceeds PO amount (420,000 total but only 1 team). SAP verification failed - PO not found in system. Only 2 photos for 10 working days. Vendor GST mismatch detected.',
            '[{"severity":"Fail","description":"SAP verification failed: PO-2026-00610 not found in SAP system"},{"severity":"Fail","description":"Invoice amount 413,000 is 98.3% of PO total for single team - suspicious"},{"severity":"Fail","description":"Vendor GST number mismatch between PO and invoice"},{"severity":"Fail","description":"Only 2 photos for 10 working days (expected minimum 10)"},{"severity":"Warning","description":"Campaign duration only 10 days but invoice amount is 413,000"}]',
            38.5, GETUTCDATE(), 0);
    PRINT 'Inserted Recommendation for Package 3: REJECT';
END

-- =============================================
-- 9. ValidationResults (one per package, linked to PO document)
-- DocumentType: 1=PO, 2=Invoice, 3=CostSummary, 4=Activity, 5=Photo
-- =============================================
IF NOT EXISTS (SELECT 1 FROM ValidationResults WHERE DocumentId IN (SELECT Id FROM POs WHERE PackageId = @Pkg1Id))
BEGIN
    DECLARE @VR1POId UNIQUEIDENTIFIER;
    SELECT TOP 1 @VR1POId = Id FROM POs WHERE PackageId = @Pkg1Id;

    INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, ValidationDetailsJson, CreatedAt, IsDeleted)
    VALUES (NEWID(), 1, @VR1POId, 1, 1, 1, 1, 1, 1, 1,
            '{"checks":[{"name":"SAP Verification","passed":true,"details":"PO found in SAP"},{"name":"Amount Consistency","passed":true,"details":"Amounts match within tolerance"},{"name":"Line Item Matching","passed":true,"details":"All line items verified"},{"name":"Completeness","passed":true,"details":"All required fields present"},{"name":"Date Validation","passed":true,"details":"Dates are consistent"},{"name":"Vendor Matching","passed":true,"details":"Vendor details match"}]}',
            GETUTCDATE(), 0);
    PRINT 'Inserted ValidationResult for Package 1: ALL PASSED';
END

IF NOT EXISTS (SELECT 1 FROM ValidationResults WHERE DocumentId IN (SELECT Id FROM POs WHERE PackageId = @Pkg2Id))
BEGIN
    DECLARE @VR2POId UNIQUEIDENTIFIER;
    SELECT TOP 1 @VR2POId = Id FROM POs WHERE PackageId = @Pkg2Id;

    INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, ValidationDetailsJson, CreatedAt, IsDeleted)
    VALUES (NEWID(), 1, @VR2POId, 1, 0, 1, 1, 0, 1, 0,
            '{"checks":[{"name":"SAP Verification","passed":true,"details":"PO found in SAP"},{"name":"Amount Consistency","passed":false,"details":"Invoice total 141,600 vs PO amount 175,000 - variance 19.1%"},{"name":"Line Item Matching","passed":true,"details":"Line items match"},{"name":"Completeness","passed":true,"details":"All fields present"},{"name":"Date Validation","passed":false,"details":"Invoice date 2026-03-12 is before campaign end date 2026-03-15"},{"name":"Vendor Matching","passed":true,"details":"Vendor details match"}]}',
            GETUTCDATE(), 0);
    PRINT 'Inserted ValidationResult for Package 2: 2 FAILED (Amount, Date)';
END

IF NOT EXISTS (SELECT 1 FROM ValidationResults WHERE DocumentId IN (SELECT Id FROM POs WHERE PackageId = @Pkg3Id))
BEGIN
    DECLARE @VR3POId UNIQUEIDENTIFIER;
    SELECT TOP 1 @VR3POId = Id FROM POs WHERE PackageId = @Pkg3Id;

    INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, ValidationDetailsJson, CreatedAt, IsDeleted)
    VALUES (NEWID(), 1, @VR3POId, 0, 0, 0, 0, 1, 0, 0,
            '{"checks":[{"name":"SAP Verification","passed":false,"details":"PO-2026-00610 not found in SAP system"},{"name":"Amount Consistency","passed":false,"details":"Invoice 413,000 is 98.3% of PO total for single team"},{"name":"Line Item Matching","passed":false,"details":"Cannot verify - SAP PO not found"},{"name":"Completeness","passed":false,"details":"Missing cost summary document, only 2 photos"},{"name":"Date Validation","passed":true,"details":"Dates are within range"},{"name":"Vendor Matching","passed":false,"details":"GST number mismatch: PO has 08AABCP5678B1Z3 vs Invoice 27AABCP1234A1Z5"}]}',
            GETUTCDATE(), 0);
    PRINT 'Inserted ValidationResult for Package 3: 5 FAILED (SAP, Amount, LineItem, Completeness, Vendor)';
END

-- =============================================
-- 10. Summary
-- =============================================
PRINT '';
PRINT '=== SEED DATA COMPLETE ===';
PRINT 'Package 1 (FAP-28C9823C): PendingASM, 89.5% confidence, APPROVE, 3 teams, 19 photos, all checks passed';
PRINT 'Package 2 (FAP-7F3B45DA): PendingASM, 70.2% confidence, REVIEW, 2 teams, 8 photos, 2 checks failed';
PRINT 'Package 3 (FAP-E5A1C8F2): PendingASM, 38.5% confidence, REJECT, 1 team, 2 photos, 5 checks failed';
PRINT '';
PRINT 'Connect Bot Framework Emulator to: http://localhost:5001/api/teams/messages';
PRINT 'Type "pending" to see all 3 submissions';
GO
