-- Seed 4 new PendingASM submissions with full data
-- ASM User: 3418DB05-AAFD-40C0-AE92-EDD11FF49B67
-- State=4 means PendingASM

DECLARE @AsmUserId UNIQUEIDENTIFIER = '3418DB05-AAFD-40C0-AE92-EDD11FF49B67';
DECLARE @Now DATETIME2 = GETUTCDATE();

-- ============================================================
-- SUBMISSION 1: Pinnacle Advertising - Bihar EV Campaign
-- ============================================================
DECLARE @Pkg1 UNIQUEIDENTIFIER = 'AA000001-1111-4000-A000-000000000001';
DECLARE @PO1 UNIQUEIDENTIFIER  = 'BB000001-1111-4000-A000-000000000001';
DECLARE @Inv1 UNIQUEIDENTIFIER = 'CC000001-1111-4000-A000-000000000001';
DECLARE @Tm1 UNIQUEIDENTIFIER  = 'DD000001-1111-4000-A000-000000000001';
DECLARE @CS1 UNIQUEIDENTIFIER  = 'EE000001-1111-4000-A000-000000000001';
DECLARE @AS1 UNIQUEIDENTIFIER  = 'FF000001-1111-4000-A000-000000000001';
DECLARE @VR1po UNIQUEIDENTIFIER = '11000001-1111-4000-A000-000000000001';
DECLARE @VR1cs UNIQUEIDENTIFIER = '11000001-1111-4000-A000-000000000002';
DECLARE @VR1as UNIQUEIDENTIFIER = '11000001-1111-4000-A000-000000000003';
DECLARE @CF1 UNIQUEIDENTIFIER  = '22000001-1111-4000-A000-000000000001';

IF NOT EXISTS (SELECT 1 FROM DocumentPackages WHERE Id = @Pkg1)
BEGIN
    INSERT INTO DocumentPackages (Id, AgencyId, State, ActivityState, SubmissionNumber, AssignedCircleHeadUserId, CurrentStep, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Pkg1, 'A1000001-0000-0000-0000-000000000001', 4, N'Bihar', N'FAP-2025-0101', @AsmUserId, 0, 1, DATEADD(HOUR,-3,@Now), @Now, 0);

    INSERT INTO POs (Id, PackageId, AgencyId, PONumber, TotalAmount, RemainingBalance, FileName, BlobUrl, FileSizeBytes, ContentType, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@PO1, @Pkg1, 'A1000001-0000-0000-0000-000000000001', N'PO-BH-2025-4401', 800000.00, 356279.00, N'PO-BH-4401.pdf', N'https://blob/po1.pdf', 245000, N'application/pdf', 1, DATEADD(HOUR,-3,@Now), @Now, 0);

    INSERT INTO Invoices (Id, PackageId, POId, VersionNumber, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, ExtractedDataJson, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Inv1, @Pkg1, @PO1, 1, N'SE-01/2025-26', '2025-04-22', N'M/S SWIFT EVENTS', N'10DEFPK2659R2Z3', 376035.00, 67686.00, 443721.00, N'INV-SE-01-2025-26.pdf', N'https://blob/inv1.pdf', 180000, N'application/pdf', 95.0, 0,
    N'{"InvoiceNumber":"SE-01/2025-26","InvoiceDate":"2025-04-22","VendorName":"M/S SWIFT EVENTS","GSTNumber":"10DEFPK2659R2Z3","GSTPercentage":18,"HSNSACCode":"998596","PONumber":"PO-BH-2025-4401","TotalAmount":443721.00}',
    DATEADD(HOUR,-3,@Now), @Now, 0);

    INSERT INTO Teams (Id, PackageId, CampaignName, State, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Tm1, @Pkg1, N'Bihar EV Trials Campaign', N'Bihar', 1, DATEADD(HOUR,-3,@Now), @Now, 0);

    INSERT INTO CostSummaries (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@CS1, @Pkg1, N'CostSummary-BH-01.pdf', N'https://blob/cs1.pdf', 120000, N'application/pdf', 1, DATEADD(HOUR,-3,@Now), @Now, 0);

    INSERT INTO ActivitySummaries (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@AS1, @Pkg1, N'Activity-BH-01.pdf', N'https://blob/as1.pdf', 95000, N'application/pdf', 1, DATEADD(HOUR,-3,@Now), @Now, 0);

    INSERT INTO ValidationResults (Id, DocumentId, DocumentType, AllValidationsPassed, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@VR1po, @PO1, 0, 1, 1, 1, 1, 1, 1, 1, DATEADD(HOUR,-2,@Now), @Now, 0);
    INSERT INTO ValidationResults (Id, DocumentId, DocumentType, AllValidationsPassed, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@VR1cs, @CS1, 3, 1, 1, 1, 1, 1, 1, 1, DATEADD(HOUR,-2,@Now), @Now, 0);
    INSERT INTO ValidationResults (Id, DocumentId, DocumentType, AllValidationsPassed, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@VR1as, @AS1, 4, 1, 1, 1, 1, 1, 1, 1, DATEADD(HOUR,-2,@Now), @Now, 0);

    INSERT INTO ConfidenceScores (Id, PackageId, OverallConfidence, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@CF1, @Pkg1, 81.0, 90.0, 78.0, 85.0, 72.0, 80.0, 0, DATEADD(HOUR,-2,@Now), @Now, 0);

    PRINT 'Submission 1 inserted: Bihar EV Campaign (FAP-2025-0101)';
END
ELSE PRINT 'Submission 1 already exists - skipped';

-- ============================================================
-- SUBMISSION 2: Horizon Media - Maharashtra Auto Expo
-- ============================================================
DECLARE @Pkg2 UNIQUEIDENTIFIER = 'AA000002-2222-4000-A000-000000000002';
DECLARE @PO2 UNIQUEIDENTIFIER  = 'BB000002-2222-4000-A000-000000000002';
DECLARE @Inv2 UNIQUEIDENTIFIER = 'CC000002-2222-4000-A000-000000000002';
DECLARE @Tm2 UNIQUEIDENTIFIER  = 'DD000002-2222-4000-A000-000000000002';
DECLARE @CS2 UNIQUEIDENTIFIER  = 'EE000002-2222-4000-A000-000000000002';
DECLARE @AS2 UNIQUEIDENTIFIER  = 'FF000002-2222-4000-A000-000000000002';
DECLARE @VR2po UNIQUEIDENTIFIER = '11000002-2222-4000-A000-000000000001';
DECLARE @VR2cs UNIQUEIDENTIFIER = '11000002-2222-4000-A000-000000000002';
DECLARE @VR2as UNIQUEIDENTIFIER = '11000002-2222-4000-A000-000000000003';
DECLARE @CF2 UNIQUEIDENTIFIER  = '22000002-2222-4000-A000-000000000002';

IF NOT EXISTS (SELECT 1 FROM DocumentPackages WHERE Id = @Pkg2)
BEGIN
    INSERT INTO DocumentPackages (Id, AgencyId, State, ActivityState, SubmissionNumber, AssignedCircleHeadUserId, CurrentStep, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Pkg2, 'A2000002-0000-0000-0000-000000000002', 4, N'Maharashtra', N'FAP-2025-0102', @AsmUserId, 0, 1, DATEADD(HOUR,-2,@Now), @Now, 0);

    INSERT INTO POs (Id, PackageId, AgencyId, PONumber, TotalAmount, RemainingBalance, FileName, BlobUrl, FileSizeBytes, ContentType, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@PO2, @Pkg2, 'A2000002-0000-0000-0000-000000000002', N'PO-MH-2025-7802', 1200000.00, 750000.00, N'PO-MH-7802.pdf', N'https://blob/po2.pdf', 310000, N'application/pdf', 1, DATEADD(HOUR,-2,@Now), @Now, 0);

    INSERT INTO Invoices (Id, PackageId, POId, VersionNumber, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, ExtractedDataJson, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Inv2, @Pkg2, @PO2, 1, N'HM-INV-0045', '2025-05-10', N'Horizon Media Solutions', N'27AABCH1234M1ZP', 380000.00, 68400.00, 448400.00, N'INV-HM-0045.pdf', N'https://blob/inv2.pdf', 195000, N'application/pdf', 92.0, 0,
    N'{"InvoiceNumber":"HM-INV-0045","InvoiceDate":"2025-05-10","VendorName":"Horizon Media Solutions","GSTNumber":"27AABCH1234M1ZP","GSTPercentage":18,"HSNSACCode":"998361","VendorCode":"VND-HM-027","PONumber":"PO-MH-2025-7802","TotalAmount":448400.00}',
    DATEADD(HOUR,-2,@Now), @Now, 0);

    INSERT INTO Teams (Id, PackageId, CampaignName, State, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Tm2, @Pkg2, N'Maharashtra Auto Expo 2025', N'Maharashtra', 1, DATEADD(HOUR,-2,@Now), @Now, 0);

    INSERT INTO CostSummaries (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@CS2, @Pkg2, N'CostSummary-MH-02.pdf', N'https://blob/cs2.pdf', 135000, N'application/pdf', 1, DATEADD(HOUR,-2,@Now), @Now, 0);

    INSERT INTO ActivitySummaries (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@AS2, @Pkg2, N'Activity-MH-02.pdf', N'https://blob/as2.pdf', 88000, N'application/pdf', 1, DATEADD(HOUR,-2,@Now), @Now, 0);

    INSERT INTO ValidationResults (Id, DocumentId, DocumentType, AllValidationsPassed, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@VR2po, @PO2, 0, 1, 1, 1, 1, 1, 1, 1, DATEADD(HOUR,-1,@Now), @Now, 0);
    INSERT INTO ValidationResults (Id, DocumentId, DocumentType, AllValidationsPassed, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@VR2cs, @CS2, 3, 1, 1, 1, 1, 1, 1, 1, DATEADD(HOUR,-1,@Now), @Now, 0);
    INSERT INTO ValidationResults (Id, DocumentId, DocumentType, AllValidationsPassed, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@VR2as, @AS2, 4, 1, 1, 1, 1, 1, 1, 1, DATEADD(HOUR,-1,@Now), @Now, 0);

    INSERT INTO ConfidenceScores (Id, PackageId, OverallConfidence, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@CF2, @Pkg2, 92.0, 95.0, 90.0, 88.0, 93.0, 94.0, 0, DATEADD(HOUR,-1,@Now), @Now, 0);

    PRINT 'Submission 2 inserted: Maharashtra Auto Expo (FAP-2025-0102)';
END
ELSE PRINT 'Submission 2 already exists - skipped';

-- ============================================================
-- SUBMISSION 3: Catalyst Brand - Karnataka Dealer Meet
-- Invoice missing GSTPercentage and VendorCode (will show FAIL)
-- Cost Summary: date validation fails. Activity: vendor matching fails.
-- ============================================================
DECLARE @Pkg3 UNIQUEIDENTIFIER = 'AA000003-3333-4000-A000-000000000003';
DECLARE @PO3 UNIQUEIDENTIFIER  = 'BB000003-3333-4000-A000-000000000003';
DECLARE @Inv3 UNIQUEIDENTIFIER = 'CC000003-3333-4000-A000-000000000003';
DECLARE @Tm3 UNIQUEIDENTIFIER  = 'DD000003-3333-4000-A000-000000000003';
DECLARE @CS3 UNIQUEIDENTIFIER  = 'EE000003-3333-4000-A000-000000000003';
DECLARE @AS3 UNIQUEIDENTIFIER  = 'FF000003-3333-4000-A000-000000000003';
DECLARE @VR3po UNIQUEIDENTIFIER = '11000003-3333-4000-A000-000000000001';
DECLARE @VR3cs UNIQUEIDENTIFIER = '11000003-3333-4000-A000-000000000002';
DECLARE @VR3as UNIQUEIDENTIFIER = '11000003-3333-4000-A000-000000000003';
DECLARE @CF3 UNIQUEIDENTIFIER  = '22000003-3333-4000-A000-000000000003';

IF NOT EXISTS (SELECT 1 FROM DocumentPackages WHERE Id = @Pkg3)
BEGIN
    INSERT INTO DocumentPackages (Id, AgencyId, State, ActivityState, SubmissionNumber, AssignedCircleHeadUserId, CurrentStep, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Pkg3, 'A3000003-0000-0000-0000-000000000003', 4, N'Karnataka', N'FAP-2025-0103', @AsmUserId, 0, 1, DATEADD(HOUR,-1,@Now), @Now, 0);

    INSERT INTO POs (Id, PackageId, AgencyId, PONumber, TotalAmount, RemainingBalance, FileName, BlobUrl, FileSizeBytes, ContentType, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@PO3, @Pkg3, 'A3000003-0000-0000-0000-000000000003', N'PO-KA-2025-1190', 550000.00, 550000.00, N'PO-KA-1190.pdf', N'https://blob/po3.pdf', 200000, N'application/pdf', 1, DATEADD(HOUR,-1,@Now), @Now, 0);

    INSERT INTO Invoices (Id, PackageId, POId, VersionNumber, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, ExtractedDataJson, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Inv3, @Pkg3, @PO3, 1, N'CBP/2025/KA-088', '2025-06-01', N'Catalyst Brand Promotions', N'29AADCC5678N1Z9', 320000.00, 57600.00, 377600.00, N'INV-CBP-KA-088.pdf', N'https://blob/inv3.pdf', 170000, N'application/pdf', 78.0, 1,
    N'{"InvoiceNumber":"CBP/2025/KA-088","InvoiceDate":"2025-06-01","VendorName":"Catalyst Brand Promotions","GSTNumber":"29AADCC5678N1Z9","HSNSACCode":"998596","PONumber":"PO-KA-2025-1190","TotalAmount":377600.00}',
    DATEADD(HOUR,-1,@Now), @Now, 0);

    INSERT INTO Teams (Id, PackageId, CampaignName, State, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Tm3, @Pkg3, N'Karnataka Dealer Meet Q2', N'Karnataka', 1, DATEADD(HOUR,-1,@Now), @Now, 0);

    INSERT INTO CostSummaries (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@CS3, @Pkg3, N'CostSummary-KA-03.pdf', N'https://blob/cs3.pdf', 110000, N'application/pdf', 1, DATEADD(HOUR,-1,@Now), @Now, 0);

    INSERT INTO ActivitySummaries (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@AS3, @Pkg3, N'Activity-KA-03.pdf', N'https://blob/as3.pdf', 92000, N'application/pdf', 1, DATEADD(HOUR,-1,@Now), @Now, 0);

    -- PO: all pass. Cost Summary: date validation fails. Activity: vendor matching fails.
    INSERT INTO ValidationResults (Id, DocumentId, DocumentType, AllValidationsPassed, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@VR3po, @PO3, 0, 1, 1, 1, 1, 1, 1, 1, DATEADD(MINUTE,-30,@Now), @Now, 0);
    INSERT INTO ValidationResults (Id, DocumentId, DocumentType, AllValidationsPassed, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@VR3cs, @CS3, 3, 0, 1, 1, 1, 1, 0, 1, DATEADD(MINUTE,-30,@Now), @Now, 0);
    INSERT INTO ValidationResults (Id, DocumentId, DocumentType, AllValidationsPassed, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@VR3as, @AS3, 4, 0, 1, 1, 1, 1, 1, 0, DATEADD(MINUTE,-30,@Now), @Now, 0);

    INSERT INTO ConfidenceScores (Id, PackageId, OverallConfidence, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@CF3, @Pkg3, 68.0, 88.0, 65.0, 60.0, 55.0, 72.0, 1, DATEADD(MINUTE,-30,@Now), @Now, 0);

    PRINT 'Submission 3 inserted: Karnataka Dealer Meet (FAP-2025-0103)';
END
ELSE PRINT 'Submission 3 already exists - skipped';

-- ============================================================
-- SUBMISSION 4: Pinnacle Advertising - Gujarat Road Show
-- Invoice amount (472000) exceeds PO balance (420000) -> Amount vs PO Balance FAIL
-- ============================================================
DECLARE @Pkg4 UNIQUEIDENTIFIER = 'AA000004-4444-4000-A000-000000000004';
DECLARE @PO4 UNIQUEIDENTIFIER  = 'BB000004-4444-4000-A000-000000000004';
DECLARE @Inv4 UNIQUEIDENTIFIER = 'CC000004-4444-4000-A000-000000000004';
DECLARE @Tm4 UNIQUEIDENTIFIER  = 'DD000004-4444-4000-A000-000000000004';
DECLARE @CS4 UNIQUEIDENTIFIER  = 'EE000004-4444-4000-A000-000000000004';
DECLARE @AS4 UNIQUEIDENTIFIER  = 'FF000004-4444-4000-A000-000000000004';
DECLARE @VR4po UNIQUEIDENTIFIER = '11000004-4444-4000-A000-000000000001';
DECLARE @VR4cs UNIQUEIDENTIFIER = '11000004-4444-4000-A000-000000000002';
DECLARE @VR4as UNIQUEIDENTIFIER = '11000004-4444-4000-A000-000000000003';
DECLARE @CF4 UNIQUEIDENTIFIER  = '22000004-4444-4000-A000-000000000004';

IF NOT EXISTS (SELECT 1 FROM DocumentPackages WHERE Id = @Pkg4)
BEGIN
    INSERT INTO DocumentPackages (Id, AgencyId, State, ActivityState, SubmissionNumber, AssignedCircleHeadUserId, CurrentStep, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Pkg4, 'A1000001-0000-0000-0000-000000000001', 4, N'Gujarat', N'FAP-2025-0104', @AsmUserId, 0, 1, DATEADD(MINUTE,-45,@Now), @Now, 0);

    INSERT INTO POs (Id, PackageId, AgencyId, PONumber, TotalAmount, RemainingBalance, FileName, BlobUrl, FileSizeBytes, ContentType, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@PO4, @Pkg4, 'A1000001-0000-0000-0000-000000000001', N'PO-GJ-2025-3350', 650000.00, 420000.00, N'PO-GJ-3350.pdf', N'https://blob/po4.pdf', 230000, N'application/pdf', 1, DATEADD(MINUTE,-45,@Now), @Now, 0);

    INSERT INTO Invoices (Id, PackageId, POId, VersionNumber, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, ExtractedDataJson, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Inv4, @Pkg4, @PO4, 1, N'PA/GJ/2025-112', '2025-06-15', N'Pinnacle Advertising Pvt Ltd', N'24AABCP9876K1ZQ', 400000.00, 72000.00, 472000.00, N'INV-PA-GJ-112.pdf', N'https://blob/inv4.pdf', 210000, N'application/pdf', 88.0, 0,
    N'{"InvoiceNumber":"PA/GJ/2025-112","InvoiceDate":"2025-06-15","VendorName":"Pinnacle Advertising Pvt Ltd","GSTNumber":"24AABCP9876K1ZQ","GSTPercentage":18,"HSNSACCode":"998361","VendorCode":"VND-PA-024","PONumber":"PO-GJ-2025-3350","TotalAmount":472000.00}',
    DATEADD(MINUTE,-45,@Now), @Now, 0);

    INSERT INTO Teams (Id, PackageId, CampaignName, State, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Tm4, @Pkg4, N'Gujarat Road Show June 2025', N'Gujarat', 1, DATEADD(MINUTE,-45,@Now), @Now, 0);

    INSERT INTO CostSummaries (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@CS4, @Pkg4, N'CostSummary-GJ-04.pdf', N'https://blob/cs4.pdf', 125000, N'application/pdf', 1, DATEADD(MINUTE,-45,@Now), @Now, 0);

    INSERT INTO ActivitySummaries (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@AS4, @Pkg4, N'Activity-GJ-04.pdf', N'https://blob/as4.pdf', 98000, N'application/pdf', 1, DATEADD(MINUTE,-45,@Now), @Now, 0);

    INSERT INTO ValidationResults (Id, DocumentId, DocumentType, AllValidationsPassed, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@VR4po, @PO4, 0, 1, 1, 1, 1, 1, 1, 1, DATEADD(MINUTE,-20,@Now), @Now, 0);
    INSERT INTO ValidationResults (Id, DocumentId, DocumentType, AllValidationsPassed, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@VR4cs, @CS4, 3, 1, 1, 1, 1, 1, 1, 1, DATEADD(MINUTE,-20,@Now), @Now, 0);
    INSERT INTO ValidationResults (Id, DocumentId, DocumentType, AllValidationsPassed, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@VR4as, @AS4, 4, 1, 1, 1, 1, 1, 1, 1, DATEADD(MINUTE,-20,@Now), @Now, 0);

    INSERT INTO ConfidenceScores (Id, PackageId, OverallConfidence, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@CF4, @Pkg4, 75.0, 92.0, 70.0, 80.0, 68.0, 65.0, 0, DATEADD(MINUTE,-20,@Now), @Now, 0);

    PRINT 'Submission 4 inserted: Gujarat Road Show (FAP-2025-0104)';
END
ELSE PRINT 'Submission 4 already exists - skipped';
