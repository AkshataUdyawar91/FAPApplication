USE BajajDocumentProcessing;
GO

-- =============================================
-- Seed Data Script for Demo
-- Creates: 2 Agencies, 5 Document Packages at various states,
--          POs, Invoices, ValidationResults, ConfidenceScores, Recommendations
-- =============================================

DECLARE @AgencyUser UNIQUEIDENTIFIER = 'A4484037-FB82-4952-B5A6-BCABE8B92F49';
DECLARE @ASMUser UNIQUEIDENTIFIER = '94CD8CE5-E71E-41A0-86DD-BB22BFD28155';
DECLARE @Now DATETIME2 = GETUTCDATE();

-- === AGENCIES ===
DECLARE @Agency1 UNIQUEIDENTIFIER = NEWID();
DECLARE @Agency2 UNIQUEIDENTIFIER = NEWID();

IF NOT EXISTS (SELECT 1 FROM Agencies WHERE SupplierCode = 'AGN-001')
BEGIN
    SET @Agency1 = NEWID();
    INSERT INTO Agencies (Id, SupplierCode, SupplierName, CreatedAt, IsDeleted)
    VALUES (@Agency1, 'AGN-001', 'Sharma Auto Parts Pvt Ltd', @Now, 0);
END
ELSE
    SELECT @Agency1 = Id FROM Agencies WHERE SupplierCode = 'AGN-001';

IF NOT EXISTS (SELECT 1 FROM Agencies WHERE SupplierCode = 'AGN-002')
BEGIN
    SET @Agency2 = NEWID();
    INSERT INTO Agencies (Id, SupplierCode, SupplierName, CreatedAt, IsDeleted)
    VALUES (@Agency2, 'AGN-002', 'Patel Motors & Services', @Now, 0);
END
ELSE
    SELECT @Agency2 = Id FROM Agencies WHERE SupplierCode = 'AGN-002';

-- Link agency user to Agency1
UPDATE Users SET AgencyId = @Agency1 WHERE Id = @AgencyUser;

-- === PACKAGE 1: Approved (full pipeline) ===
DECLARE @Pkg1 UNIQUEIDENTIFIER = NEWID();
DECLARE @PO1 UNIQUEIDENTIFIER = NEWID();
DECLARE @Inv1 UNIQUEIDENTIFIER = NEWID();

INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, VersionNumber, State, CreatedAt, IsDeleted, CreatedBy)
VALUES (@Pkg1, @Agency1, @AgencyUser, 1, 8, DATEADD(DAY, -10, @Now), 0, 'agency@bajaj.com');

INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, IsDeleted)
VALUES (@PO1, @Pkg1, @Agency1, 'PO-2026-0001', DATEADD(DAY, -15, @Now), 'Sharma Auto Parts Pvt Ltd', 250000.00, 'PO_2026_0001.pdf', 'https://storage.blob.core.windows.net/documents/po1.pdf', 524288, 'application/pdf', 0.95, 0, 1, DATEADD(DAY, -10, @Now), 0);

INSERT INTO Invoices (Id, PackageId, POId, VersionNumber, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, CreatedAt, IsDeleted)
VALUES (@Inv1, @Pkg1, @PO1, 1, 'INV-2026-0001', DATEADD(DAY, -12, @Now), 'Sharma Auto Parts Pvt Ltd', '27AABCS1234F1ZP', 211864.41, 38135.59, 250000.00, 'INV_2026_0001.pdf', 'https://storage.blob.core.windows.net/documents/inv1.pdf', 412672, 'application/pdf', 0.92, 0, DATEADD(DAY, -10, @Now), 0);

INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, IsDeleted)
VALUES (NEWID(), 0, @PO1, 1, 1, 1, 1, 1, 1, 1, DATEADD(DAY, -9, @Now), 0);

INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, IsDeleted)
VALUES (NEWID(), 1, @Inv1, 1, 1, 1, 1, 1, 1, 1, DATEADD(DAY, -9, @Now), 0);

INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, IsDeleted)
VALUES (NEWID(), @Pkg1, 95.0, 92.0, 88.0, 85.0, 90.0, 91.5, 0, DATEADD(DAY, -9, @Now), 0);

INSERT INTO Recommendations (Id, PackageId, Type, Evidence, ConfidenceScore, CreatedAt, IsDeleted)
VALUES (NEWID(), @Pkg1, 0, 'All documents validated successfully. PO and Invoice amounts match. Vendor details consistent across documents. Confidence score 91.5% exceeds approval threshold.', 91.5, DATEADD(DAY, -8, @Now), 0);


-- === PACKAGE 2: PendingASM (awaiting ASM review) ===
DECLARE @Pkg2 UNIQUEIDENTIFIER = NEWID();
DECLARE @PO2 UNIQUEIDENTIFIER = NEWID();
DECLARE @Inv2 UNIQUEIDENTIFIER = NEWID();

INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, VersionNumber, State, CreatedAt, IsDeleted, CreatedBy)
VALUES (@Pkg2, @Agency1, @AgencyUser, 1, 4, DATEADD(DAY, -3, @Now), 0, 'agency@bajaj.com');

INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, IsDeleted)
VALUES (@PO2, @Pkg2, @Agency1, 'PO-2026-0002', DATEADD(DAY, -7, @Now), 'Sharma Auto Parts Pvt Ltd', 175000.00, 'PO_2026_0002.pdf', 'https://storage.blob.core.windows.net/documents/po2.pdf', 498000, 'application/pdf', 0.88, 0, 1, DATEADD(DAY, -3, @Now), 0);

INSERT INTO Invoices (Id, PackageId, POId, VersionNumber, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, CreatedAt, IsDeleted)
VALUES (@Inv2, @Pkg2, @PO2, 1, 'INV-2026-0002', DATEADD(DAY, -5, @Now), 'Sharma Auto Parts Pvt Ltd', '27AABCS1234F1ZP', 148305.08, 26694.92, 175000.00, 'INV_2026_0002.pdf', 'https://storage.blob.core.windows.net/documents/inv2.pdf', 389120, 'application/pdf', 0.85, 0, DATEADD(DAY, -3, @Now), 0);

INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, IsDeleted)
VALUES (NEWID(), 0, @PO2, 1, 1, 1, 1, 1, 1, 1, DATEADD(DAY, -2, @Now), 0);

INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, IsDeleted)
VALUES (NEWID(), @Pkg2, 88.0, 85.0, 0.0, 0.0, 0.0, 78.2, 1, DATEADD(DAY, -2, @Now), 0);

INSERT INTO Recommendations (Id, PackageId, Type, Evidence, ConfidenceScore, CreatedAt, IsDeleted)
VALUES (NEWID(), @Pkg2, 1, 'PO and Invoice validated. Missing Cost Summary and Activity documents. Overall confidence 78.2% is below auto-approval threshold. Manual review recommended.', 78.2, DATEADD(DAY, -2, @Now), 0);

-- === PACKAGE 3: PendingRA (passed ASM, awaiting RA) ===
DECLARE @Pkg3 UNIQUEIDENTIFIER = NEWID();
DECLARE @PO3 UNIQUEIDENTIFIER = NEWID();
DECLARE @Inv3 UNIQUEIDENTIFIER = NEWID();

INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, VersionNumber, State, CreatedAt, IsDeleted, CreatedBy)
VALUES (@Pkg3, @Agency2, @AgencyUser, 1, 6, DATEADD(DAY, -5, @Now), 0, 'agency@bajaj.com');

INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, IsDeleted)
VALUES (@PO3, @Pkg3, @Agency2, 'PO-2026-0003', DATEADD(DAY, -10, @Now), 'Patel Motors & Services', 320000.00, 'PO_2026_0003.pdf', 'https://storage.blob.core.windows.net/documents/po3.pdf', 556032, 'application/pdf', 0.97, 0, 1, DATEADD(DAY, -5, @Now), 0);

INSERT INTO Invoices (Id, PackageId, POId, VersionNumber, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, CreatedAt, IsDeleted)
VALUES (@Inv3, @Pkg3, @PO3, 1, 'INV-2026-0003', DATEADD(DAY, -7, @Now), 'Patel Motors & Services', '24AABCP5678G2ZQ', 271186.44, 48813.56, 320000.00, 'INV_2026_0003.pdf', 'https://storage.blob.core.windows.net/documents/inv3.pdf', 445440, 'application/pdf', 0.94, 0, DATEADD(DAY, -5, @Now), 0);

INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, IsDeleted)
VALUES (NEWID(), @Pkg3, 97.0, 94.0, 91.0, 88.0, 92.0, 93.1, 0, DATEADD(DAY, -4, @Now), 0);

INSERT INTO Recommendations (Id, PackageId, Type, Evidence, ConfidenceScore, CreatedAt, IsDeleted)
VALUES (NEWID(), @Pkg3, 0, 'All documents present and validated. High confidence across all document types. PO-Invoice amounts match perfectly. Recommended for approval.', 93.1, DATEADD(DAY, -4, @Now), 0);

-- === PACKAGE 4: ASMRejected ===
DECLARE @Pkg4 UNIQUEIDENTIFIER = NEWID();
DECLARE @PO4 UNIQUEIDENTIFIER = NEWID();
DECLARE @Inv4 UNIQUEIDENTIFIER = NEWID();

INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, VersionNumber, State, CreatedAt, IsDeleted, CreatedBy)
VALUES (@Pkg4, @Agency1, @AgencyUser, 1, 5, DATEADD(DAY, -7, @Now), 0, 'agency@bajaj.com');

INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, IsDeleted)
VALUES (@PO4, @Pkg4, @Agency1, 'PO-2026-0004', DATEADD(DAY, -14, @Now), 'Sharma Auto Parts Pvt Ltd', 95000.00, 'PO_2026_0004.pdf', 'https://storage.blob.core.windows.net/documents/po4.pdf', 312000, 'application/pdf', 0.72, 1, 1, DATEADD(DAY, -7, @Now), 0);

INSERT INTO Invoices (Id, PackageId, POId, VersionNumber, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, CreatedAt, IsDeleted)
VALUES (@Inv4, @Pkg4, @PO4, 1, 'INV-2026-0004', DATEADD(DAY, -9, @Now), 'Sharma Auto Parts Pvt Ltd', '27AABCS1234F1ZP', 88000.00, 7000.00, 95000.00, 'INV_2026_0004.pdf', 'https://storage.blob.core.windows.net/documents/inv4.pdf', 298000, 'application/pdf', 0.68, 1, DATEADD(DAY, -7, @Now), 0);

INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, FailureReason, CreatedAt, IsDeleted)
VALUES (NEWID(), 1, @Inv4, 1, 0, 0, 1, 1, 1, 0, 'Invoice amount mismatch: SubTotal + Tax does not equal TotalAmount. Line items do not match PO line items.', DATEADD(DAY, -6, @Now), 0);

INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, IsDeleted)
VALUES (NEWID(), @Pkg4, 72.0, 68.0, 0.0, 0.0, 0.0, 55.6, 1, DATEADD(DAY, -6, @Now), 0);

INSERT INTO Recommendations (Id, PackageId, Type, Evidence, ConfidenceScore, CreatedAt, IsDeleted)
VALUES (NEWID(), @Pkg4, 2, 'Invoice validation failed: amount inconsistency detected. Line items do not match PO. Low extraction confidence on both documents. Rejection recommended.', 55.6, DATEADD(DAY, -6, @Now), 0);

-- === PACKAGE 5: Uploaded (just submitted, not yet processed) ===
DECLARE @Pkg5 UNIQUEIDENTIFIER = NEWID();
DECLARE @PO5 UNIQUEIDENTIFIER = NEWID();

INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, VersionNumber, State, CreatedAt, IsDeleted, CreatedBy)
VALUES (@Pkg5, @Agency2, @AgencyUser, 1, 1, DATEADD(HOUR, -2, @Now), 0, 'agency@bajaj.com');

INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractionConfidence, IsFlaggedForReview, VersionNumber, CreatedAt, IsDeleted)
VALUES (@PO5, @Pkg5, @Agency2, 'PO-2026-0005', DATEADD(DAY, -1, @Now), 'Patel Motors & Services', 410000.00, 'PO_2026_0005.pdf', 'https://storage.blob.core.windows.net/documents/po5.pdf', 612000, 'application/pdf', 0.0, 0, 1, DATEADD(HOUR, -2, @Now), 0);

-- === NOTIFICATIONS ===
DECLARE @Notif1 UNIQUEIDENTIFIER = NEWID();
DECLARE @Notif2 UNIQUEIDENTIFIER = NEWID();
DECLARE @Notif3 UNIQUEIDENTIFIER = NEWID();

-- Check Notifications columns first
INSERT INTO Notifications (Id, UserId, Type, Title, Message, IsRead, RelatedEntityId, CreatedAt, IsDeleted)
VALUES 
(@Notif1, @AgencyUser, 0, 'Package Approved', 'Your submission PO-2026-0001 has been approved.', 1, @Pkg1, DATEADD(DAY, -8, @Now), 0),
(@Notif2, @ASMUser, 0, 'New Submission for Review', 'A new submission PO-2026-0002 from Sharma Auto Parts requires your review.', 0, @Pkg2, DATEADD(DAY, -2, @Now), 0),
(@Notif3, @AgencyUser, 0, 'Package Rejected', 'Your submission PO-2026-0004 has been rejected. Reason: Invoice amount mismatch.', 0, @Pkg4, DATEADD(DAY, -6, @Now), 0);

PRINT 'Seed data inserted successfully!';
PRINT 'Packages created: 5 (Approved, PendingASM, PendingRA, ASMRejected, Uploaded)';
PRINT 'Agencies created: 2';
GO
