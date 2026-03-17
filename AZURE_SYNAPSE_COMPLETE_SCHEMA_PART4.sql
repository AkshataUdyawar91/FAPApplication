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
-- =============================================

INSERT INTO dbo.BDP_StateGstMasters (Id, GstCode, StateCode, StateName, IsActive, IsDeleted, CreatedAt)
SELECT NEWID(), '01', 'JK', 'Jammu and Kashmir', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '02', 'HP', 'Himachal Pradesh', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '03', 'PB', 'Punjab', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '04', 'CH', 'Chandigarh', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '05', 'DL', 'Delhi', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '06', 'HR', 'Haryana', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '07', 'UP', 'Uttar Pradesh', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '08', 'UT', 'Uttarakhand', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '09', 'BH', 'Bihar', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '10', 'SK', 'Sikkim', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '11', 'MN', 'Manipur', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '12', 'ML', 'Meghalaya', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '13', 'MZ', 'Mizoram', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '14', 'TR', 'Tripura', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '15', 'AS', 'Assam', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '16', 'WB', 'West Bengal', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '17', 'JH', 'Jharkhand', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '18', 'OR', 'Odisha', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '19', 'CT', 'Chhattisgarh', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '20', 'MP', 'Madhya Pradesh', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '21', 'GJ', 'Gujarat', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '22', 'DD', 'Daman and Diu', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '23', 'DN', 'Dadra and Nagar Haveli', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '24', 'MH', 'Maharashtra', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '25', 'KA', 'Karnataka', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '26', 'GA', 'Goa', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '27', 'KL', 'Kerala', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '28', 'TN', 'Tamil Nadu', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '29', 'PY', 'Puducherry', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '30', 'AN', 'Andaman and Nicobar Islands', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '31', 'AP', 'Andhra Pradesh', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '32', 'AR', 'Arunachal Pradesh', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '33', 'TG', 'Telangana', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '34', 'LD', 'Ladakh', 1, 0, GETUTCDATE();

-- SEED: HsnMaster
INSERT INTO dbo.BDP_HsnMasters (Id, Code, Description, IsActive, IsDeleted, CreatedAt)
SELECT NEWID(), '8703', 'Motor cars and other motor vehicles', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '8704', 'Motor vehicles for the transport of goods', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '8711', 'Motorcycles and cycles', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '9406', 'Prefabricated buildings', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), '9405', 'Lamps and lighting fittings', 1, 0, GETUTCDATE();

-- SEED: CostMaster
INSERT INTO dbo.BDP_CostMasters (Id, ElementName, ExpenseNature, IsActive, IsDeleted, CreatedAt)
SELECT NEWID(), 'POS - Standee', 'Fixed Cost', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'Promoter', 'Cost per Day', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'Branding Material', 'Fixed Cost', 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'Transportation', 'Cost per Day', 1, 0, GETUTCDATE();

-- SEED: CostMasterStateRate
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
-- =============================================

DECLARE @UserId_Agency UNIQUEIDENTIFIER = NEWID();
DECLARE @UserId_ASM UNIQUEIDENTIFIER = NEWID();
DECLARE @UserId_RA UNIQUEIDENTIFIER = NEWID();
DECLARE @UserId_Admin UNIQUEIDENTIFIER = NEWID();

INSERT INTO dbo.BDP_Users (Id, Email, PasswordHash, FullName, Role, AgencyId, IsActive, IsDeleted, CreatedAt)
SELECT @UserId_Agency, 'agency@bajaj.com', '$2a$11$8Yd8Yd8Yd8Yd8Yd8Yd8eYd8Yd8Yd8Yd8Yd8Yd8Yd8Yd8Yd8Yd8', 'Agency User', 0, @AgencyId1, 1, 0, GETUTCDATE()
UNION ALL SELECT @UserId_ASM, 'asm@bajaj.com', '$2a$11$8Yd8Yd8Yd8Yd8Yd8Yd8eYd8Yd8Yd8Yd8Yd8Yd8Yd8Yd8Yd8Yd8', 'ASM User', 1, NULL, 1, 0, GETUTCDATE()
UNION ALL SELECT @UserId_RA, 'ra@bajaj.com', '$2a$11$8Yd8Yd8Yd8Yd8Yd8Yd8eYd8Yd8Yd8Yd8Yd8Yd8Yd8Yd8Yd8Yd8', 'RA User', 2, NULL, 1, 0, GETUTCDATE()
UNION ALL SELECT @UserId_Admin, 'admin@bajaj.com', '$2a$11$8Yd8Yd8Yd8Yd8Yd8Yd8eYd8Yd8Yd8Yd8Yd8Yd8Yd8Yd8Yd8Yd8', 'Admin User', 3, NULL, 1, 0, GETUTCDATE();

-- =============================================
-- SEED: Test ASMs
-- =============================================

INSERT INTO dbo.BDP_ASMs (Id, Name, Location, UserId, IsDeleted, CreatedAt)
SELECT NEWID(), 'ASM 1 - North Region', 'Delhi', @UserId_ASM, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), 'ASM 2 - South Region', 'Bangalore', NULL, 0, GETUTCDATE();

-- =============================================
-- SEED: Test Document Packages
-- =============================================

DECLARE @PackageId1 UNIQUEIDENTIFIER = NEWID();
DECLARE @PackageId2 UNIQUEIDENTIFIER = NEWID();

INSERT INTO dbo.BDP_DocumentPackages (Id, AgencyId, SubmittedByUserId, VersionNumber, State, IsDeleted, CreatedAt)
SELECT @PackageId1, @AgencyId1, @UserId_Agency, 1, 0, 0, GETUTCDATE()
UNION ALL SELECT @PackageId2, @AgencyId2, @UserId_Agency, 1, 0, 0, GETUTCDATE();

-- =============================================
-- SEED: Test POs
-- =============================================

DECLARE @POId1 UNIQUEIDENTIFIER = NEWID();
DECLARE @POId2 UNIQUEIDENTIFIER = NEWID();

INSERT INTO dbo.BDP_POs (Id, PackageId, AgencyId, PONumber, PODate, VendorName, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, IsDeleted, CreatedAt)
SELECT @POId1, @PackageId1, @AgencyId1, 'PO-2024-001', GETUTCDATE(), 'Vendor A', 100000.00, 'po_001.pdf', 'https://storage.blob.core.windows.net/documents/po_001.pdf', 1024000, 'application/pdf', 0, 1, 0, GETUTCDATE()
UNION ALL SELECT @POId2, @PackageId2, @AgencyId2, 'PO-2024-002', GETUTCDATE(), 'Vendor B', 150000.00, 'po_002.pdf', 'https://storage.blob.core.windows.net/documents/po_002.pdf', 1536000, 'application/pdf', 0, 1, 0, GETUTCDATE();

-- =============================================
-- SEED: Test Cost Summaries
-- =============================================

INSERT INTO dbo.BDP_CostSummaries (Id, PackageId, TotalCost, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, IsDeleted, CreatedAt)
SELECT NEWID(), @PackageId1, 100000.00, 'cost_summary_001.pdf', 'https://storage.blob.core.windows.net/documents/cost_summary_001.pdf', 512000, 'application/pdf', 0, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), @PackageId2, 150000.00, 'cost_summary_002.pdf', 'https://storage.blob.core.windows.net/documents/cost_summary_002.pdf', 768000, 'application/pdf', 0, 1, 0, GETUTCDATE();

-- =============================================
-- SEED: Test Activity Summaries
-- =============================================

INSERT INTO dbo.BDP_ActivitySummaries (Id, PackageId, ActivityDescription, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, IsDeleted, CreatedAt)
SELECT NEWID(), @PackageId1, 'Campaign activity for Q1 2024', 'activity_001.pdf', 'https://storage.blob.core.windows.net/documents/activity_001.pdf', 256000, 'application/pdf', 0, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), @PackageId2, 'Campaign activity for Q2 2024', 'activity_002.pdf', 'https://storage.blob.core.windows.net/documents/activity_002.pdf', 384000, 'application/pdf', 0, 1, 0, GETUTCDATE();

-- =============================================
-- SEED: Test Invoices
-- =============================================

INSERT INTO dbo.BDP_Invoices (Id, PackageId, POId, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, VersionNumber, IsDeleted, CreatedAt)
SELECT NEWID(), @PackageId1, @POId1, 'INV-001', GETUTCDATE(), 'Vendor A', '18AABCT1234H1Z0', 90000.00, 10000.00, 100000.00, 'invoice_001.pdf', 'https://storage.blob.core.windows.net/documents/invoice_001.pdf', 512000, 'application/pdf', 0, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), @PackageId2, @POId2, 'INV-002', GETUTCDATE(), 'Vendor B', '18AABCT5678H1Z0', 135000.00, 15000.00, 150000.00, 'invoice_002.pdf', 'https://storage.blob.core.windows.net/documents/invoice_002.pdf', 768000, 'application/pdf', 0, 1, 0, GETUTCDATE();

-- =============================================
-- SEED: Test Teams
-- =============================================

DECLARE @TeamId1 UNIQUEIDENTIFIER = NEWID();
DECLARE @TeamId2 UNIQUEIDENTIFIER = NEWID();

INSERT INTO dbo.BDP_Teams (Id, PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, DealershipAddress, State, VersionNumber, IsDeleted, CreatedAt)
SELECT @TeamId1, @PackageId1, 'Campaign Q1 2024', 'TEAM-001', DATEADD(DAY, -30, GETUTCDATE()), GETUTCDATE(), 30, 'Bajaj Dealership Delhi', 'New Delhi, India', 'Delhi', 1, 0, GETUTCDATE()
UNION ALL SELECT @TeamId2, @PackageId2, 'Campaign Q2 2024', 'TEAM-002', DATEADD(DAY, -30, GETUTCDATE()), GETUTCDATE(), 30, 'Bajaj Dealership Mumbai', 'Mumbai, India', 'Maharashtra', 1, 0, GETUTCDATE();

-- =============================================
-- SEED: Test Team Photos
-- =============================================

INSERT INTO dbo.BDP_TeamPhotos (Id, TeamId, PackageId, FileName, BlobUrl, FileSizeBytes, ContentType, Caption, IsFlaggedForReview, DisplayOrder, VersionNumber, IsDeleted, CreatedAt)
SELECT NEWID(), @TeamId1, @PackageId1, 'photo_001.jpg', 'https://storage.blob.core.windows.net/photos/photo_001.jpg', 2048000, 'image/jpeg', 'Campaign photo 1', 0, 1, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), @TeamId1, @PackageId1, 'photo_002.jpg', 'https://storage.blob.core.windows.net/photos/photo_002.jpg', 2048000, 'image/jpeg', 'Campaign photo 2', 0, 2, 1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), @TeamId2, @PackageId2, 'photo_003.jpg', 'https://storage.blob.core.windows.net/photos/photo_003.jpg', 2048000, 'image/jpeg', 'Campaign photo 3', 0, 1, 1, 0, GETUTCDATE();

-- =============================================
-- SEED: Test Campaign Invoices
-- =============================================

INSERT INTO dbo.BDP_CampaignInvoices (Id, CampaignId, PackageId, InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount, FileName, BlobUrl, FileSizeBytes, ContentType, IsFlaggedForReview, IsDeleted, CreatedAt)
SELECT NEWID(), @TeamId1, @PackageId1, 'CINV-001', GETUTCDATE(), 'Vendor A', '18AABCT1234H1Z0', 45000.00, 5000.00, 50000.00, 'campaign_invoice_001.pdf', 'https://storage.blob.core.windows.net/documents/campaign_invoice_001.pdf', 256000, 'application/pdf', 0, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), @TeamId2, @PackageId2, 'CINV-002', GETUTCDATE(), 'Vendor B', '18AABCT5678H1Z0', 67500.00, 7500.00, 75000.00, 'campaign_invoice_002.pdf', 'https://storage.blob.core.windows.net/documents/campaign_invoice_002.pdf', 384000, 'application/pdf', 0, 0, GETUTCDATE();

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
SELECT NEWID(), @UserId_Agency, 0, 'Submission Received', 'Your document package has been received and is being processed.', 0, @PackageId1, 0, GETUTCDATE()
UNION ALL SELECT NEWID(), @UserId_ASM, 0, 'New Submission for Review', 'A new document package is pending your review.', 0, @PackageId1, 0, GETUTCDATE();

-- =============================================
-- SEED: Test Audit Logs
-- =============================================

INSERT INTO dbo.BDP_AuditLogs (Id, UserId, Action, EntityType, EntityId, IpAddress, UserAgent, IsDeleted, CreatedAt)
SELECT NEWID(), @UserId_Agency, 'SubmitPackage', 'DocumentPackage', @PackageId1, '192.168.1.1', 'Mozilla/5.0', 0, GETUTCDATE()
UNION ALL SELECT NEWID(), @UserId_ASM, 'ViewPackage', 'DocumentPackage', @PackageId1, '192.168.1.2', 'Mozilla/5.0', 0, GETUTCDATE();

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
SELECT NEWID(), @ConversationId1, 'user', 'What is the status of my submission?', 0, GETUTCDATE()
UNION ALL SELECT NEWID(), @ConversationId1, 'assistant', 'Your submission is currently under review. All validation checks have passed with high confidence scores.', 0, GETUTCDATE();

-- =============================================
-- COMPLETION
-- =============================================

PRINT 'Balsynwsdev - BDP_ prefixed schema seed data created successfully!';
PRINT 'Total Tables Seeded: 24 (all prefixed with BDP_)';
