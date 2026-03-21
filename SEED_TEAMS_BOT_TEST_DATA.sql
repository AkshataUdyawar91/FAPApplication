-- =============================================
-- Seed: Teams Bot Test Data
-- Purpose: Insert 3 complete FAP submissions in PendingASM state
--          with all related data (Agency, PO, Teams, Invoices,
--          ConfidenceScores, Recommendations, ValidationResults)
--          for testing the Teams Bot notification flow.
-- Date: 2026-03-16
-- Idempotent: Uses IF NOT EXISTS checks
-- Target: localhost\SQLEXPRESS / BajajDocumentProcessing
-- =============================================

SET NOCOUNT ON;
BEGIN TRANSACTION;
BEGIN TRY

-- ============================================================
-- 1. Seed additional Agencies (if not exist)
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM Agencies WHERE Id = 'A2000002-0000-0000-0000-000000000002')
BEGIN
    INSERT INTO Agencies (Id, SupplierCode, SupplierName, CreatedAt, IsDeleted)
    VALUES ('A2000002-0000-0000-0000-000000000002', 'SUP-DL-002', 'Horizon Media Solutions', GETUTCDATE(), 0);
END;

IF NOT EXISTS (SELECT 1 FROM Agencies WHERE Id = 'A3000003-0000-0000-0000-000000000003')
BEGIN
    INSERT INTO Agencies (Id, SupplierCode, SupplierName, CreatedAt, IsDeleted)
    VALUES ('A3000003-0000-0000-0000-000000000003', 'SUP-KA-003', 'Catalyst Brand Promotions', GETUTCDATE(), 0);
END;

-- ============================================================
-- 2. Seed Agency Users for new agencies (if not exist)
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM Users WHERE Id = 'B2000002-1111-1111-1111-000000000002')
BEGIN
    INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, AgencyId, IsActive, CreatedAt, IsDeleted)
    VALUES ('B2000002-1111-1111-1111-000000000002', 'horizon@agency.com',
            '$2a$11$placeholder', 'Rahul Sharma', 1,
            'A2000002-0000-0000-0000-000000000002', 1, GETUTCDATE(), 0);
END;

IF NOT EXISTS (SELECT 1 FROM Users WHERE Id = 'B3000003-1111-1111-1111-000000000003')
BEGIN
    INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, AgencyId, IsActive, CreatedAt, IsDeleted)
    VALUES ('B3000003-1111-1111-1111-000000000003', 'catalyst@agency.com',
            '$2a$11$placeholder', 'Priya Patel', 1,
            'A3000003-0000-0000-0000-000000000003', 1, GETUTCDATE(), 0);
END;

-- ============================================================
-- 3. SUBMISSION 1: High confidence APPROVE — Pinnacle Advertising
--    PO: 4500012345, Amount: ₹2,85,000, Confidence: 92/100
-- ============================================================
DECLARE @PKG1 UNIQUEIDENTIFIER = 'D1000001-AAAA-BBBB-CCCC-000000000001';
DECLARE @PO1  UNIQUEIDENTIFIER = 'E1000001-AAAA-BBBB-CCCC-000000000001';
DECLARE @TM1  UNIQUEIDENTIFIER = 'F1000001-AAAA-BBBB-CCCC-000000000001';
DECLARE @INV1 UNIQUEIDENTIFIER = 'C1000001-AAAA-BBBB-CCCC-000000000001';
DECLARE @CS1  UNIQUEIDENTIFIER = 'CC100001-AAAA-BBBB-CCCC-000000000001';
DECLARE @REC1 UNIQUEIDENTIFIER = 'DD100001-AAAA-BBBB-CCCC-000000000001';
DECLARE @VR1  UNIQUEIDENTIFIER = 'EE100001-AAAA-BBBB-CCCC-000000000001';

DECLARE @AGENCY1 UNIQUEIDENTIFIER = 'A1000001-0000-0000-0000-000000000001';
DECLARE @USER1   UNIQUEIDENTIFIER = '4AED005F-D377-4929-BC22-CAFB35EA6AE2';

IF NOT EXISTS (SELECT 1 FROM DocumentPackages WHERE Id = @PKG1)
BEGIN
    -- DocumentPackage
    INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, VersionNumber, State, CreatedAt, IsDeleted)
    VALUES (@PKG1, @AGENCY1, @USER1, 1, 4, DATEADD(HOUR, -3, GETUTCDATE()), 0);

    -- PO
    INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount,
                     FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence,
                     IsFlaggedForReview, VersionNumber, CreatedAt, IsDeleted)
    VALUES (@PO1, @PKG1, @AGENCY1, '4500012345', '2026-02-15', 'Pinnacle Advertising Pvt Ltd', 285000.00,
            'PO_4500012345.pdf', 'https://storage.blob.core.windows.net/docs/po1.pdf', 245000, 'application/pdf', 0.95,
            0, 1, DATEADD(HOUR, -3, GETUTCDATE()), 0);

    -- Team
    INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays,
                       DealershipName, DealershipAddress, [State], VersionNumber, CreatedAt, IsDeleted)
    VALUES (@TM1, @PKG1, 'Pune Monsoon Drive 2026', 'TM-PUN-001', '2026-01-10', '2026-02-10', 25,
            'Bajaj Auto Showroom Pune', 'Hinjewadi Phase 2, Pune 411057', 'Maharashtra', 1, DATEADD(HOUR, -3, GETUTCDATE()), 0);

    -- CampaignInvoice
    INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName,
                                   GSTNumber, SubTotal, TaxAmount, TotalAmount,
                                   FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence,
                                   IsFlaggedForReview, CreatedAt, IsDeleted)
    VALUES (@INV1, @TM1, @PKG1, 'INV-2026-0451', '2026-02-12', 'Pinnacle Advertising Pvt Ltd',
            '27AABCP1234A1Z5', 241525.42, 43474.58, 285000.00,
            'Invoice_0451.pdf', 'https://storage.blob.core.windows.net/docs/inv1.pdf', 198000, 'application/pdf', 0.93,
            0, DATEADD(HOUR, -3, GETUTCDATE()), 0);

    -- ConfidenceScore
    INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence,
                                   ActivityConfidence, PhotosConfidence, OverallConfidence,
                                   IsFlaggedForReview, CreatedAt, IsDeleted)
    VALUES (@CS1, @PKG1, 95, 93, 90, 88, 85, 92, 0, DATEADD(HOUR, -2, GETUTCDATE()), 0);

    -- Recommendation (Type 1 = Approve)
    INSERT INTO Recommendations (Id, PackageId, Type, Evidence, ValidationIssuesJson, ConfidenceScore, CreatedAt, IsDeleted)
    VALUES (@REC1, @PKG1, 1,
            'All documents verified. PO amount matches invoice total. Vendor details consistent across documents. Activity photos confirm on-ground execution at Pune dealership. Recommend approval.',
            NULL, 92, DATEADD(HOUR, -2, GETUTCDATE()), 0);

    -- ValidationResult (for PO, DocumentType 1 = PO)
    INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed,
                                    LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed,
                                    VendorMatchingPassed, AllValidationsPassed, CreatedAt, IsDeleted)
    VALUES (@VR1, 1, @PO1, 1, 1, 1, 1, 1, 1, 1, DATEADD(HOUR, -2, GETUTCDATE()), 0);

    PRINT 'Submission 1 inserted: FAP-D1000001 (Pinnacle Advertising, ₹2,85,000, Confidence 92)';
END
ELSE
    PRINT 'Submission 1 already exists — skipping';

-- ============================================================
-- 4. SUBMISSION 2: Medium confidence REVIEW — Horizon Media
--    PO: 4500067890, Amount: ₹1,50,000, Confidence: 74/100
-- ============================================================
DECLARE @PKG2 UNIQUEIDENTIFIER = 'D2000002-AAAA-BBBB-CCCC-000000000002';
DECLARE @PO2  UNIQUEIDENTIFIER = 'E2000002-AAAA-BBBB-CCCC-000000000002';
DECLARE @TM2  UNIQUEIDENTIFIER = 'F2000002-AAAA-BBBB-CCCC-000000000002';
DECLARE @INV2 UNIQUEIDENTIFIER = 'C2000002-AAAA-BBBB-CCCC-000000000002';
DECLARE @CS2  UNIQUEIDENTIFIER = 'CC200002-AAAA-BBBB-CCCC-000000000002';
DECLARE @REC2 UNIQUEIDENTIFIER = 'DD200002-AAAA-BBBB-CCCC-000000000002';
DECLARE @VR2  UNIQUEIDENTIFIER = 'EE200002-AAAA-BBBB-CCCC-000000000002';

DECLARE @AGENCY2 UNIQUEIDENTIFIER = 'A2000002-0000-0000-0000-000000000002';
DECLARE @USER2   UNIQUEIDENTIFIER = 'B2000002-1111-1111-1111-000000000002';

IF NOT EXISTS (SELECT 1 FROM DocumentPackages WHERE Id = @PKG2)
BEGIN
    -- DocumentPackage
    INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, VersionNumber, State, CreatedAt, IsDeleted)
    VALUES (@PKG2, @AGENCY2, @USER2, 1, 4, DATEADD(HOUR, -5, GETUTCDATE()), 0);

    -- PO
    INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount,
                     FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence,
                     IsFlaggedForReview, VersionNumber, CreatedAt, IsDeleted)
    VALUES (@PO2, @PKG2, @AGENCY2, '4500067890', '2026-01-20', 'Horizon Media Solutions', 150000.00,
            'PO_4500067890.pdf', 'https://storage.blob.core.windows.net/docs/po2.pdf', 312000, 'application/pdf', 0.78,
            1, 1, DATEADD(HOUR, -5, GETUTCDATE()), 0);

    -- Team
    INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays,
                       DealershipName, DealershipAddress, [State], VersionNumber, CreatedAt, IsDeleted)
    VALUES (@TM2, @PKG2, 'Delhi Winter Campaign 2026', 'TM-DL-002', '2025-12-01', '2026-01-15', 30,
            'Bajaj Probiking Delhi', 'Connaught Place, New Delhi 110001', 'Delhi', 1, DATEADD(HOUR, -5, GETUTCDATE()), 0);

    -- CampaignInvoice
    INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName,
                                   GSTNumber, SubTotal, TaxAmount, TotalAmount,
                                   FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence,
                                   IsFlaggedForReview, CreatedAt, IsDeleted)
    VALUES (@INV2, @TM2, @PKG2, 'INV-2026-0782', '2026-01-18', 'Horizon Media Solutions',
            '07AABCH5678B2Z3', 127118.64, 22881.36, 150000.00,
            'Invoice_0782.pdf', 'https://storage.blob.core.windows.net/docs/inv2.pdf', 175000, 'application/pdf', 0.72,
            1, DATEADD(HOUR, -5, GETUTCDATE()), 0);

    -- ConfidenceScore
    INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence,
                                   ActivityConfidence, PhotosConfidence, OverallConfidence,
                                   IsFlaggedForReview, CreatedAt, IsDeleted)
    VALUES (@CS2, @PKG2, 78, 72, 75, 70, 68, 74, 1, DATEADD(HOUR, -4, GETUTCDATE()), 0);

    -- Recommendation (Type 2 = Review)
    INSERT INTO Recommendations (Id, PackageId, Type, Evidence, ValidationIssuesJson, ConfidenceScore, CreatedAt, IsDeleted)
    VALUES (@REC2, @PKG2, 2,
            'Invoice amount matches PO but vendor GST number could not be verified against SAP records. Activity photos show partial coverage — only 18 of 30 working days documented. Cost summary has minor discrepancies in line item totals. Manual review recommended.',
            '["GST number mismatch with SAP records","Activity coverage incomplete (18/30 days)","Cost summary line item total off by ₹2,340"]',
            74, DATEADD(HOUR, -4, GETUTCDATE()), 0);

    -- ValidationResult (some checks failed)
    INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed,
                                    LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed,
                                    VendorMatchingPassed, AllValidationsPassed,
                                    FailureReason, CreatedAt, IsDeleted)
    VALUES (@VR2, 1, @PO2, 0, 1, 1, 1, 1, 0, 0,
            'SAP verification failed: GST number not found in vendor master. Vendor name partial match only.',
            DATEADD(HOUR, -4, GETUTCDATE()), 0);

    PRINT 'Submission 2 inserted: FAP-D2000002 (Horizon Media, ₹1,50,000, Confidence 74)';
END
ELSE
    PRINT 'Submission 2 already exists — skipping';

-- ============================================================
-- 5. SUBMISSION 3: Low confidence REJECT — Catalyst Brand
--    PO: 4500099001, Amount: ₹4,20,000, Confidence: 55/100
-- ============================================================
DECLARE @PKG3 UNIQUEIDENTIFIER = 'D3000003-AAAA-BBBB-CCCC-000000000003';
DECLARE @PO3  UNIQUEIDENTIFIER = 'E3000003-AAAA-BBBB-CCCC-000000000003';
DECLARE @TM3  UNIQUEIDENTIFIER = 'F3000003-AAAA-BBBB-CCCC-000000000003';
DECLARE @INV3A UNIQUEIDENTIFIER = 'C3000003-AAAA-BBBB-CCCC-00000000003A';
DECLARE @INV3B UNIQUEIDENTIFIER = 'C3000003-AAAA-BBBB-CCCC-00000000003B';
DECLARE @CS3  UNIQUEIDENTIFIER = 'CC300003-AAAA-BBBB-CCCC-000000000003';
DECLARE @REC3 UNIQUEIDENTIFIER = 'DD300003-AAAA-BBBB-CCCC-000000000003';
DECLARE @VR3  UNIQUEIDENTIFIER = 'EE300003-AAAA-BBBB-CCCC-000000000003';

DECLARE @AGENCY3 UNIQUEIDENTIFIER = 'A3000003-0000-0000-0000-000000000003';
DECLARE @USER3   UNIQUEIDENTIFIER = 'B3000003-1111-1111-1111-000000000003';

IF NOT EXISTS (SELECT 1 FROM DocumentPackages WHERE Id = @PKG3)
BEGIN
    -- DocumentPackage
    INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, VersionNumber, State, CreatedAt, IsDeleted)
    VALUES (@PKG3, @AGENCY3, @USER3, 1, 4, DATEADD(HOUR, -1, GETUTCDATE()), 0);

    -- PO
    INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount,
                     FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence,
                     IsFlaggedForReview, VersionNumber, CreatedAt, IsDeleted)
    VALUES (@PO3, @PKG3, @AGENCY3, '4500099001', '2026-03-01', 'Catalyst Brand Promotions', 420000.00,
            'PO_4500099001.pdf', 'https://storage.blob.core.windows.net/docs/po3.pdf', 410000, 'application/pdf', 0.58,
            1, 1, DATEADD(HOUR, -1, GETUTCDATE()), 0);

    -- Team
    INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays,
                       DealershipName, DealershipAddress, [State], VersionNumber, CreatedAt, IsDeleted)
    VALUES (@TM3, @PKG3, 'Bangalore Tech Expo 2026', 'TM-KA-003', '2026-02-15', '2026-03-10', 20,
            'Bajaj Auto Hub Bangalore', 'Whitefield Main Road, Bangalore 560066', 'Karnataka', 1, DATEADD(HOUR, -1, GETUTCDATE()), 0);

    -- CampaignInvoice 1 (of 2)
    INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName,
                                   GSTNumber, SubTotal, TaxAmount, TotalAmount,
                                   FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence,
                                   IsFlaggedForReview, CreatedAt, IsDeleted)
    VALUES (@INV3A, @TM3, @PKG3, 'INV-2026-1100', '2026-03-05', 'Catalyst Brand Promotions',
            '29AABCC9012C3Z1', 169491.53, 30508.47, 200000.00,
            'Invoice_1100.pdf', 'https://storage.blob.core.windows.net/docs/inv3a.pdf', 220000, 'application/pdf', 0.55,
            1, DATEADD(HOUR, -1, GETUTCDATE()), 0);

    -- CampaignInvoice 2 (of 2)
    INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName,
                                   GSTNumber, SubTotal, TaxAmount, TotalAmount,
                                   FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence,
                                   IsFlaggedForReview, CreatedAt, IsDeleted)
    VALUES (@INV3B, @TM3, @PKG3, 'INV-2026-1101', '2026-03-08', 'Catalyst Brand Promotions',
            '29AABCC9012C3Z1', 186440.68, 33559.32, 220000.00,
            'Invoice_1101.pdf', 'https://storage.blob.core.windows.net/docs/inv3b.pdf', 195000, 'application/pdf', 0.50,
            1, DATEADD(HOUR, -1, GETUTCDATE()), 0);

    -- ConfidenceScore
    INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence,
                                   ActivityConfidence, PhotosConfidence, OverallConfidence,
                                   IsFlaggedForReview, CreatedAt, IsDeleted)
    VALUES (@CS3, @PKG3, 58, 52, 55, 50, 45, 55, 1, DATEADD(MINUTE, -30, GETUTCDATE()), 0);

    -- Recommendation (Type 3 = Reject)
    INSERT INTO Recommendations (Id, PackageId, Type, Evidence, ValidationIssuesJson, ConfidenceScore, CreatedAt, IsDeleted)
    VALUES (@REC3, @PKG3, 3,
            'Multiple critical issues found. PO amount (₹4,20,000) does not match combined invoice total (₹4,20,000 but line items sum to ₹3,95,000). Vendor GST number invalid. Activity photos appear to be stock images — no EXIF location data. Cost summary missing 3 required line items. Rejection recommended.',
            '["PO line items total ₹3,95,000 vs header amount ₹4,20,000","Vendor GST number format invalid","Activity photos lack EXIF geolocation data","Cost summary missing venue rental, logistics, and staffing line items","Invoice dates precede PO date"]',
            55, DATEADD(MINUTE, -30, GETUTCDATE()), 0);

    -- ValidationResult (multiple checks failed)
    INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed,
                                    LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed,
                                    VendorMatchingPassed, AllValidationsPassed,
                                    FailureReason, CreatedAt, IsDeleted)
    VALUES (@VR3, 1, @PO3, 0, 0, 0, 0, 0, 0, 0,
            'SAP verification failed. Amount mismatch between PO header and line items. Invoice dates precede PO date. Cost summary incomplete. Vendor GST invalid.',
            DATEADD(MINUTE, -30, GETUTCDATE()), 0);

    PRINT 'Submission 3 inserted: FAP-D3000003 (Catalyst Brand, ₹4,20,000, Confidence 55)';
END
ELSE
    PRINT 'Submission 3 already exists — skipping';

COMMIT TRANSACTION;
PRINT '';
PRINT '=== Seed complete. 3 submissions in PendingASM state ready for Teams Bot testing. ===';
PRINT 'Type "pending" in Bot Framework Emulator to see them.';

END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
