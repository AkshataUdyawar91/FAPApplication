-- =============================================
-- PART 4: SEED DATA & REFERENCE DATA
-- Target: Azure Synapse Analytics Dedicated SQL Pool
-- Database: Balsynwsdev | Prefix: BDP_
-- =============================================
-- Note: Synapse does not support multi-row INSERT VALUES.
--       Using INSERT INTO ... SELECT ... UNION ALL pattern.
-- =============================================

-- =============================================
-- SEED: Reference Data (StateGstMaster)
-- Note: GstCode removed; GstPercentage added (18% standard GST rate)
-- =============================================

INSERT INTO dbo.BDP_StateGstMasters (Id, StateCode, StateName, GstPercentage, IsActive, IsDeleted, CreatedAt)
SELECT NEWID(), 'JK', 'Jammu and Kashmir', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'HP', 'Himachal Pradesh', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'PB', 'Punjab', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'CH', 'Chandigarh', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'DL', 'Delhi', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'HR', 'Haryana', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'UP', 'Uttar Pradesh', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'UT', 'Uttarakhand', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'BH', 'Bihar', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'SK', 'Sikkim', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'MN', 'Manipur', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'ML', 'Meghalaya', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'MZ', 'Mizoram', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'TR', 'Tripura', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'AS', 'Assam', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'WB', 'West Bengal', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'JH', 'Jharkhand', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'OR', 'Odisha', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'CT', 'Chhattisgarh', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'MP', 'Madhya Pradesh', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'GJ', 'Gujarat', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'DD', 'Daman and Diu', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'DN', 'Dadra and Nagar Haveli', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'MH', 'Maharashtra', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'KA', 'Karnataka', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'GA', 'Goa', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'KL', 'Kerala', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'TN', 'Tamil Nadu', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'PY', 'Puducherry', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'AN', 'Andaman and Nicobar Islands', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'AP', 'Andhra Pradesh', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'AR', 'Arunachal Pradesh', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'TG', 'Telangana', 18.00, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'LD', 'Ladakh', 18.00, 1, 0, GETUTCDATE();

-- =============================================
-- SEED: HsnMaster
-- =============================================

INSERT INTO dbo.BDP_HsnMasters (Id, Code, Description, IsActive, IsDeleted, CreatedAt)
SELECT NEWID(), '8703', 'Motor cars and other motor vehicles', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '8704', 'Motor vehicles for the transport of goods', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '8711', 'Motorcycles and cycles', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '9406', 'Prefabricated buildings', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '9405', 'Lamps and lighting fittings', 1, 0, GETUTCDATE();

-- =============================================
-- SEED: CostMaster
-- =============================================

INSERT INTO dbo.BDP_CostMasters (Id, ElementName, ExpenseNature, IsActive, IsDeleted, CreatedAt)
SELECT NEWID(), 'POS - Standee', 'Fixed Cost', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'Promoter', 'Cost per Day', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'Branding Material', 'Fixed Cost', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'Transportation', 'Cost per Day', 1, 0, GETUTCDATE();

-- =============================================
-- SEED: CostMasterStateRate
-- =============================================

INSERT INTO dbo.BDP_CostMasterStateRates (Id, StateCode, ElementName, RateValue, RateType, IsActive, IsDeleted, CreatedAt)
SELECT NEWID(), 'Delhi', 'POS - Standee', 5000.00, 'Amount', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'Delhi', 'Promoter', 500.00, 'Amount', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'UP & UTT', 'POS - Standee', 4500.00, 'Amount', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'UP & UTT', 'Promoter', 450.00, 'Amount', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'Maharashtra', 'POS - Standee', 6000.00, 'Amount', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'Maharashtra', 'Promoter', 600.00, 'Amount', 1, 0, GETUTCDATE();

-- =============================================
-- SEED: Test Agencies
-- =============================================

DECLARE @AgencyId1 UNIQUEIDENTIFIER = NEWID();
DECLARE @AgencyId2 UNIQUEIDENTIFIER = NEWID();

INSERT INTO dbo.BDP_Agencies (Id, SupplierCode, SupplierName, IsDeleted, CreatedAt)
SELECT @AgencyId1, 'SUP001', 'Test Agency 1', 0, GETUTCDATE()
UNION ALL SELECT @AgencyId2, 'SUP002', 'Test Agency 2', 0, GETUTCDATE();

-- =============================================
-- SEED: Test Users
-- Role: 0=Agency, 1=CircleHead(ASM), 2=RA(HQ), 3=Admin
-- =============================================

DECLARE @UserId_Agency      UNIQUEIDENTIFIER = NEWID();
DECLARE @UserId_CircleHead  UNIQUEIDENTIFIER = NEWID();
DECLARE @UserId_RA          UNIQUEIDENTIFIER = NEWID();
DECLARE @UserId_Admin       UNIQUEIDENTIFIER = NEWID();

INSERT INTO dbo.BDP_Users (Id, Email, PasswordHash, FullName, Role, AgencyId, IsActive, IsDeleted, CreatedAt)
SELECT @UserId_Agency,     'agency@bajaj.com',     '$2a$11$placeholder_hash_agency',     'Agency User',      0, @AgencyId1, 1, 0, GETUTCDATE()
UNION ALL SELECT @UserId_CircleHead, 'circlehead@bajaj.com', '$2a$11$placeholder_hash_circlehead', 'Circle Head User', 1, NULL,       1, 0, GETUTCDATE()
UNION ALL SELECT @UserId_RA,         'ra@bajaj.com',         '$2a$11$placeholder_hash_ra',         'RA User',          2, NULL,       1, 0, GETUTCDATE()
UNION ALL SELECT @UserId_Admin,      'admin@bajaj.com',      '$2a$11$placeholder_hash_admin',      'Admin User',       3, NULL,       1, 0, GETUTCDATE();

-- =============================================
-- SEED: StateMappings
-- CircleHeadUserId = assigned CircleHead (ASM) for the state
-- RAUserId = assigned RA (HQ) for the state
-- =============================================

INSERT INTO dbo.BDP_StateMappings (Id, State, CircleHeadUserId, RAUserId, IsActive, IsDeleted, CreatedAt)
SELECT NEWID(), 'Delhi',       @UserId_CircleHead, @UserId_RA, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'Maharashtra', @UserId_CircleHead, @UserId_RA, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'Karnataka',   NULL,               @UserId_RA, 1, 0, GETUTCDATE();

-- =============================================
-- SEED: Dealers
-- =============================================

INSERT INTO dbo.BDP_Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt)
SELECT NEWID(), 'DLR001', 'Bajaj Dealership Delhi Central',  'Delhi',       'New Delhi', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'DLR002', 'Bajaj Dealership Mumbai West',   'Maharashtra', 'Mumbai',    1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'DLR003', 'Bajaj Dealership Bangalore North','Karnataka',   'Bangalore', 1, 0, GETUTCDATE();

-- =============================================
-- SEED: StateCities
-- =============================================

INSERT INTO dbo.BDP_StateCities (Id, State, City, IsActive, IsDeleted, CreatedAt)
SELECT NEWID(), 'Delhi',       'New Delhi',  1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'Maharashtra', 'Mumbai',     1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'Maharashtra', 'Pune',       1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'Karnataka',   'Bangalore',  1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'Karnataka',   'Mysore',     1, 0, GETUTCDATE();

-- =============================================
-- SEED: SubmissionSequences
-- =============================================

INSERT INTO dbo.BDP_SubmissionSequences (Year, LastNumber)
SELECT 2026, 0;

-- =============================================
-- SEED: Test Document Packages
-- =============================================

DECLARE @PackageId1 UNIQUEIDENTIFIER = NEWID();
DECLARE @PackageId2 UNIQUEIDENTIFIER = NEWID();

INSERT INTO dbo.BDP_DocumentPackages (Id, AgencyId, SubmittedByUserId, SubmissionNumber, VersionNumber, State, CurrentStep, AssignedCircleHeadUserId, AssignedRAUserId, IsDeleted, CreatedAt)
SELECT @PackageId1, @AgencyId1, @UserId_Agency, 'CIQ-2026-00001', 1, 0, 0, @UserId_CircleHead, NULL, 0, GETUTCDATE()
UNION ALL SELECT @PackageId2, @AgencyId2, @UserId_Agency, 'CIQ-2026-00002', 1, 0, 0, @UserId_CircleHead, NULL, 0, GETUTCDATE();

-- =============================================
-- SEED: Test POs
-- =============================================

DECLARE @POId1 UNIQUEIDENTIFIER = NEWID();
DECLARE @POId2 UNIQUEIDENTIFIER = NEWID();

INSERT INTO dbo.BDP_POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, VendorCode, TotalAmount, RemainingBalance, POStatus, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, IsDeleted, CreatedAt)
SELECT @POId1, @PackageId1, @AgencyId1, 'PO-2026-001', GETUTCDATE(), 'Vendor A', 'V001', 100000.00, 100000.00, 'Open', 'po_001.pdf', 'https://storage.blob.core.windows.net/documents/po_001.pdf', 1024000, 'application/pdf', 0, 1, 0, GETUTCDATE()
UNION ALL SELECT @POId2, @PackageId2, @AgencyId2, 'PO-2026-002', GETUTCDATE(), 'Vendor B', 'V002', 150000.00, 150000.00, 'Open', 'po_002.pdf', 'https://storage.blob.core.windows.net/documents/po_002.pdf', 1536000, 'application/pdf', 0, 1, 0, GETUTCDATE();

-- =============================================
-- SEED: Test Cost Summaries
-- =============================================

INSERT INTO dbo.BDP_CostSummaries (Id, PackageId, TotalCost, NumberOfActivations, NumberOfDays, NumberOfTeams, PlaceOfSupply, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, IsDeleted, CreatedAt)
SELECT NEWID(), @PackageId1, 100000.00, 1, 30, 2, 'Delhi',       'cost_summary_001.pdf', 'https://storage.blob.core.windows.net/documents/cost_summary_001.pdf', 512000, 'application/pdf', 0, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), @PackageId2, 150000.00, 1, 30, 3, 'Maharashtra', 'cost_summary_002.pdf', 'https://storage.blob.core.windows.net/documents/cost_summary_002.pdf', 768000, 'application/pdf', 0, 1, 0, GETUTCDATE();

-- =============================================
-- SEED: Test Activity Summaries
-- =============================================

INSERT INTO dbo.BDP_ActivitySummaries (Id, PackageId, ActivityDescription, DealerName, TotalDays, TotalWorkingDays, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, IsDeleted, CreatedAt)
SELECT NEWID(), @PackageId1, 'Campaign activity for Q1 2026', 'Bajaj Dealership Delhi Central',  30, 26, 'activity_001.pdf', 'https://storage.blob.core.windows.net/documents/activity_001.pdf', 256000, 'application/pdf', 0, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), @PackageId2, 'Campaign activity for Q2 2026', 'Bajaj Dealership Mumbai West',   30, 25, 'activity_002.pdf', 'https://storage.blob.core.windows.net/documents/activity_002.pdf', 384000, 'application/pdf', 0, 1, 0, GETUTCDATE();

-- =============================================
-- SEED: Test Invoices
-- =============================================

INSERT INTO dbo.BDP_Invoices (Id, PackageId, POId, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, IsDeleted, CreatedAt)
SELECT NEWID(), @PackageId1, @POId1, 'INV-001', GETUTCDATE(), 'Vendor A', '18AABCT1234H1Z0', 90000.00, 10000.00, 100000.00, 'invoice_001.pdf', 'https://storage.blob.core.windows.net/documents/invoice_001.pdf', 512000, 'application/pdf', 0, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), @PackageId2, @POId2, 'INV-002', GETUTCDATE(), 'Vendor B', '18AABCT5678H1Z0', 135000.00, 15000.00, 150000.00, 'invoice_002.pdf', 'https://storage.blob.core.windows.net/documents/invoice_002.pdf', 768000, 'application/pdf', 0, 1, 0, GETUTCDATE();

-- =============================================
-- SEED: Test Teams (no TeamsJson column)
-- =============================================

DECLARE @TeamId1 UNIQUEIDENTIFIER = NEWID();
DECLARE @TeamId2 UNIQUEIDENTIFIER = NEWID();

INSERT INTO dbo.BDP_Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, DealershipAddress, State, VersionNumber, IsDeleted, CreatedAt)
SELECT @TeamId1, @PackageId1, 'Campaign Q1 2026', 'TEAM-001', DATEADD(DAY, -30, GETUTCDATE()), GETUTCDATE(), 26, 'Bajaj Dealership Delhi Central', 'New Delhi, India', 'Delhi',       1, 0, GETUTCDATE()
UNION ALL SELECT @TeamId2, @PackageId2, 'Campaign Q2 2026', 'TEAM-002', DATEADD(DAY, -30, GETUTCDATE()), GETUTCDATE(), 25, 'Bajaj Dealership Mumbai West',   'Mumbai, India',   'Maharashtra', 1, 0, GETUTCDATE();

-- =============================================
-- SEED: Test Team Photos
-- =============================================

INSERT INTO dbo.BDP_TeamPhotos (Id, TeamId, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, Caption, IsFlaggedForReview, DisplayOrder, VersionNumber, IsDeleted, CreatedAt)
SELECT NEWID(), @TeamId1, @PackageId1, 'photo_001.jpg', 'https://storage.blob.core.windows.net/photos/photo_001.jpg', 2048000, 'image/jpeg', 'Campaign photo 1', 0, 1, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), @TeamId1, @PackageId1, 'photo_002.jpg', 'https://storage.blob.core.windows.net/photos/photo_002.jpg', 2048000, 'image/jpeg', 'Campaign photo 2', 0, 2, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), @TeamId2, @PackageId2, 'photo_003.jpg', 'https://storage.blob.core.windows.net/photos/photo_003.jpg', 2048000, 'image/jpeg', 'Campaign photo 3', 0, 1, 1, 0, GETUTCDATE();

-- =============================================
-- SEED: Test Confidence Scores
-- =============================================

INSERT INTO dbo.BDP_ConfidenceScores (Id, PackageId, PoConfidence, InvoiceConfidence, CostSummaryConfidence, ActivityConfidence, PhotosConfidence, OverallConfidence, IsFlaggedForReview, IsDeleted, CreatedAt)
SELECT NEWID(), @PackageId1, 95.50, 92.30, 88.75, 85.00, 90.00, 90.31, 0, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), @PackageId2, 93.00, 94.50, 91.25, 87.50, 92.00, 91.65, 0, 0, GETUTCDATE();

-- =============================================
-- SEED: Test Recommendations
-- =============================================

INSERT INTO dbo.BDP_Recommendations (Id, PackageId, Type, Evidence, ConfidenceScore, IsDeleted, CreatedAt)
SELECT NEWID(), @PackageId1, 0, 'All validation checks passed. High confidence scores across all documents. Recommend approval.', 90.31, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), @PackageId2, 0, 'All validation checks passed. High confidence scores across all documents. Recommend approval.', 91.65, 0, GETUTCDATE();

-- =============================================
-- SEED: Test Notifications
-- =============================================

INSERT INTO dbo.BDP_Notifications (Id, UserId, Type, Title, Message, IsRead, RelatedEntityId, IsDeleted, CreatedAt)
SELECT NEWID(), @UserId_Agency,     0, 'Submission Received',       'Your document package has been received and is being processed.', 0, @PackageId1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), @UserId_CircleHead, 0, 'New Submission for Review', 'A new document package is pending your review.',                  0, @PackageId1, 0, GETUTCDATE();

-- =============================================
-- SEED: Test Audit Logs (NewValuesJson only; OldValuesJson removed)
-- =============================================

INSERT INTO dbo.BDP_AuditLogs (Id, UserId, Action, EntityType, EntityId, IpAddress, UserAgent, IsDeleted, CreatedAt)
SELECT NEWID(), @UserId_Agency,     'SubmitPackage', 'DocumentPackage', @PackageId1, '192.168.1.1', 'Mozilla/5.0', 0, GETUTCDATE()
UNION ALL SELECT NEWID(), @UserId_CircleHead, 'ViewPackage',   'DocumentPackage', @PackageId1, '192.168.1.2', 'Mozilla/5.0', 0, GETUTCDATE();

-- =============================================
-- SEED: Test Conversations
-- =============================================

DECLARE @ConversationId1 UNIQUEIDENTIFIER = NEWID();

INSERT INTO dbo.BDP_Conversations (Id, UserId, LastMessageAt, IsDeleted, CreatedAt)
SELECT @ConversationId1, @UserId_Agency, GETUTCDATE(), 0, GETUTCDATE();

-- =============================================
-- SEED: Test Conversation Messages
-- =============================================

INSERT INTO dbo.BDP_ConversationMessages (Id, ConversationId, Role, Content, IsDeleted, CreatedAt)
SELECT NEWID(), @ConversationId1, 'user',      'What is the status of my submission?', 0, GETUTCDATE()
UNION ALL SELECT NEWID(), @ConversationId1, 'assistant', 'Your submission is currently under review. All validation checks have passed with high confidence scores.', 0, GETUTCDATE();

-- =============================================
-- COMPLETION
-- =============================================

PRINT 'Balsynwsdev - BDP_ prefixed schema seed data created successfully!';
PRINT 'Total Tables: 27 (all prefixed with BDP_)';
PRINT 'Removed: BDP_ASMs, BDP_CampaignInvoices';
PRINT 'Added: BDP_StateMappings, BDP_Dealers, BDP_StateCities, BDP_SubmissionSequences, BDP_EmailDeliveryLogs, BDP_POBalanceLogs, BDP_POSyncLogs';
