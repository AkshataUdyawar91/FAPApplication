-- =============================================
-- Script: SEED_TEAMS_TEST_DATA.sql
-- Purpose: Seed complete test submissions with ALL related entities
--          (PO, Teams, CampaignInvoices, TeamPhotos, CostSummary,
--           ActivitySummary, EnquiryDocument, ValidationResults,
--           ConfidenceScores, Recommendations, RequestApprovalHistory)
--          so every role has data visible in the Teams chatbot.
-- Date: 2026-03-18
-- Idempotent: Yes — checks before inserting.
-- Rollback: Run CLEANUP section at bottom.
-- =============================================

-- Guard: only run if no test submissions exist yet
IF EXISTS (SELECT 1 FROM DocumentPackages WHERE SubmissionNumber LIKE 'CIQ-TEST-%')
BEGIN
    PRINT 'Test data already exists — skipping.';
    RETURN;
END

DECLARE @now DATETIME2 = SYSUTCDATETIME();

-- ============ Resolve user IDs ============
DECLARE @agencyUserId UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM Users WHERE Email = 'agency@bajaj.com' AND IsActive = 1);
DECLARE @agencyId UNIQUEIDENTIFIER = (SELECT TOP 1 AgencyId FROM Users WHERE Email = 'agency@bajaj.com');

DECLARE @asm1Id UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM Users WHERE Email = 'asm@bajaj.com');
DECLARE @asm2Id UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM Users WHERE Email = 'asm2@bajaj.com');
DECLARE @asm3Id UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM Users WHERE Email = 'asm3@bajaj.com');
DECLARE @asm5Id UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM Users WHERE Email = 'asm5@bajaj.com');
DECLARE @asm6Id UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM Users WHERE Email = 'asm6@bajaj.com');
DECLARE @asm8Id UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM Users WHERE Email = 'asm8@bajaj.com');

DECLARE @ra1Id UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM Users WHERE Email = 'ra@bajaj.com');
DECLARE @ra2Id UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM Users WHERE Email = 'ra2@bajaj.com');

IF @agencyUserId IS NULL OR @agencyId IS NULL
BEGIN
    PRINT 'ERROR: agency@bajaj.com not found or has no AgencyId.';
    RETURN;
END

-- ============================================================
-- HELPER: Reusable ID variables per submission
-- Each submission gets: Package, PO, Team, CampaignInvoice,
--   TeamPhoto, CostSummary, ActivitySummary, EnquiryDocument
-- ============================================================

-- ============================================================
-- SUBMISSION 1: PendingASM for asm@bajaj.com (Maharashtra)
-- ============================================================
DECLARE @pkg1 UNIQUEIDENTIFIER = NEWID();
DECLARE @po1 UNIQUEIDENTIFIER = NEWID();
DECLARE @team1 UNIQUEIDENTIFIER = NEWID();
DECLARE @cinv1 UNIQUEIDENTIFIER = NEWID();
DECLARE @photo1 UNIQUEIDENTIFIER = NEWID();
DECLARE @cs1 UNIQUEIDENTIFIER = NEWID();
DECLARE @as1 UNIQUEIDENTIFIER = NEWID();
DECLARE @ed1 UNIQUEIDENTIFIER = NEWID();

INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, State, ActivityState, SubmissionNumber, AssignedCircleHeadUserId, AssignedRAUserId, VersionNumber, CurrentStep, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@pkg1, @agencyId, @agencyUserId, 4, 'Maharashtra', 'CIQ-TEST-00001', @asm1Id, NULL, 1, 0, DATEADD(HOUR,-3,@now), @now, 0);

INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, RemainingBalance, POStatus, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@po1, @pkg1, @agencyId, 'PO-TEST-MH-001', '2026-03-10', 'Demo Agency', 450000, 450000, 'Open', 'po_mh001.pdf', 'seed://po-mh-001', 1048576, 'application/pdf', 0, 1, @now, @now, 0);

INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, DealershipAddress, State, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@team1, @pkg1, 'Maharashtra Campaign Q1', 'MH-T01', '2026-03-01', '2026-03-15', 12, 'Bajaj Auto Pune', '123 MG Road, Pune 411001', 'Maharashtra', 1, @now, @now, 0);

INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cinv1, @team1, @pkg1, 'INV-MH-2026-001', '2026-03-12', 'Demo Agency', '27AABCU9603R1ZM', 381356, 68644, 450000, 'inv_mh001.pdf', 'seed://inv-mh-001', 524288, 'application/pdf', 0, @now, @now, 0);

INSERT INTO TeamPhotos (Id, TeamId, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, DisplayOrder, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@photo1, @team1, @pkg1, 'photo_mh001.jpg', 'seed://photo-mh-001', 2097152, 'image/jpeg', 0, 1, 1, @now, @now, 0);

INSERT INTO CostSummaries (Id, PackageId, TotalCost, PlaceOfSupply, NumberOfDays, NumberOfActivations, NumberOfTeams, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cs1, @pkg1, 450000, 'Maharashtra', 12, 8, 1, 'cost_mh001.xlsx', 'seed://cost-mh-001', 262144, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 0, 1, @now, @now, 0);

INSERT INTO ActivitySummaries (Id, PackageId, ActivityDescription, DealerName, TotalDays, TotalWorkingDays, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@as1, @pkg1, 'BTL activation at Bajaj Auto Pune dealership — product demos and test rides', 'Bajaj Auto Pune', 15, 12, 'activity_mh001.xlsx', 'seed://activity-mh-001', 196608, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 0, 1, @now, @now, 0);

INSERT INTO EnquiryDocuments (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractedDataJson, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@ed1, @pkg1, 'enquiry_mh001.xlsx', 'seed://enquiry-mh-001', 327680, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  '{"totalRecords":87,"completeRecords":84,"incompleteRecords":3,"fields":["Name","Phone","Date","State","Model"]}',
  0, 1, @now, @now, 0);

INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg1, 92.5, 88.0, 85.0, 90.0, 78.0, 88.35, 0, @now, @now, 0);

INSERT INTO Recommendations (Id, PackageId, [Type], Evidence, ConfidenceScore, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg1, 1, 'All documents verified. PO amount matches invoice total. Activity photos geotagged within Maharashtra. Recommend approval.', 88.35, @now, @now, 0);

-- ValidationResults for submission 1
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 1, @po1, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 2, @cinv1, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 3, @cs1, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 4, @as1, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 5, @ed1, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);

-- ============================================================
-- SUBMISSION 2: PendingASM for asm@bajaj.com (Maharashtra — review)
-- ============================================================
DECLARE @pkg2 UNIQUEIDENTIFIER = NEWID();
DECLARE @po2 UNIQUEIDENTIFIER = NEWID();
DECLARE @team2 UNIQUEIDENTIFIER = NEWID();
DECLARE @cinv2 UNIQUEIDENTIFIER = NEWID();
DECLARE @photo2 UNIQUEIDENTIFIER = NEWID();
DECLARE @cs2 UNIQUEIDENTIFIER = NEWID();
DECLARE @as2 UNIQUEIDENTIFIER = NEWID();
DECLARE @ed2 UNIQUEIDENTIFIER = NEWID();

INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, State, ActivityState, SubmissionNumber, AssignedCircleHeadUserId, AssignedRAUserId, VersionNumber, CurrentStep, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@pkg2, @agencyId, @agencyUserId, 4, 'Maharashtra', 'CIQ-TEST-00002', @asm1Id, NULL, 1, 0, DATEADD(HOUR,-1,@now), @now, 0);

INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, RemainingBalance, POStatus, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@po2, @pkg2, @agencyId, 'PO-TEST-MH-002', '2026-03-12', 'Demo Agency', 280000, 280000, 'Open', 'po_mh002.pdf', 'seed://po-mh-002', 1048576, 'application/pdf', 0, 1, @now, @now, 0);

INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, DealershipAddress, State, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@team2, @pkg2, 'Maharashtra Campaign Q1-B', 'MH-T02', '2026-03-05', '2026-03-18', 10, 'Bajaj Auto Mumbai', '456 Link Road, Mumbai 400053', 'Maharashtra', 1, @now, @now, 0);

INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cinv2, @team2, @pkg2, 'INV-MH-2026-002', '2026-03-14', 'Demo Agency', '27AABCU9603R1ZM', 237288, 42712, 280000, 'inv_mh002.pdf', 'seed://inv-mh-002', 524288, 'application/pdf', 1, @now, @now, 0);

INSERT INTO TeamPhotos (Id, TeamId, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, DisplayOrder, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@photo2, @team2, @pkg2, 'photo_mh002.jpg', 'seed://photo-mh-002', 2097152, 'image/jpeg', 0, 1, 1, @now, @now, 0);

INSERT INTO CostSummaries (Id, PackageId, TotalCost, PlaceOfSupply, NumberOfDays, NumberOfActivations, NumberOfTeams, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cs2, @pkg2, 280000, 'Maharashtra', 10, 6, 1, 'cost_mh002.xlsx', 'seed://cost-mh-002', 262144, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 0, 1, @now, @now, 0);

INSERT INTO ActivitySummaries (Id, PackageId, ActivityDescription, DealerName, TotalDays, TotalWorkingDays, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@as2, @pkg2, 'BTL activation at Bajaj Auto Mumbai — product showcase', 'Bajaj Auto Mumbai', 13, 10, 'activity_mh002.xlsx', 'seed://activity-mh-002', 196608, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 0, 1, @now, @now, 0);

INSERT INTO EnquiryDocuments (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractedDataJson, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@ed2, @pkg2, 'enquiry_mh002.xlsx', 'seed://enquiry-mh-002', 327680, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  '{"totalRecords":52,"completeRecords":45,"incompleteRecords":7,"fields":["Name","Phone","Date","State","Model"]}',
  0, 1, @now, @now, 0);

INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg2, 75.0, 68.0, 70.0, 60.0, 55.0, 68.5, 1, @now, @now, 0);

INSERT INTO Recommendations (Id, PackageId, [Type], Evidence, ConfidenceScore, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg2, 2, 'Invoice amount exceeds PO remaining balance by 12%. Activity photos lack GPS metadata. Recommend manual review.', 68.5, @now, @now, 0);

-- ValidationResults for submission 2 (some failures)
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 1, @po2, 1, 0, 1, 1, 1, 1, 0, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 2, @cinv2, 1, 0, 1, 0, 1, 1, 0, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 3, @cs2, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 4, @as2, 1, 1, 1, 0, 1, 1, 0, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 5, @ed2, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);

-- ============================================================
-- SUBMISSION 3: PendingASM for asm2@bajaj.com (Gujarat)
-- ============================================================
DECLARE @pkg3 UNIQUEIDENTIFIER = NEWID();
DECLARE @po3 UNIQUEIDENTIFIER = NEWID();
DECLARE @team3 UNIQUEIDENTIFIER = NEWID();
DECLARE @cinv3 UNIQUEIDENTIFIER = NEWID();
DECLARE @photo3 UNIQUEIDENTIFIER = NEWID();
DECLARE @cs3 UNIQUEIDENTIFIER = NEWID();
DECLARE @as3 UNIQUEIDENTIFIER = NEWID();
DECLARE @ed3 UNIQUEIDENTIFIER = NEWID();

INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, State, ActivityState, SubmissionNumber, AssignedCircleHeadUserId, AssignedRAUserId, VersionNumber, CurrentStep, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@pkg3, @agencyId, @agencyUserId, 4, 'Gujarat', 'CIQ-TEST-00003', @asm2Id, NULL, 1, 0, DATEADD(HOUR,-5,@now), @now, 0);

INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, RemainingBalance, POStatus, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@po3, @pkg3, @agencyId, 'PO-TEST-GJ-001', '2026-03-08', 'Demo Agency', 620000, 500000, 'PartiallyConsumed', 'po_gj001.pdf', 'seed://po-gj-001', 1048576, 'application/pdf', 0, 1, @now, @now, 0);

INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, DealershipAddress, State, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@team3, @pkg3, 'Gujarat Campaign Q1', 'GJ-T01', '2026-03-01', '2026-03-20', 15, 'Bajaj Auto Ahmedabad', '789 SG Highway, Ahmedabad 380054', 'Gujarat', 1, @now, @now, 0);

INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cinv3, @team3, @pkg3, 'INV-GJ-2026-001', '2026-03-15', 'Demo Agency', '24AABCU9603R1ZN', 525424, 94576, 620000, 'inv_gj001.pdf', 'seed://inv-gj-001', 524288, 'application/pdf', 0, @now, @now, 0);

INSERT INTO TeamPhotos (Id, TeamId, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, DisplayOrder, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@photo3, @team3, @pkg3, 'photo_gj001.jpg', 'seed://photo-gj-001', 2097152, 'image/jpeg', 0, 1, 1, @now, @now, 0);

INSERT INTO CostSummaries (Id, PackageId, TotalCost, PlaceOfSupply, NumberOfDays, NumberOfActivations, NumberOfTeams, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cs3, @pkg3, 620000, 'Gujarat', 15, 10, 1, 'cost_gj001.xlsx', 'seed://cost-gj-001', 262144, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 0, 1, @now, @now, 0);

INSERT INTO ActivitySummaries (Id, PackageId, ActivityDescription, DealerName, TotalDays, TotalWorkingDays, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@as3, @pkg3, 'BTL activation at Bajaj Auto Ahmedabad — roadshow and test rides', 'Bajaj Auto Ahmedabad', 20, 15, 'activity_gj001.xlsx', 'seed://activity-gj-001', 196608, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 0, 1, @now, @now, 0);

INSERT INTO EnquiryDocuments (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractedDataJson, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@ed3, @pkg3, 'enquiry_gj001.xlsx', 'seed://enquiry-gj-001', 327680, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  '{"totalRecords":120,"completeRecords":115,"incompleteRecords":5,"fields":["Name","Phone","Date","State","Model"]}',
  0, 1, @now, @now, 0);

INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg3, 95.0, 91.0, 88.0, 92.0, 85.0, 91.3, 0, @now, @now, 0);

INSERT INTO Recommendations (Id, PackageId, [Type], Evidence, ConfidenceScore, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg3, 1, 'All validations passed. PO balance sufficient. Invoice dates within PO period. Strong recommendation to approve.', 91.3, @now, @now, 0);

INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 1, @po3, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 2, @cinv3, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 3, @cs3, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 4, @as3, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 5, @ed3, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);

-- ============================================================
-- SUBMISSION 4: PendingASM for asm3@bajaj.com (Karnataka — reject)
-- ============================================================
DECLARE @pkg4 UNIQUEIDENTIFIER = NEWID();
DECLARE @po4 UNIQUEIDENTIFIER = NEWID();
DECLARE @team4 UNIQUEIDENTIFIER = NEWID();
DECLARE @cinv4 UNIQUEIDENTIFIER = NEWID();
DECLARE @photo4 UNIQUEIDENTIFIER = NEWID();
DECLARE @cs4 UNIQUEIDENTIFIER = NEWID();
DECLARE @as4 UNIQUEIDENTIFIER = NEWID();
DECLARE @ed4 UNIQUEIDENTIFIER = NEWID();

INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, State, ActivityState, SubmissionNumber, AssignedCircleHeadUserId, AssignedRAUserId, VersionNumber, CurrentStep, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@pkg4, @agencyId, @agencyUserId, 4, 'Karnataka', 'CIQ-TEST-00004', @asm3Id, NULL, 1, 0, DATEADD(HOUR,-2,@now), @now, 0);

INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, RemainingBalance, POStatus, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@po4, @pkg4, @agencyId, 'PO-TEST-KA-001', '2026-03-05', 'Demo Agency', 380000, 380000, 'Open', 'po_ka001.pdf', 'seed://po-ka-001', 1048576, 'application/pdf', 0, 1, @now, @now, 0);

INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, DealershipAddress, State, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@team4, @pkg4, 'Karnataka Campaign Q1', 'KA-T01', '2026-03-01', '2026-03-12', 9, 'Bajaj Auto Bangalore', '321 Brigade Road, Bangalore 560001', 'Karnataka', 1, @now, @now, 0);

INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cinv4, @team4, @pkg4, 'INV-KA-2026-001', '2026-03-10', 'Demo Agency', '29AABCU9603R1ZP', 322034, 57966, 380000, 'inv_ka001.pdf', 'seed://inv-ka-001', 524288, 'application/pdf', 1, @now, @now, 0);

INSERT INTO TeamPhotos (Id, TeamId, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, DisplayOrder, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@photo4, @team4, @pkg4, 'photo_ka001.jpg', 'seed://photo-ka-001', 2097152, 'image/jpeg', 0, 1, 1, @now, @now, 0);

INSERT INTO CostSummaries (Id, PackageId, TotalCost, PlaceOfSupply, NumberOfDays, NumberOfActivations, NumberOfTeams, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cs4, @pkg4, 380000, 'Karnataka', 9, 5, 1, 'cost_ka001.xlsx', 'seed://cost-ka-001', 262144, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 1, 1, @now, @now, 0);

INSERT INTO ActivitySummaries (Id, PackageId, ActivityDescription, DealerName, TotalDays, TotalWorkingDays, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@as4, @pkg4, 'BTL activation at Bajaj Auto Bangalore — mall kiosk', 'Bajaj Auto Bangalore', 12, 9, 'activity_ka001.xlsx', 'seed://activity-ka-001', 196608, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 0, 1, @now, @now, 0);

INSERT INTO EnquiryDocuments (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractedDataJson, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@ed4, @pkg4, 'enquiry_ka001.xlsx', 'seed://enquiry-ka-001', 327680, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  '{"totalRecords":30,"completeRecords":18,"incompleteRecords":12,"fields":["Name","Phone","Date","State","Model"]}',
  0, 1, @now, @now, 0);

INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg4, 50.0, 45.0, 40.0, 35.0, 30.0, 42.5, 1, @now, @now, 0);

INSERT INTO Recommendations (Id, PackageId, [Type], Evidence, ConfidenceScore, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg4, 3, 'Multiple validation failures: PO number not found in SAP, invoice vendor mismatch, cost summary totals do not reconcile. Recommend rejection.', 42.5, @now, @now, 0);

INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 1, @po4, 0, 0, 0, 1, 1, 0, 0, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 2, @cinv4, 0, 0, 0, 0, 0, 0, 0, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 3, @cs4, 1, 0, 0, 1, 1, 1, 0, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 4, @as4, 1, 1, 1, 0, 0, 1, 0, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 5, @ed4, 1, 1, 1, 0, 1, 1, 0, @now, @now, 0);

-- ============================================================
-- SUBMISSION 5: PendingASM for asm5@bajaj.com (Rajasthan)
-- ============================================================
DECLARE @pkg5 UNIQUEIDENTIFIER = NEWID();
DECLARE @po5 UNIQUEIDENTIFIER = NEWID();
DECLARE @team5 UNIQUEIDENTIFIER = NEWID();
DECLARE @cinv5 UNIQUEIDENTIFIER = NEWID();
DECLARE @photo5 UNIQUEIDENTIFIER = NEWID();
DECLARE @cs5 UNIQUEIDENTIFIER = NEWID();
DECLARE @as5 UNIQUEIDENTIFIER = NEWID();
DECLARE @ed5 UNIQUEIDENTIFIER = NEWID();

INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, State, ActivityState, SubmissionNumber, AssignedCircleHeadUserId, AssignedRAUserId, VersionNumber, CurrentStep, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@pkg5, @agencyId, @agencyUserId, 4, 'Rajasthan', 'CIQ-TEST-00005', @asm5Id, NULL, 1, 0, DATEADD(HOUR,-4,@now), @now, 0);

INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, RemainingBalance, POStatus, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@po5, @pkg5, @agencyId, 'PO-TEST-RJ-001', '2026-03-01', 'Demo Agency', 550000, 550000, 'Open', 'po_rj001.pdf', 'seed://po-rj-001', 1048576, 'application/pdf', 0, 1, @now, @now, 0);

INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, DealershipAddress, State, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@team5, @pkg5, 'Rajasthan Campaign Q1', 'RJ-T01', '2026-03-01', '2026-03-18', 14, 'Bajaj Auto Jaipur', '55 MI Road, Jaipur 302001', 'Rajasthan', 1, @now, @now, 0);

INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cinv5, @team5, @pkg5, 'INV-RJ-2026-001', '2026-03-14', 'Demo Agency', '08AABCU9603R1ZQ', 466102, 83898, 550000, 'inv_rj001.pdf', 'seed://inv-rj-001', 524288, 'application/pdf', 0, @now, @now, 0);

INSERT INTO TeamPhotos (Id, TeamId, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, DisplayOrder, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@photo5, @team5, @pkg5, 'photo_rj001.jpg', 'seed://photo-rj-001', 2097152, 'image/jpeg', 0, 1, 1, @now, @now, 0);

INSERT INTO CostSummaries (Id, PackageId, TotalCost, PlaceOfSupply, NumberOfDays, NumberOfActivations, NumberOfTeams, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cs5, @pkg5, 550000, 'Rajasthan', 14, 9, 1, 'cost_rj001.xlsx', 'seed://cost-rj-001', 262144, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 0, 1, @now, @now, 0);

INSERT INTO ActivitySummaries (Id, PackageId, ActivityDescription, DealerName, TotalDays, TotalWorkingDays, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@as5, @pkg5, 'BTL activation at Bajaj Auto Jaipur — outdoor event', 'Bajaj Auto Jaipur', 18, 14, 'activity_rj001.xlsx', 'seed://activity-rj-001', 196608, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 0, 1, @now, @now, 0);

INSERT INTO EnquiryDocuments (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractedDataJson, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@ed5, @pkg5, 'enquiry_rj001.xlsx', 'seed://enquiry-rj-001', 327680, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  '{"totalRecords":95,"completeRecords":90,"incompleteRecords":5,"fields":["Name","Phone","Date","State","Model"]}',
  0, 1, @now, @now, 0);

INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg5, 89.0, 85.0, 82.0, 88.0, 80.0, 85.9, 0, @now, @now, 0);

INSERT INTO Recommendations (Id, PackageId, [Type], Evidence, ConfidenceScore, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg5, 1, 'Documents verified successfully. PO and invoice amounts align. Activity evidence is consistent. Approve recommended.', 85.9, @now, @now, 0);

INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 1, @po5, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 2, @cinv5, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 3, @cs5, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 4, @as5, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 5, @ed5, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);

-- ============================================================
-- SUBMISSION 6: PendingASM for asm6@bajaj.com (Uttar Pradesh)
-- ============================================================
DECLARE @pkg6 UNIQUEIDENTIFIER = NEWID();
DECLARE @po6 UNIQUEIDENTIFIER = NEWID();
DECLARE @team6 UNIQUEIDENTIFIER = NEWID();
DECLARE @cinv6 UNIQUEIDENTIFIER = NEWID();
DECLARE @photo6 UNIQUEIDENTIFIER = NEWID();
DECLARE @cs6 UNIQUEIDENTIFIER = NEWID();
DECLARE @as6 UNIQUEIDENTIFIER = NEWID();
DECLARE @ed6 UNIQUEIDENTIFIER = NEWID();

INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, State, ActivityState, SubmissionNumber, AssignedCircleHeadUserId, AssignedRAUserId, VersionNumber, CurrentStep, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@pkg6, @agencyId, @agencyUserId, 4, 'Uttar Pradesh', 'CIQ-TEST-00006', @asm6Id, NULL, 1, 0, DATEADD(HOUR,-6,@now), @now, 0);

INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, RemainingBalance, POStatus, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@po6, @pkg6, @agencyId, 'PO-TEST-UP-001', '2026-02-28', 'Demo Agency', 720000, 600000, 'PartiallyConsumed', 'po_up001.pdf', 'seed://po-up-001', 1048576, 'application/pdf', 0, 1, @now, @now, 0);

INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, DealershipAddress, State, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@team6, @pkg6, 'UP Campaign Q1', 'UP-T01', '2026-02-25', '2026-03-15', 15, 'Bajaj Auto Lucknow', '12 Hazratganj, Lucknow 226001', 'Uttar Pradesh', 1, @now, @now, 0);

INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cinv6, @team6, @pkg6, 'INV-UP-2026-001', '2026-03-10', 'Demo Agency', '09AABCU9603R1ZR', 610169, 109831, 720000, 'inv_up001.pdf', 'seed://inv-up-001', 524288, 'application/pdf', 0, @now, @now, 0);

INSERT INTO TeamPhotos (Id, TeamId, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, DisplayOrder, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@photo6, @team6, @pkg6, 'photo_up001.jpg', 'seed://photo-up-001', 2097152, 'image/jpeg', 0, 1, 1, @now, @now, 0);

INSERT INTO CostSummaries (Id, PackageId, TotalCost, PlaceOfSupply, NumberOfDays, NumberOfActivations, NumberOfTeams, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cs6, @pkg6, 720000, 'Uttar Pradesh', 15, 11, 1, 'cost_up001.xlsx', 'seed://cost-up-001', 262144, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 0, 1, @now, @now, 0);

INSERT INTO ActivitySummaries (Id, PackageId, ActivityDescription, DealerName, TotalDays, TotalWorkingDays, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@as6, @pkg6, 'BTL activation at Bajaj Auto Lucknow — dealer meet', 'Bajaj Auto Lucknow', 19, 15, 'activity_up001.xlsx', 'seed://activity-up-001', 196608, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 0, 1, @now, @now, 0);

INSERT INTO EnquiryDocuments (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractedDataJson, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@ed6, @pkg6, 'enquiry_up001.xlsx', 'seed://enquiry-up-001', 327680, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  '{"totalRecords":65,"completeRecords":58,"incompleteRecords":7,"fields":["Name","Phone","Date","State","Model"]}',
  0, 1, @now, @now, 0);

INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg6, 78.0, 72.0, 75.0, 65.0, 60.0, 72.6, 1, @now, @now, 0);

INSERT INTO Recommendations (Id, PackageId, [Type], Evidence, ConfidenceScore, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg6, 2, 'Minor discrepancies in cost summary line items. Activity dates partially outside PO validity. Manual review recommended.', 72.6, @now, @now, 0);

INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 1, @po6, 1, 1, 1, 1, 0, 1, 0, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 2, @cinv6, 1, 1, 1, 1, 0, 1, 0, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 3, @cs6, 1, 0, 1, 1, 1, 1, 0, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 4, @as6, 1, 1, 1, 0, 0, 1, 0, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 5, @ed6, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);

-- ============================================================
-- SUBMISSION 7: PendingRA for ra@bajaj.com (Maharashtra)
-- ============================================================
DECLARE @pkg7 UNIQUEIDENTIFIER = NEWID();
DECLARE @po7 UNIQUEIDENTIFIER = NEWID();
DECLARE @team7 UNIQUEIDENTIFIER = NEWID();
DECLARE @cinv7 UNIQUEIDENTIFIER = NEWID();
DECLARE @photo7 UNIQUEIDENTIFIER = NEWID();
DECLARE @cs7 UNIQUEIDENTIFIER = NEWID();
DECLARE @as7 UNIQUEIDENTIFIER = NEWID();
DECLARE @ed7 UNIQUEIDENTIFIER = NEWID();

INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, State, ActivityState, SubmissionNumber, AssignedCircleHeadUserId, AssignedRAUserId, VersionNumber, CurrentStep, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@pkg7, @agencyId, @agencyUserId, 6, 'Maharashtra', 'CIQ-TEST-00007', @asm1Id, @ra1Id, 1, 0, DATEADD(DAY,-2,@now), @now, 0);

INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, RemainingBalance, POStatus, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@po7, @pkg7, @agencyId, 'PO-TEST-MH-003', '2026-03-01', 'Demo Agency', 900000, 650000, 'PartiallyConsumed', 'po_mh003.pdf', 'seed://po-mh-003', 1048576, 'application/pdf', 0, 1, @now, @now, 0);

INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, DealershipAddress, State, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@team7, @pkg7, 'Maharashtra Campaign Q1-C', 'MH-T03', '2026-02-20', '2026-03-10', 15, 'Bajaj Auto Nagpur', '88 Sitabuldi, Nagpur 440012', 'Maharashtra', 1, @now, @now, 0);

INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cinv7, @team7, @pkg7, 'INV-MH-2026-003', '2026-03-08', 'Demo Agency', '27AABCU9603R1ZM', 762712, 137288, 900000, 'inv_mh003.pdf', 'seed://inv-mh-003', 524288, 'application/pdf', 0, @now, @now, 0);

INSERT INTO TeamPhotos (Id, TeamId, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, DisplayOrder, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@photo7, @team7, @pkg7, 'photo_mh003.jpg', 'seed://photo-mh-003', 2097152, 'image/jpeg', 0, 1, 1, @now, @now, 0);

INSERT INTO CostSummaries (Id, PackageId, TotalCost, PlaceOfSupply, NumberOfDays, NumberOfActivations, NumberOfTeams, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cs7, @pkg7, 900000, 'Maharashtra', 15, 12, 1, 'cost_mh003.xlsx', 'seed://cost-mh-003', 262144, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 0, 1, @now, @now, 0);

INSERT INTO ActivitySummaries (Id, PackageId, ActivityDescription, DealerName, TotalDays, TotalWorkingDays, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@as7, @pkg7, 'BTL activation at Bajaj Auto Nagpur — dealer event and test rides', 'Bajaj Auto Nagpur', 19, 15, 'activity_mh003.xlsx', 'seed://activity-mh-003', 196608, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 0, 1, @now, @now, 0);

INSERT INTO EnquiryDocuments (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractedDataJson, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@ed7, @pkg7, 'enquiry_mh003.xlsx', 'seed://enquiry-mh-003', 327680, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  '{"totalRecords":110,"completeRecords":105,"incompleteRecords":5,"fields":["Name","Phone","Date","State","Model"]}',
  0, 1, @now, @now, 0);

INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg7, 94.0, 90.0, 87.0, 91.0, 82.0, 90.1, 0, @now, @now, 0);

INSERT INTO Recommendations (Id, PackageId, [Type], Evidence, ConfidenceScore, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg7, 1, 'ASM approved. All cross-document validations passed. PO balance sufficient. Recommend final approval.', 90.1, @now, @now, 0);

INSERT INTO RequestApprovalHistory (Id, PackageId, ApproverId, ApproverRole, Action, Comments, ActionDate, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg7, @asm1Id, 2, 2, 'Verified all documents. Approved for RA review.', DATEADD(HOUR,-12,@now), 1, @now, @now, 0);

INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 1, @po7, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 2, @cinv7, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 3, @cs7, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 4, @as7, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 5, @ed7, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);

-- ============================================================
-- SUBMISSION 8: PendingRA for ra@bajaj.com (Gujarat)
-- ============================================================
DECLARE @pkg8 UNIQUEIDENTIFIER = NEWID();
DECLARE @po8 UNIQUEIDENTIFIER = NEWID();
DECLARE @team8 UNIQUEIDENTIFIER = NEWID();
DECLARE @cinv8 UNIQUEIDENTIFIER = NEWID();
DECLARE @photo8 UNIQUEIDENTIFIER = NEWID();
DECLARE @cs8 UNIQUEIDENTIFIER = NEWID();
DECLARE @as8 UNIQUEIDENTIFIER = NEWID();
DECLARE @ed8 UNIQUEIDENTIFIER = NEWID();

INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, State, ActivityState, SubmissionNumber, AssignedCircleHeadUserId, AssignedRAUserId, VersionNumber, CurrentStep, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@pkg8, @agencyId, @agencyUserId, 6, 'Gujarat', 'CIQ-TEST-00008', @asm2Id, @ra1Id, 1, 0, DATEADD(DAY,-1,@now), @now, 0);

INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, RemainingBalance, POStatus, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@po8, @pkg8, @agencyId, 'PO-TEST-GJ-002', '2026-02-25', 'Demo Agency', 410000, 410000, 'Open', 'po_gj002.pdf', 'seed://po-gj-002', 1048576, 'application/pdf', 0, 1, @now, @now, 0);

INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, DealershipAddress, State, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@team8, @pkg8, 'Gujarat Campaign Q1-B', 'GJ-T02', '2026-02-20', '2026-03-08', 13, 'Bajaj Auto Surat', '22 Ring Road, Surat 395002', 'Gujarat', 1, @now, @now, 0);

INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cinv8, @team8, @pkg8, 'INV-GJ-2026-002', '2026-03-05', 'Demo Agency', '24AABCU9603R1ZN', 347458, 62542, 410000, 'inv_gj002.pdf', 'seed://inv-gj-002', 524288, 'application/pdf', 0, @now, @now, 0);

INSERT INTO TeamPhotos (Id, TeamId, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, DisplayOrder, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@photo8, @team8, @pkg8, 'photo_gj002.jpg', 'seed://photo-gj-002', 2097152, 'image/jpeg', 0, 1, 1, @now, @now, 0);

INSERT INTO CostSummaries (Id, PackageId, TotalCost, PlaceOfSupply, NumberOfDays, NumberOfActivations, NumberOfTeams, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cs8, @pkg8, 410000, 'Gujarat', 13, 8, 1, 'cost_gj002.xlsx', 'seed://cost-gj-002', 262144, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 0, 1, @now, @now, 0);

INSERT INTO ActivitySummaries (Id, PackageId, ActivityDescription, DealerName, TotalDays, TotalWorkingDays, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@as8, @pkg8, 'BTL activation at Bajaj Auto Surat — showroom event', 'Bajaj Auto Surat', 17, 13, 'activity_gj002.xlsx', 'seed://activity-gj-002', 196608, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 0, 1, @now, @now, 0);

INSERT INTO EnquiryDocuments (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractedDataJson, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@ed8, @pkg8, 'enquiry_gj002.xlsx', 'seed://enquiry-gj-002', 327680, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  '{"totalRecords":78,"completeRecords":74,"incompleteRecords":4,"fields":["Name","Phone","Date","State","Model"]}',
  0, 1, @now, @now, 0);

INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg8, 88.0, 84.0, 80.0, 86.0, 75.0, 84.2, 0, @now, @now, 0);

INSERT INTO Recommendations (Id, PackageId, [Type], Evidence, ConfidenceScore, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg8, 1, 'ASM approved. Documents consistent. PO balance covers invoice. Approve recommended.', 84.2, @now, @now, 0);

INSERT INTO RequestApprovalHistory (Id, PackageId, ApproverId, ApproverRole, Action, Comments, ActionDate, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg8, @asm2Id, 2, 2, 'All checks passed. Forwarding to RA.', DATEADD(HOUR,-6,@now), 1, @now, @now, 0);

INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 1, @po8, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 2, @cinv8, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 3, @cs8, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 4, @as8, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 5, @ed8, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);

-- ============================================================
-- SUBMISSION 9: PendingRA for ra2@bajaj.com (Uttar Pradesh)
-- ============================================================
DECLARE @pkg9 UNIQUEIDENTIFIER = NEWID();
DECLARE @po9 UNIQUEIDENTIFIER = NEWID();
DECLARE @team9 UNIQUEIDENTIFIER = NEWID();
DECLARE @cinv9 UNIQUEIDENTIFIER = NEWID();
DECLARE @photo9 UNIQUEIDENTIFIER = NEWID();
DECLARE @cs9 UNIQUEIDENTIFIER = NEWID();
DECLARE @as9 UNIQUEIDENTIFIER = NEWID();
DECLARE @ed9 UNIQUEIDENTIFIER = NEWID();

INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, State, ActivityState, SubmissionNumber, AssignedCircleHeadUserId, AssignedRAUserId, VersionNumber, CurrentStep, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@pkg9, @agencyId, @agencyUserId, 6, 'Uttar Pradesh', 'CIQ-TEST-00009', @asm6Id, @ra2Id, 1, 0, DATEADD(DAY,-1,@now), @now, 0);

INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, RemainingBalance, POStatus, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@po9, @pkg9, @agencyId, 'PO-TEST-UP-002', '2026-03-02', 'Demo Agency', 530000, 530000, 'Open', 'po_up002.pdf', 'seed://po-up-002', 1048576, 'application/pdf', 0, 1, @now, @now, 0);

INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, DealershipAddress, State, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@team9, @pkg9, 'UP Campaign Q1-B', 'UP-T02', '2026-03-01', '2026-03-16', 12, 'Bajaj Auto Kanpur', '45 Mall Road, Kanpur 208001', 'Uttar Pradesh', 1, @now, @now, 0);

INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cinv9, @team9, @pkg9, 'INV-UP-2026-002', '2026-03-12', 'Demo Agency', '09AABCU9603R1ZR', 449153, 80847, 530000, 'inv_up002.pdf', 'seed://inv-up-002', 524288, 'application/pdf', 0, @now, @now, 0);

INSERT INTO TeamPhotos (Id, TeamId, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, DisplayOrder, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@photo9, @team9, @pkg9, 'photo_up002.jpg', 'seed://photo-up-002', 2097152, 'image/jpeg', 0, 1, 1, @now, @now, 0);

INSERT INTO CostSummaries (Id, PackageId, TotalCost, PlaceOfSupply, NumberOfDays, NumberOfActivations, NumberOfTeams, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cs9, @pkg9, 530000, 'Uttar Pradesh', 12, 7, 1, 'cost_up002.xlsx', 'seed://cost-up-002', 262144, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 0, 1, @now, @now, 0);

INSERT INTO ActivitySummaries (Id, PackageId, ActivityDescription, DealerName, TotalDays, TotalWorkingDays, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@as9, @pkg9, 'BTL activation at Bajaj Auto Kanpur — roadshow', 'Bajaj Auto Kanpur', 16, 12, 'activity_up002.xlsx', 'seed://activity-up-002', 196608, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 0, 1, @now, @now, 0);

INSERT INTO EnquiryDocuments (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractedDataJson, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@ed9, @pkg9, 'enquiry_up002.xlsx', 'seed://enquiry-up-002', 327680, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  '{"totalRecords":42,"completeRecords":35,"incompleteRecords":7,"fields":["Name","Phone","Date","State","Model"]}',
  0, 1, @now, @now, 0);

INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg9, 60.0, 55.0, 50.0, 58.0, 45.0, 55.1, 1, @now, @now, 0);

INSERT INTO Recommendations (Id, PackageId, [Type], Evidence, ConfidenceScore, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg9, 2, 'ASM approved with reservations. Cost summary has unreconciled line items. RA should verify before final approval.', 55.1, @now, @now, 0);

INSERT INTO RequestApprovalHistory (Id, PackageId, ApproverId, ApproverRole, Action, Comments, ActionDate, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg9, @asm6Id, 2, 2, 'Approved with note: cost summary needs RA verification.', DATEADD(HOUR,-8,@now), 1, @now, @now, 0);

INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 1, @po9, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 2, @cinv9, 1, 0, 1, 1, 1, 1, 0, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 3, @cs9, 1, 0, 0, 1, 1, 1, 0, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 4, @as9, 1, 1, 1, 0, 1, 1, 0, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 5, @ed9, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);

-- ============================================================
-- SUBMISSION 10: PendingRA for ra2@bajaj.com (West Bengal)
-- ============================================================
DECLARE @pkg10 UNIQUEIDENTIFIER = NEWID();
DECLARE @po10 UNIQUEIDENTIFIER = NEWID();
DECLARE @team10 UNIQUEIDENTIFIER = NEWID();
DECLARE @cinv10 UNIQUEIDENTIFIER = NEWID();
DECLARE @photo10 UNIQUEIDENTIFIER = NEWID();
DECLARE @cs10 UNIQUEIDENTIFIER = NEWID();
DECLARE @as10 UNIQUEIDENTIFIER = NEWID();
DECLARE @ed10 UNIQUEIDENTIFIER = NEWID();

INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, State, ActivityState, SubmissionNumber, AssignedCircleHeadUserId, AssignedRAUserId, VersionNumber, CurrentStep, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@pkg10, @agencyId, @agencyUserId, 6, 'West Bengal', 'CIQ-TEST-00010', @asm8Id, @ra2Id, 1, 0, DATEADD(HOUR,-18,@now), @now, 0);

INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, RemainingBalance, POStatus, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@po10, @pkg10, @agencyId, 'PO-TEST-WB-001', '2026-03-06', 'Demo Agency', 340000, 340000, 'Open', 'po_wb001.pdf', 'seed://po-wb-001', 1048576, 'application/pdf', 0, 1, @now, @now, 0);

INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, DealershipAddress, State, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@team10, @pkg10, 'West Bengal Campaign Q1', 'WB-T01', '2026-03-01', '2026-03-14', 10, 'Bajaj Auto Kolkata', '99 Park Street, Kolkata 700016', 'West Bengal', 1, @now, @now, 0);

INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cinv10, @team10, @pkg10, 'INV-WB-2026-001', '2026-03-10', 'Demo Agency', '19AABCU9603R1ZS', 288136, 51864, 340000, 'inv_wb001.pdf', 'seed://inv-wb-001', 524288, 'application/pdf', 0, @now, @now, 0);

INSERT INTO TeamPhotos (Id, TeamId, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, DisplayOrder, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@photo10, @team10, @pkg10, 'photo_wb001.jpg', 'seed://photo-wb-001', 2097152, 'image/jpeg', 0, 1, 1, @now, @now, 0);

INSERT INTO CostSummaries (Id, PackageId, TotalCost, PlaceOfSupply, NumberOfDays, NumberOfActivations, NumberOfTeams, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cs10, @pkg10, 340000, 'West Bengal', 10, 6, 1, 'cost_wb001.xlsx', 'seed://cost-wb-001', 262144, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 0, 1, @now, @now, 0);

INSERT INTO ActivitySummaries (Id, PackageId, ActivityDescription, DealerName, TotalDays, TotalWorkingDays, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@as10, @pkg10, 'BTL activation at Bajaj Auto Kolkata — dealer meet and greet', 'Bajaj Auto Kolkata', 14, 10, 'activity_wb001.xlsx', 'seed://activity-wb-001', 196608, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 0, 1, @now, @now, 0);

INSERT INTO EnquiryDocuments (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractedDataJson, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@ed10, @pkg10, 'enquiry_wb001.xlsx', 'seed://enquiry-wb-001', 327680, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  '{"totalRecords":68,"completeRecords":65,"incompleteRecords":3,"fields":["Name","Phone","Date","State","Model"]}',
  0, 1, @now, @now, 0);

INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg10, 91.0, 87.0, 83.0, 89.0, 80.0, 87.0, 0, @now, @now, 0);

INSERT INTO Recommendations (Id, PackageId, [Type], Evidence, ConfidenceScore, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg10, 1, 'ASM approved. All documents validated. Strong confidence across all categories. Final approval recommended.', 87.0, @now, @now, 0);

INSERT INTO RequestApprovalHistory (Id, PackageId, ApproverId, ApproverRole, Action, Comments, ActionDate, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg10, @asm8Id, 2, 2, 'All good. Approved for RA.', DATEADD(HOUR,-10,@now), 1, @now, @now, 0);

INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 1, @po10, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 2, @cinv10, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 3, @cs10, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 4, @as10, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 5, @ed10, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);

-- ============================================================
-- SUBMISSION 11: Approved — full lifecycle (Maharashtra)
-- ============================================================
DECLARE @pkg11 UNIQUEIDENTIFIER = NEWID();
DECLARE @po11 UNIQUEIDENTIFIER = NEWID();
DECLARE @team11 UNIQUEIDENTIFIER = NEWID();
DECLARE @cinv11 UNIQUEIDENTIFIER = NEWID();
DECLARE @photo11 UNIQUEIDENTIFIER = NEWID();
DECLARE @cs11 UNIQUEIDENTIFIER = NEWID();
DECLARE @as11 UNIQUEIDENTIFIER = NEWID();
DECLARE @ed11 UNIQUEIDENTIFIER = NEWID();

INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, State, ActivityState, SubmissionNumber, AssignedCircleHeadUserId, AssignedRAUserId, VersionNumber, CurrentStep, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@pkg11, @agencyId, @agencyUserId, 8, 'Maharashtra', 'CIQ-TEST-00011', @asm1Id, @ra1Id, 1, 0, DATEADD(DAY,-5,@now), @now, 0);

INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, RemainingBalance, POStatus, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@po11, @pkg11, @agencyId, 'PO-TEST-MH-004', '2026-02-15', 'Demo Agency', 1100000, 800000, 'PartiallyConsumed', 'po_mh004.pdf', 'seed://po-mh-004', 1048576, 'application/pdf', 0, 1, @now, @now, 0);

INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, DealershipAddress, State, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@team11, @pkg11, 'Maharashtra Campaign Q4', 'MH-T04', '2026-02-10', '2026-03-01', 16, 'Bajaj Auto Thane', '77 Ghodbunder Road, Thane 400607', 'Maharashtra', 1, @now, @now, 0);

INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cinv11, @team11, @pkg11, 'INV-MH-2026-004', '2026-02-28', 'Demo Agency', '27AABCU9603R1ZM', 932203, 167797, 1100000, 'inv_mh004.pdf', 'seed://inv-mh-004', 524288, 'application/pdf', 0, @now, @now, 0);

INSERT INTO TeamPhotos (Id, TeamId, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, DisplayOrder, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@photo11, @team11, @pkg11, 'photo_mh004.jpg', 'seed://photo-mh-004', 2097152, 'image/jpeg', 0, 1, 1, @now, @now, 0);

INSERT INTO CostSummaries (Id, PackageId, TotalCost, PlaceOfSupply, NumberOfDays, NumberOfActivations, NumberOfTeams, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cs11, @pkg11, 1100000, 'Maharashtra', 16, 14, 1, 'cost_mh004.xlsx', 'seed://cost-mh-004', 262144, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 0, 1, @now, @now, 0);

INSERT INTO ActivitySummaries (Id, PackageId, ActivityDescription, DealerName, TotalDays, TotalWorkingDays, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@as11, @pkg11, 'BTL activation at Bajaj Auto Thane — large-scale dealer event', 'Bajaj Auto Thane', 20, 16, 'activity_mh004.xlsx', 'seed://activity-mh-004', 196608, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 0, 1, @now, @now, 0);

INSERT INTO EnquiryDocuments (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractedDataJson, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@ed11, @pkg11, 'enquiry_mh004.xlsx', 'seed://enquiry-mh-004', 327680, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  '{"totalRecords":150,"completeRecords":148,"incompleteRecords":2,"fields":["Name","Phone","Date","State","Model"]}',
  0, 1, @now, @now, 0);

INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg11, 96.0, 94.0, 91.0, 93.0, 88.0, 93.3, 0, @now, @now, 0);

INSERT INTO Recommendations (Id, PackageId, [Type], Evidence, ConfidenceScore, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg11, 1, 'Excellent submission quality. All validations passed with high confidence.', 93.3, @now, @now, 0);

INSERT INTO RequestApprovalHistory (Id, PackageId, ApproverId, ApproverRole, Action, Comments, ActionDate, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg11, @asm1Id, 2, 2, 'Approved.', DATEADD(DAY,-4,@now), 1, @now, @now, 0);
INSERT INTO RequestApprovalHistory (Id, PackageId, ApproverId, ApproverRole, Action, Comments, ActionDate, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg11, @ra1Id, 3, 2, 'Final approval granted.', DATEADD(DAY,-3,@now), 1, @now, @now, 0);

INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 1, @po11, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 2, @cinv11, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 3, @cs11, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 4, @as11, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 5, @ed11, 1, 1, 1, 1, 1, 1, 1, @now, @now, 0);

-- ============================================================
-- SUBMISSION 12: ASMRejected (Gujarat)
-- ============================================================
DECLARE @pkg12 UNIQUEIDENTIFIER = NEWID();
DECLARE @po12 UNIQUEIDENTIFIER = NEWID();
DECLARE @team12 UNIQUEIDENTIFIER = NEWID();
DECLARE @cinv12 UNIQUEIDENTIFIER = NEWID();
DECLARE @photo12 UNIQUEIDENTIFIER = NEWID();
DECLARE @cs12 UNIQUEIDENTIFIER = NEWID();
DECLARE @as12 UNIQUEIDENTIFIER = NEWID();
DECLARE @ed12 UNIQUEIDENTIFIER = NEWID();

INSERT INTO DocumentPackages (Id, AgencyId, SubmittedByUserId, State, ActivityState, SubmissionNumber, AssignedCircleHeadUserId, AssignedRAUserId, VersionNumber, CurrentStep, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@pkg12, @agencyId, @agencyUserId, 5, 'Gujarat', 'CIQ-TEST-00012', @asm2Id, NULL, 1, 0, DATEADD(DAY,-3,@now), @now, 0);

INSERT INTO POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, RemainingBalance, POStatus, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@po12, @pkg12, @agencyId, 'PO-TEST-GJ-003', '2026-02-20', 'Demo Agency', 200000, 200000, 'Open', 'po_gj003.pdf', 'seed://po-gj-003', 1048576, 'application/pdf', 0, 1, @now, @now, 0);

INSERT INTO Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, DealershipAddress, State, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@team12, @pkg12, 'Gujarat Campaign Q1-C', 'GJ-T03', '2026-02-15', '2026-02-28', 10, 'Bajaj Auto Vadodara', '33 Alkapuri, Vadodara 390007', 'Gujarat', 1, @now, @now, 0);

INSERT INTO CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cinv12, @team12, @pkg12, 'INV-GJ-2026-003', '2026-02-25', 'Some Other Vendor', '24XXXXX9999R1ZZ', 169492, 30508, 200000, 'inv_gj003.pdf', 'seed://inv-gj-003', 524288, 'application/pdf', 1, @now, @now, 0);

INSERT INTO TeamPhotos (Id, TeamId, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, DisplayOrder, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@photo12, @team12, @pkg12, 'photo_gj003.jpg', 'seed://photo-gj-003', 2097152, 'image/jpeg', 1, 1, 1, @now, @now, 0);

INSERT INTO CostSummaries (Id, PackageId, TotalCost, PlaceOfSupply, NumberOfDays, NumberOfActivations, NumberOfTeams, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@cs12, @pkg12, 200000, 'Gujarat', 10, 4, 1, 'cost_gj003.xlsx', 'seed://cost-gj-003', 262144, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 1, 1, @now, @now, 0);

INSERT INTO ActivitySummaries (Id, PackageId, ActivityDescription, DealerName, TotalDays, TotalWorkingDays, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@as12, @pkg12, 'BTL activation at Bajaj Auto Vadodara — small event', 'Bajaj Auto Vadodara', 14, 10, 'activity_gj003.xlsx', 'seed://activity-gj-003', 196608, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 1, 1, @now, @now, 0);

INSERT INTO EnquiryDocuments (Id, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractedDataJson, IsFlaggedForReview, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (@ed12, @pkg12, 'enquiry_gj003.xlsx', 'seed://enquiry-gj-003', 327680, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  '{"totalRecords":20,"completeRecords":10,"incompleteRecords":10,"fields":["Name","Phone","Date","State","Model"]}',
  0, 1, @now, @now, 0);

INSERT INTO ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg12, 40.0, 35.0, 30.0, 25.0, 20.0, 32.5, 1, @now, @now, 0);

INSERT INTO Recommendations (Id, PackageId, [Type], Evidence, ConfidenceScore, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg12, 3, 'Invoice vendor name does not match PO. Photos appear to be stock images. Reject recommended.', 32.5, @now, @now, 0);

INSERT INTO RequestApprovalHistory (Id, PackageId, ApproverId, ApproverRole, Action, Comments, ActionDate, VersionNumber, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), @pkg12, @asm2Id, 2, 3, 'Rejected: invoice vendor mismatch and suspicious photos. Please resubmit with correct documents.', DATEADD(DAY,-2,@now), 1, @now, @now, 0);

INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 1, @po12, 0, 1, 0, 1, 1, 0, 0, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 2, @cinv12, 0, 0, 0, 0, 1, 0, 0, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 3, @cs12, 1, 0, 0, 0, 1, 1, 0, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 4, @as12, 1, 1, 1, 0, 0, 1, 0, @now, @now, 0);
INSERT INTO ValidationResults (Id, DocumentType, DocumentId, SapVerificationPassed, AmountConsistencyPassed, LineItemMatchingPassed, CompletenessCheckPassed, DateValidationPassed, VendorMatchingPassed, AllValidationsPassed, CreatedAt, UpdatedAt, IsDeleted)
VALUES (NEWID(), 5, @ed12, 1, 1, 1, 0, 1, 1, 0, @now, @now, 0);

-- ============================================================
-- SUMMARY
-- ============================================================
PRINT 'Successfully seeded 12 test submissions with COMPLETE data:';
PRINT '  Each submission includes: DocumentPackage, PO, Team, CampaignInvoice,';
PRINT '  TeamPhoto, CostSummary, ActivitySummary, EnquiryDocument,';
PRINT '  ConfidenceScore, Recommendation, and 5 ValidationResults.';
PRINT '';
PRINT '  6x PendingASM  (asm@, asm2@, asm3@, asm5@, asm6@ bajaj.com)';
PRINT '  4x PendingRA   (ra@, ra2@ bajaj.com)';
PRINT '  1x Approved    (full lifecycle)';
PRINT '  1x ASMRejected (agency can see rejection)';
PRINT '';
PRINT 'Test logins (password: Password123!):';
PRINT '  agency@bajaj.com  — sees all 12';
PRINT '  asm@bajaj.com     — 2 PendingASM (Maharashtra)';
PRINT '  asm2@bajaj.com    — 1 PendingASM (Gujarat)';
PRINT '  asm3@bajaj.com    — 1 PendingASM (Karnataka)';
PRINT '  asm5@bajaj.com    — 1 PendingASM (Rajasthan)';
PRINT '  asm6@bajaj.com    — 1 PendingASM (Uttar Pradesh)';
PRINT '  ra@bajaj.com      — 2 PendingRA (Maharashtra, Gujarat)';
PRINT '  ra2@bajaj.com     — 2 PendingRA (Uttar Pradesh, West Bengal)';
