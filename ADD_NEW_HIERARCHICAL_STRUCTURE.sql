-- =============================================
-- Migration: Update Hierarchical Structure
-- Date: 2026-03-09
-- Purpose: Restructure to support:
--   - 1 PO per FAP
--   - 1 Enquiry Doc (Additional docs at PO level)
--   - Multiple Campaigns (Teams) per PO
--   - Multiple Invoices per Campaign
--   - Multiple Photos per Campaign
--   - 1 Cost Summary per Campaign
--   - 1 Activity Summary per Campaign
-- =============================================

USE BajajDocumentProcessing;
GO

-- ============================================
-- Step 1: Add Enquiry Document fields to DocumentPackages
-- ============================================
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'EnquiryDocFileName')
BEGIN
    ALTER TABLE DocumentPackages ADD EnquiryDocFileName NVARCHAR(512) NULL;
    PRINT 'Added EnquiryDocFileName to DocumentPackages';
END

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'EnquiryDocBlobUrl')
BEGIN
    ALTER TABLE DocumentPackages ADD EnquiryDocBlobUrl NVARCHAR(2048) NULL;
    PRINT 'Added EnquiryDocBlobUrl to DocumentPackages';
END

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'EnquiryDocContentType')
BEGIN
    ALTER TABLE DocumentPackages ADD EnquiryDocContentType NVARCHAR(100) NULL;
    PRINT 'Added EnquiryDocContentType to DocumentPackages';
END

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'EnquiryDocFileSizeBytes')
BEGIN
    ALTER TABLE DocumentPackages ADD EnquiryDocFileSizeBytes BIGINT NULL;
    PRINT 'Added EnquiryDocFileSizeBytes to DocumentPackages';
END

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'EnquiryDocExtractedDataJson')
BEGIN
    ALTER TABLE DocumentPackages ADD EnquiryDocExtractedDataJson NVARCHAR(MAX) NULL;
    PRINT 'Added EnquiryDocExtractedDataJson to DocumentPackages';
END

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'EnquiryDocExtractionConfidence')
BEGIN
    ALTER TABLE DocumentPackages ADD EnquiryDocExtractionConfidence FLOAT NULL;
    PRINT 'Added EnquiryDocExtractionConfidence to DocumentPackages';
END
GO

-- ============================================
-- Step 2: Update Campaigns table structure
-- Remove InvoiceId, add new fields
-- ============================================

-- Add TeamCode column
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Campaigns' AND COLUMN_NAME = 'TeamCode')
BEGIN
    ALTER TABLE Campaigns ADD TeamCode NVARCHAR(100) NULL;
    PRINT 'Added TeamCode to Campaigns';
END

-- Add Activity Summary fields
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Campaigns' AND COLUMN_NAME = 'ActivitySummaryFileName')
BEGIN
    ALTER TABLE Campaigns ADD ActivitySummaryFileName NVARCHAR(512) NULL;
    PRINT 'Added ActivitySummaryFileName to Campaigns';
END

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Campaigns' AND COLUMN_NAME = 'ActivitySummaryBlobUrl')
BEGIN
    ALTER TABLE Campaigns ADD ActivitySummaryBlobUrl NVARCHAR(2048) NULL;
    PRINT 'Added ActivitySummaryBlobUrl to Campaigns';
END

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Campaigns' AND COLUMN_NAME = 'ActivitySummaryContentType')
BEGIN
    ALTER TABLE Campaigns ADD ActivitySummaryContentType NVARCHAR(100) NULL;
    PRINT 'Added ActivitySummaryContentType to Campaigns';
END

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Campaigns' AND COLUMN_NAME = 'ActivitySummaryFileSizeBytes')
BEGIN
    ALTER TABLE Campaigns ADD ActivitySummaryFileSizeBytes BIGINT NULL;
    PRINT 'Added ActivitySummaryFileSizeBytes to Campaigns';
END

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Campaigns' AND COLUMN_NAME = 'ActivitySummaryExtractedDataJson')
BEGIN
    ALTER TABLE Campaigns ADD ActivitySummaryExtractedDataJson NVARCHAR(MAX) NULL;
    PRINT 'Added ActivitySummaryExtractedDataJson to Campaigns';
END

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Campaigns' AND COLUMN_NAME = 'ActivitySummaryExtractionConfidence')
BEGIN
    ALTER TABLE Campaigns ADD ActivitySummaryExtractionConfidence FLOAT NULL;
    PRINT 'Added ActivitySummaryExtractionConfidence to Campaigns';
END

-- Add Cost Summary content type and file size
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Campaigns' AND COLUMN_NAME = 'CostSummaryContentType')
BEGIN
    ALTER TABLE Campaigns ADD CostSummaryContentType NVARCHAR(100) NULL;
    PRINT 'Added CostSummaryContentType to Campaigns';
END

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Campaigns' AND COLUMN_NAME = 'CostSummaryFileSizeBytes')
BEGIN
    ALTER TABLE Campaigns ADD CostSummaryFileSizeBytes BIGINT NULL;
    PRINT 'Added CostSummaryFileSizeBytes to Campaigns';
END
GO

-- ============================================
-- Step 3: Create CampaignInvoices table
-- ============================================
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CampaignInvoices')
BEGIN
    CREATE TABLE CampaignInvoices (
        Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
        CampaignId UNIQUEIDENTIFIER NOT NULL,
        PackageId UNIQUEIDENTIFIER NOT NULL,
        InvoiceNumber NVARCHAR(100) NULL,
        InvoiceDate DATETIME2 NULL,
        VendorName NVARCHAR(500) NULL,
        GSTNumber NVARCHAR(50) NULL,
        SubTotal DECIMAL(18,2) NULL,
        TaxAmount DECIMAL(18,2) NULL,
        TotalAmount DECIMAL(18,2) NULL,
        FileName NVARCHAR(500) NOT NULL,
        BlobUrl NVARCHAR(2000) NOT NULL,
        FileSizeBytes BIGINT NOT NULL DEFAULT 0,
        ContentType NVARCHAR(100) NOT NULL,
        ExtractedDataJson NVARCHAR(MAX) NULL,
        ExtractionConfidence FLOAT NULL,
        IsFlaggedForReview BIT NOT NULL DEFAULT 0,
        IsDeleted BIT NOT NULL DEFAULT 0,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy NVARCHAR(256) NULL,
        UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        UpdatedBy NVARCHAR(256) NULL,
        
        CONSTRAINT FK_CampaignInvoices_Campaigns FOREIGN KEY (CampaignId) REFERENCES Campaigns(Id),
        CONSTRAINT FK_CampaignInvoices_DocumentPackages FOREIGN KEY (PackageId) REFERENCES DocumentPackages(Id)
    );
    
    CREATE INDEX IX_CampaignInvoices_CampaignId ON CampaignInvoices(CampaignId);
    CREATE INDEX IX_CampaignInvoices_PackageId ON CampaignInvoices(PackageId);
    CREATE INDEX IX_CampaignInvoices_InvoiceNumber ON CampaignInvoices(InvoiceNumber);
    
    PRINT 'Created CampaignInvoices table';
END
GO

-- ============================================
-- Step 4: Add indexes to Campaigns table
-- ============================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Campaigns_TeamCode' AND object_id = OBJECT_ID('Campaigns'))
BEGIN
    CREATE INDEX IX_Campaigns_TeamCode ON Campaigns(TeamCode);
    PRINT 'Created index IX_Campaigns_TeamCode';
END
GO

-- ============================================
-- Step 5: Make InvoiceId nullable in Campaigns (for backward compatibility)
-- ============================================
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Campaigns' AND COLUMN_NAME = 'InvoiceId' AND IS_NULLABLE = 'NO')
BEGIN
    -- Drop the foreign key constraint first if it exists
    DECLARE @constraintName NVARCHAR(200);
    SELECT @constraintName = name 
    FROM sys.foreign_keys 
    WHERE parent_object_id = OBJECT_ID('Campaigns') 
    AND referenced_object_id = OBJECT_ID('Invoices');
    
    IF @constraintName IS NOT NULL
    BEGIN
        EXEC('ALTER TABLE Campaigns DROP CONSTRAINT ' + @constraintName);
        PRINT 'Dropped foreign key constraint on Campaigns.InvoiceId';
    END
    
    -- Make InvoiceId nullable
    ALTER TABLE Campaigns ALTER COLUMN InvoiceId UNIQUEIDENTIFIER NULL;
    PRINT 'Made InvoiceId nullable in Campaigns';
END
GO

PRINT '';
PRINT '===========================================';
PRINT 'Migration completed successfully!';
PRINT '';
PRINT 'New Structure:';
PRINT '  DocumentPackage (FAP)';
PRINT '    ├── 1 PO Document (in Documents table)';
PRINT '    ├── 1 Enquiry Document (EnquiryDoc* fields)';
PRINT '    └── Multiple Campaigns (Teams)';
PRINT '        ├── Multiple Invoices (CampaignInvoices)';
PRINT '        ├── Multiple Photos (CampaignPhotos)';
PRINT '        ├── 1 Cost Summary (CostSummary* fields)';
PRINT '        └── 1 Activity Summary (ActivitySummary* fields)';
PRINT '===========================================';
GO
