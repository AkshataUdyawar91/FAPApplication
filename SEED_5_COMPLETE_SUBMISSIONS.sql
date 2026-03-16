-- =============================================
-- Seed Script: 5 Complete Submissions with Full Validation Results
-- Purpose: Insert 5 DocumentPackages in PendingASM state with all documents,
--          validation results, confidence scores, and recommendations.
-- Database: BajajDocumentProcessing on localhost\SQLEXPRESS
-- Date: 2026-03-16
-- Idempotent: Uses IF NOT EXISTS checks
-- =============================================

-- First, get the Agency user and an Agency to link to
DECLARE @AgencyUserId UNIQUEIDENTIFIER;
DECLARE @AgencyId UNIQUEIDENTIFIER;
DECLARE @Now DATETIME2 = GETUTCDATE();

-- Get agency user
SELECT TOP 1 @AgencyUserId = Id FROM Users WHERE Email = 'agency@bajaj.com';

-- Get or create an agency
SELECT TOP 1 @AgencyId = Id FROM Agencies;

IF @AgencyId IS NULL
BEGIN
    SET @AgencyId = NEWID();
    INSERT INTO Agencies (Id, SupplierCode, SupplierName, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@AgencyId, 'SUP-001', 'Bajaj Marketing Solutions', @Now, @Now, 0);
    PRINT 'Created agency: Bajaj Marketing Solutions';
END

IF @AgencyUserId IS NULL
BEGIN
    PRINT 'ERROR: agency@bajaj.com user not found. Run the app first to seed users.';
    RETURN;
END

PRINT 'Using AgencyId: ' + CAST(@AgencyId AS NVARCHAR(50));
PRINT 'Using AgencyUserId: ' + CAST(@AgencyUserId AS NVARCHAR(50));

-- =============================================
-- SUBMISSION 1: All checks pass — Approve recommendation
-- =============================================
DECLARE @Pkg1 UNIQUEIDENTIFIER = 'A0000001-0001-0001-0001-000000000001';
DECLARE @PO1 UNIQUEIDENTIFIER = 'B0000001-0001-0001-0001-000000000001';
DECLARE @CS1 UNIQUEIDENTIFIER = 'C0000001-0001-0001-0001-000000000001';
DECLARE @AS1 UNIQUEIDENTIFIER = 'D0000001-0001-0001-0001-000000000001';
DECLARE @ED1 UNIQUEIDENTIFIER = 'E0000001-0001-0001-0001-000000000001';
DECLARE @Team1 UNIQUEIDENTIFIER = 'F0000001-0001-0001-0001-000000000001';
DECLARE @Inv1a UNIQUEIDENTIFIER = 'F1000001-0001-0001-0001-000000000001';
DECLARE @Conf1 UNIQUEIDENTIFIER = 'C1000001-0001-0001-0001-000000000001';
DECLARE @Rec1 UNIQUEIDENTIFIER = 'R0000001-0001-0001-0001-000000000001';

IF NOT EXISTS (SELECT 1 FROM DocumentPackages WHERE Id = @Pkg1)
BEGIN
    INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, VersionNumber, State, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Pkg1, @AgencyId, @AgencyUserId, 1, 4, DATEADD(DAY, -5, @Now), @Now, 0);

    INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@PO1, @Pkg1, @AgencyId, 'PO-2026-1001', DATEADD(DAY, -10, @Now), 'Bajaj Marketing Solutions', 250000.00, 'PO_1001.pdf', 'https://blob/po1.pdf', 102400, 'application/pdf', 0.95, 0, 1, @Now, @Now, 0);

    INSERT INTO CostSummaries (Id, PackageId, TotalCost, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@CS1, @Pkg1, 248000.00, 'CostSummary_1001.pdf', 'https://blob/cs1.pdf', 81920, 'application/pdf', 0.92, 0, 1, @Now, @Now, 0);

    INSERT INTO ActivitySummaries (Id, PackageId, ActivityDescription, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@AS1, @Pkg1, 'Dealer activation campaign in Maharashtra', 'Activity_1001.pdf', 'https://blob/as1.pdf', 61440, 'application/pdf', 0.90, 0, 1, @Now, @Now, 0);

    INSERT INTO EnquiryDocuments (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractedDataJson, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@ED1, @Pkg1, 'Enquiry_1001.xlsx', 'https://blob/ed1.xlsx', 40960, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', '{"totalRecords":120,"completeRecords":118}', 0.88, 0, 1, @Now, @Now, 0);

    INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, State, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Team1, @Pkg1, 'Maharashtra Campaign Q1', 'TEAM-MH-01', DATEADD(DAY, -30, @Now), DATEADD(DAY, -5, @Now), 25, 'Bajaj Auto Pune', 'Maharashtra', 1, @Now, @Now, 0);

    INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Inv1a, @Team1, @Pkg1, 'INV-2026-5001', DATEADD(DAY, -3, @Now), 'Bajaj Marketing Solutions', 250000.00, 'Invoice_5001.pdf', 'https://blob/inv1a.pdf', 71680, 'application/pdf', 0.93, 0, @Now, @Now, 0);

    -- Validation Results: ALL PASS
    INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, FailureReason, CreatedAt, UpdatedAt, IsDeleted)
    VALUES
        (NEWID(), 1, @PO1, 1, 1, 1, 1, 1, 1, 1, NULL, @Now, @Now, 0),
        (NEWID(), 2, @Inv1a, 1, 1, 1, 1, 1, 1, 1, NULL, @Now, @Now, 0),
        (NEWID(), 3, @CS1, 1, 1, 1, 1, 1, 1, 1, NULL, @Now, @Now, 0),
        (NEWID(), 4, @AS1, 1, 1, 1, 1, 1, 1, 1, NULL, @Now, @Now, 0),
        (NEWID(), 5, @ED1, 1, 1, 1, 1, 1, 1, 1, NULL, @Now, @Now, 0);

    INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Conf1, @Pkg1, 95, 93, 92, 90, 85, 92.1, 0, @Now, @Now, 0);

    INSERT INTO Recommendations (Id, PackageId, Type, Evidence, ConfidenceScore, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Rec1, @Pkg1, 1, 'All validation checks passed. Documents are consistent and complete. Recommend approval.', 92.1, @Now, @Now, 0);

    PRINT 'Submission 1 created: All Pass — Approve';
END
ELSE PRINT 'Submission 1 already exists, skipping.';

-- =============================================
-- SUBMISSION 2: Invoice fails (amount mismatch + missing fields) — Review recommendation
-- =============================================
DECLARE @Pkg2 UNIQUEIDENTIFIER = 'A0000002-0002-0002-0002-000000000002';
DECLARE @PO2 UNIQUEIDENTIFIER = 'B0000002-0002-0002-0002-000000000002';
DECLARE @CS2 UNIQUEIDENTIFIER = 'C0000002-0002-0002-0002-000000000002';
DECLARE @AS2 UNIQUEIDENTIFIER = 'D0000002-0002-0002-0002-000000000002';
DECLARE @ED2 UNIQUEIDENTIFIER = 'E0000002-0002-0002-0002-000000000002';
DECLARE @Team2 UNIQUEIDENTIFIER = 'F0000002-0002-0002-0002-000000000002';
DECLARE @Inv2a UNIQUEIDENTIFIER = 'F1000002-0002-0002-0002-000000000002';
DECLARE @Inv2b UNIQUEIDENTIFIER = 'F1000002-0002-0002-0002-000000000003';
DECLARE @Conf2 UNIQUEIDENTIFIER = 'C1000002-0002-0002-0002-000000000002';
DECLARE @Rec2 UNIQUEIDENTIFIER = 'R0000002-0002-0002-0002-000000000002';

IF NOT EXISTS (SELECT 1 FROM DocumentPackages WHERE Id = @Pkg2)
BEGIN
    INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, VersionNumber, State, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Pkg2, @AgencyId, @AgencyUserId, 1, 4, DATEADD(DAY, -4, @Now), @Now, 0);

    INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@PO2, @Pkg2, @AgencyId, 'PO-2026-1002', DATEADD(DAY, -12, @Now), 'Creative Ads India', 180000.00, 'PO_1002.pdf', 'https://blob/po2.pdf', 98304, 'application/pdf', 0.91, 0, 1, @Now, @Now, 0);

    INSERT INTO CostSummaries (Id, PackageId, TotalCost, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@CS2, @Pkg2, 175000.00, 'CostSummary_1002.pdf', 'https://blob/cs2.pdf', 77824, 'application/pdf', 0.89, 0, 1, @Now, @Now, 0);

    INSERT INTO ActivitySummaries (Id, PackageId, ActivityDescription, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@AS2, @Pkg2, 'Dealer activation in Gujarat', 'Activity_1002.pdf', 'https://blob/as2.pdf', 57344, 'application/pdf', 0.87, 0, 1, @Now, @Now, 0);

    INSERT INTO EnquiryDocuments (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractedDataJson, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@ED2, @Pkg2, 'Enquiry_1002.xlsx', 'https://blob/ed2.xlsx', 36864, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', '{"totalRecords":85,"completeRecords":80}', 0.85, 0, 1, @Now, @Now, 0);

    INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, State, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Team2, @Pkg2, 'Gujarat Campaign Q1', 'TEAM-GJ-01', DATEADD(DAY, -28, @Now), DATEADD(DAY, -4, @Now), 24, 'Bajaj Auto Ahmedabad', 'Gujarat', 1, @Now, @Now, 0);

    INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
    VALUES
        (@Inv2a, @Team2, @Pkg2, 'INV-2026-5002', DATEADD(DAY, -2, @Now), 'Creative Ads India', 120000.00, 'Invoice_5002.pdf', 'https://blob/inv2a.pdf', 65536, 'application/pdf', 0.88, 0, @Now, @Now, 0),
        (@Inv2b, @Team2, @Pkg2, 'INV-2026-5003', DATEADD(DAY, -2, @Now), 'Creative Ads India', 65000.00, 'Invoice_5003.pdf', 'https://blob/inv2b.pdf', 61440, 'application/pdf', 0.86, 0, @Now, @Now, 0);

    -- Validation Results: PO pass, Invoice FAIL (amount mismatch), CostSummary pass, Activity pass, Enquiry pass
    INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, FailureReason, CreatedAt, UpdatedAt, IsDeleted)
    VALUES
        (NEWID(), 1, @PO2, 1, 1, 1, 1, 1, 1, 1, NULL, @Now, @Now, 0),
        (NEWID(), 2, @Inv2a, 1, 0, 0, 1, 1, 1, 0, 'Invoice total (₹1,85,000) exceeds PO amount (₹1,80,000) by 2.8%; 2 PO line items missing from invoice', @Now, @Now, 0),
        (NEWID(), 3, @CS2, 1, 1, 1, 1, 1, 1, 1, NULL, @Now, @Now, 0),
        (NEWID(), 4, @AS2, 1, 1, 1, 1, 1, 1, 1, NULL, @Now, @Now, 0),
        (NEWID(), 5, @ED2, 1, 1, 1, 1, 1, 1, 1, NULL, @Now, @Now, 0);

    INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Conf2, @Pkg2, 91, 72, 89, 87, 80, 83.4, 0, @Now, @Now, 0);

    INSERT INTO Recommendations (Id, PackageId, Type, Evidence, ConfidenceScore, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Rec2, @Pkg2, 2, 'Invoice amount exceeds PO by 2.8%. Missing line items in invoice. Recommend manual review.', 83.4, @Now, @Now, 0);

    PRINT 'Submission 2 created: Invoice Fail — Review';
END
ELSE PRINT 'Submission 2 already exists, skipping.';

-- =============================================
-- SUBMISSION 3: Multiple failures (SAP, dates, vendor) — Reject recommendation
-- =============================================
DECLARE @Pkg3 UNIQUEIDENTIFIER = 'A0000003-0003-0003-0003-000000000003';
DECLARE @PO3 UNIQUEIDENTIFIER = 'B0000003-0003-0003-0003-000000000003';
DECLARE @CS3 UNIQUEIDENTIFIER = 'C0000003-0003-0003-0003-000000000003';
DECLARE @AS3 UNIQUEIDENTIFIER = 'D0000003-0003-0003-0003-000000000003';
DECLARE @ED3 UNIQUEIDENTIFIER = 'E0000003-0003-0003-0003-000000000003';
DECLARE @Team3 UNIQUEIDENTIFIER = 'F0000003-0003-0003-0003-000000000003';
DECLARE @Inv3a UNIQUEIDENTIFIER = 'F1000003-0003-0003-0003-000000000003';
DECLARE @Conf3 UNIQUEIDENTIFIER = 'C1000003-0003-0003-0003-000000000003';
DECLARE @Rec3 UNIQUEIDENTIFIER = 'R0000003-0003-0003-0003-000000000003';

IF NOT EXISTS (SELECT 1 FROM DocumentPackages WHERE Id = @Pkg3)
BEGIN
    INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, VersionNumber, State, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Pkg3, @AgencyId, @AgencyUserId, 1, 4, DATEADD(DAY, -3, @Now), @Now, 0);

    INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@PO3, @Pkg3, @AgencyId, 'PO-2026-1003', DATEADD(DAY, -15, @Now), 'Metro Events Pvt Ltd', 320000.00, 'PO_1003.pdf', 'https://blob/po3.pdf', 110592, 'application/pdf', 0.88, 0, 1, @Now, @Now, 0);

    INSERT INTO CostSummaries (Id, PackageId, TotalCost, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@CS3, @Pkg3, 310000.00, 'CostSummary_1003.pdf', 'https://blob/cs3.pdf', 86016, 'application/pdf', 0.84, 0, 1, @Now, @Now, 0);

    INSERT INTO ActivitySummaries (Id, PackageId, ActivityDescription, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@AS3, @Pkg3, 'Road show campaign in Karnataka', 'Activity_1003.pdf', 'https://blob/as3.pdf', 53248, 'application/pdf', 0.82, 0, 1, @Now, @Now, 0);

    INSERT INTO EnquiryDocuments (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractedDataJson, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@ED3, @Pkg3, 'Enquiry_1003.xlsx', 'https://blob/ed3.xlsx', 32768, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', '{"totalRecords":65,"completeRecords":50}', 0.78, 0, 1, @Now, @Now, 0);

    INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, State, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Team3, @Pkg3, 'Karnataka Road Show', 'TEAM-KA-01', DATEADD(DAY, -25, @Now), DATEADD(DAY, -3, @Now), 22, 'Bajaj Auto Bangalore', 'Karnataka', 1, @Now, @Now, 0);

    INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Inv3a, @Team3, @Pkg3, 'INV-2026-5004', DATEADD(DAY, -1, @Now), 'Metro Events Pvt Ltd', 315000.00, 'Invoice_5004.pdf', 'https://blob/inv3a.pdf', 69632, 'application/pdf', 0.85, 0, @Now, @Now, 0);

    -- Validation Results: PO FAIL (SAP + dates + vendor), Invoice FAIL (amount), CostSummary FAIL (completeness), Activity pass, Enquiry FAIL
    INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, FailureReason, CreatedAt, UpdatedAt, IsDeleted)
    VALUES
        (NEWID(), 1, @PO3, 0, 1, 1, 1, 0, 0, 0, 'PO not found in SAP system; PO date is 15 days before submission which exceeds 7-day threshold; Vendor name mismatch between PO and SAP records', @Now, @Now, 0),
        (NEWID(), 2, @Inv3a, 1, 0, 1, 1, 1, 1, 0, 'Invoice total (₹3,15,000) does not match PO amount (₹3,20,000) — difference of ₹5,000', @Now, @Now, 0),
        (NEWID(), 3, @CS3, 1, 1, 1, 0, 1, 1, 0, 'Cost breakdown missing 2 required line item categories', @Now, @Now, 0),
        (NEWID(), 4, @AS3, 1, 1, 1, 1, 1, 1, 1, NULL, @Now, @Now, 0),
        (NEWID(), 5, @ED3, 1, 1, 1, 0, 1, 1, 0, '15 of 65 enquiry records missing required fields (customer name, phone number)', @Now, @Now, 0);

    INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Conf3, @Pkg3, 62, 70, 68, 82, 75, 69.6, 1, @Now, @Now, 0);

    INSERT INTO Recommendations (Id, PackageId, Type, Evidence, ConfidenceScore, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Rec3, @Pkg3, 3, 'Multiple critical failures: PO not verified in SAP, date validation failed, vendor mismatch, amount inconsistency. Recommend rejection.', 69.6, @Now, @Now, 0);

    PRINT 'Submission 3 created: Multiple Failures — Reject';
END
ELSE PRINT 'Submission 3 already exists, skipping.';

-- =============================================
-- SUBMISSION 4: Cost Summary and Activity fail — Review recommendation
-- =============================================
DECLARE @Pkg4 UNIQUEIDENTIFIER = 'A0000004-0004-0004-0004-000000000004';
DECLARE @PO4 UNIQUEIDENTIFIER = 'B0000004-0004-0004-0004-000000000004';
DECLARE @CS4 UNIQUEIDENTIFIER = 'C0000004-0004-0004-0004-000000000004';
DECLARE @AS4 UNIQUEIDENTIFIER = 'D0000004-0004-0004-0004-000000000004';
DECLARE @ED4 UNIQUEIDENTIFIER = 'E0000004-0004-0004-0004-000000000004';
DECLARE @Team4 UNIQUEIDENTIFIER = 'F0000004-0004-0004-0004-000000000004';
DECLARE @Inv4a UNIQUEIDENTIFIER = 'F1000004-0004-0004-0004-000000000004';
DECLARE @Inv4b UNIQUEIDENTIFIER = 'F1000004-0004-0004-0004-000000000005';
DECLARE @Conf4 UNIQUEIDENTIFIER = 'C1000004-0004-0004-0004-000000000004';
DECLARE @Rec4 UNIQUEIDENTIFIER = 'R0000004-0004-0004-0004-000000000004';

IF NOT EXISTS (SELECT 1 FROM DocumentPackages WHERE Id = @Pkg4)
BEGIN
    INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, VersionNumber, State, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Pkg4, @AgencyId, @AgencyUserId, 1, 4, DATEADD(DAY, -2, @Now), @Now, 0);

    INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@PO4, @Pkg4, @AgencyId, 'PO-2026-1004', DATEADD(DAY, -8, @Now), 'Digital Reach Agency', 420000.00, 'PO_1004.pdf', 'https://blob/po4.pdf', 118784, 'application/pdf', 0.94, 0, 1, @Now, @Now, 0);

    INSERT INTO CostSummaries (Id, PackageId, TotalCost, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@CS4, @Pkg4, 415000.00, 'CostSummary_1004.pdf', 'https://blob/cs4.pdf', 90112, 'application/pdf', 0.80, 1, 1, @Now, @Now, 0);

    INSERT INTO ActivitySummaries (Id, PackageId, ActivityDescription, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@AS4, @Pkg4, 'Digital marketing campaign in Tamil Nadu', 'Activity_1004.pdf', 'https://blob/as4.pdf', 49152, 'application/pdf', 0.76, 1, 1, @Now, @Now, 0);

    INSERT INTO EnquiryDocuments (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractedDataJson, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@ED4, @Pkg4, 'Enquiry_1004.xlsx', 'https://blob/ed4.xlsx', 45056, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', '{"totalRecords":95,"completeRecords":92}', 0.90, 0, 1, @Now, @Now, 0);

    INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, State, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Team4, @Pkg4, 'Tamil Nadu Digital Campaign', 'TEAM-TN-01', DATEADD(DAY, -20, @Now), DATEADD(DAY, -2, @Now), 18, 'Bajaj Auto Chennai', 'Tamil Nadu', 1, @Now, @Now, 0);

    INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
    VALUES
        (@Inv4a, @Team4, @Pkg4, 'INV-2026-5005', DATEADD(DAY, -1, @Now), 'Digital Reach Agency', 280000.00, 'Invoice_5005.pdf', 'https://blob/inv4a.pdf', 73728, 'application/pdf', 0.91, 0, @Now, @Now, 0),
        (@Inv4b, @Team4, @Pkg4, 'INV-2026-5006', DATEADD(DAY, -1, @Now), 'Digital Reach Agency', 140000.00, 'Invoice_5006.pdf', 'https://blob/inv4b.pdf', 67584, 'application/pdf', 0.89, 0, @Now, @Now, 0);

    -- Validation Results: PO pass, Invoice pass, CostSummary FAIL (amount + vendor), Activity FAIL (completeness + dates), Enquiry pass
    INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, FailureReason, CreatedAt, UpdatedAt, IsDeleted)
    VALUES
        (NEWID(), 1, @PO4, 1, 1, 1, 1, 1, 1, 1, NULL, @Now, @Now, 0),
        (NEWID(), 2, @Inv4a, 1, 1, 1, 1, 1, 1, 1, NULL, @Now, @Now, 0),
        (NEWID(), 3, @CS4, 1, 0, 1, 1, 1, 0, 0, 'Cost summary total (₹4,15,000) differs from invoice total (₹4,20,000); Vendor name on cost summary does not match PO vendor', @Now, @Now, 0),
        (NEWID(), 4, @AS4, 1, 1, 1, 0, 0, 1, 0, 'Activity summary missing required team member details; Campaign dates in activity (Jan-Feb) do not match PO dates (Mar)', @Now, @Now, 0),
        (NEWID(), 5, @ED4, 1, 1, 1, 1, 1, 1, 1, NULL, @Now, @Now, 0);

    INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Conf4, @Pkg4, 94, 91, 65, 58, 78, 80.3, 1, @Now, @Now, 0);

    INSERT INTO Recommendations (Id, PackageId, Type, Evidence, ConfidenceScore, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Rec4, @Pkg4, 2, 'Cost summary and activity summary have validation failures. Cost total mismatch and missing activity details. Recommend review.', 80.3, @Now, @Now, 0);

    PRINT 'Submission 4 created: CostSummary + Activity Fail — Review';
END
ELSE PRINT 'Submission 4 already exists, skipping.';

-- =============================================
-- SUBMISSION 5: Enquiry document fails, rest pass — Approve recommendation (minor issue)
-- =============================================
DECLARE @Pkg5 UNIQUEIDENTIFIER = 'A0000005-0005-0005-0005-000000000005';
DECLARE @PO5 UNIQUEIDENTIFIER = 'B0000005-0005-0005-0005-000000000005';
DECLARE @CS5 UNIQUEIDENTIFIER = 'C0000005-0005-0005-0005-000000000005';
DECLARE @AS5 UNIQUEIDENTIFIER = 'D0000005-0005-0005-0005-000000000005';
DECLARE @ED5 UNIQUEIDENTIFIER = 'E0000005-0005-0005-0005-000000000005';
DECLARE @Team5 UNIQUEIDENTIFIER = 'F0000005-0005-0005-0005-000000000005';
DECLARE @Inv5a UNIQUEIDENTIFIER = 'F1000005-0005-0005-0005-000000000005';
DECLARE @Conf5 UNIQUEIDENTIFIER = 'C1000005-0005-0005-0005-000000000005';
DECLARE @Rec5 UNIQUEIDENTIFIER = 'R0000005-0005-0005-0005-000000000005';

IF NOT EXISTS (SELECT 1 FROM DocumentPackages WHERE Id = @Pkg5)
BEGIN
    INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, VersionNumber, State, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Pkg5, @AgencyId, @AgencyUserId, 1, 4, DATEADD(DAY, -1, @Now), @Now, 0);

    INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@PO5, @Pkg5, @AgencyId, 'PO-2026-1005', DATEADD(DAY, -6, @Now), 'Sunrise Promotions', 150000.00, 'PO_1005.pdf', 'https://blob/po5.pdf', 94208, 'application/pdf', 0.96, 0, 1, @Now, @Now, 0);

    INSERT INTO CostSummaries (Id, PackageId, TotalCost, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@CS5, @Pkg5, 148500.00, 'CostSummary_1005.pdf', 'https://blob/cs5.pdf', 73728, 'application/pdf', 0.93, 0, 1, @Now, @Now, 0);

    INSERT INTO ActivitySummaries (Id, PackageId, ActivityDescription, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@AS5, @Pkg5, 'Dealer meet and greet in Rajasthan', 'Activity_1005.pdf', 'https://blob/as5.pdf', 45056, 'application/pdf', 0.91, 0, 1, @Now, @Now, 0);

    INSERT INTO EnquiryDocuments (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractedDataJson, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@ED5, @Pkg5, 'Enquiry_1005.xlsx', 'https://blob/ed5.xlsx', 28672, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', '{"totalRecords":40,"completeRecords":28}', 0.70, 1, 1, @Now, @Now, 0);

    INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, State, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Team5, @Pkg5, 'Rajasthan Dealer Meet', 'TEAM-RJ-01', DATEADD(DAY, -15, @Now), DATEADD(DAY, -1, @Now), 14, 'Bajaj Auto Jaipur', 'Rajasthan', 1, @Now, @Now, 0);

    INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Inv5a, @Team5, @Pkg5, 'INV-2026-5007', @Now, 'Sunrise Promotions', 150000.00, 'Invoice_5007.pdf', 'https://blob/inv5a.pdf', 63488, 'application/pdf', 0.94, 0, @Now, @Now, 0);

    -- Validation Results: PO pass, Invoice pass, CostSummary pass, Activity pass, Enquiry FAIL (completeness + vendor)
    INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, FailureReason, CreatedAt, UpdatedAt, IsDeleted)
    VALUES
        (NEWID(), 1, @PO5, 1, 1, 1, 1, 1, 1, 1, NULL, @Now, @Now, 0),
        (NEWID(), 2, @Inv5a, 1, 1, 1, 1, 1, 1, 1, NULL, @Now, @Now, 0),
        (NEWID(), 3, @CS5, 1, 1, 1, 1, 1, 1, 1, NULL, @Now, @Now, 0),
        (NEWID(), 4, @AS5, 1, 1, 1, 1, 1, 1, 1, NULL, @Now, @Now, 0),
        (NEWID(), 5, @ED5, 1, 1, 1, 0, 1, 0, 0, '12 of 40 enquiry records missing customer name; Dealer codes in enquiry do not match activity summary dealer', @Now, @Now, 0);

    INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Conf5, @Pkg5, 96, 94, 93, 91, 82, 92.5, 0, @Now, @Now, 0);

    INSERT INTO Recommendations (Id, PackageId, Type, Evidence, ConfidenceScore, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (@Rec5, @Pkg5, 1, 'Core documents (PO, Invoice, Cost Summary, Activity) all pass validation. Enquiry document has minor completeness issues but does not affect approval. Recommend approval.', 92.5, @Now, @Now, 0);

    PRINT 'Submission 5 created: Enquiry Fail only — Approve';
END
ELSE PRINT 'Submission 5 already exists, skipping.';

PRINT '';
PRINT '=== Seed complete. 5 submissions created in PendingASM state. ===';
PRINT 'Submission 1: All Pass — Approve';
PRINT 'Submission 2: Invoice Fail — Review';
PRINT 'Submission 3: Multiple Failures — Reject';
PRINT 'Submission 4: CostSummary + Activity Fail — Review';
PRINT 'Submission 5: Enquiry Fail only — Approve';
