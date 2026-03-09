-- =============================================
-- Script: Add Hierarchical Structure Tables
-- Purpose: Create Invoices, Campaigns, CampaignPhotos tables
-- Date: 2026-03-09
-- 
-- IMPORTANT: In SSMS, select "BajajDocumentProcessing" from the 
-- database dropdown BEFORE running this script!
-- =============================================

USE BajajDocumentProcessing;
GO

PRINT 'Current database: ' + DB_NAME();
PRINT '';

-- Check if DocumentPackages table exists
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'DocumentPackages')
BEGIN
    PRINT '*** ERROR: DocumentPackages table not found! ***';
    PRINT 'Make sure you selected BajajDocumentProcessing database.';
    RETURN;
END

PRINT 'DocumentPackages table found - proceeding...';

-- Step 1: Create Invoices table
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Invoices')
BEGIN
    CREATE TABLE Invoices (
        Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
        PackageId UNIQUEIDENTIFIER NOT NULL,
        PODocumentId UNIQUEIDENTIFIER NOT NULL,
        InvoiceNumber NVARCHAR(100) NULL,
        InvoiceDate DATETIME2 NULL,
        VendorName NVARCHAR(500) NULL,
        GSTNumber NVARCHAR(50) NULL,
        SubTotal DECIMAL(18,2) NULL,
        TaxAmount DECIMAL(18,2) NULL,
        TotalAmount DECIMAL(18,2) NULL,
        FileName NVARCHAR(512) NOT NULL,
        BlobUrl NVARCHAR(2048) NOT NULL,
        FileSizeBytes BIGINT NOT NULL DEFAULT 0,
        ContentType NVARCHAR(128) NOT NULL DEFAULT 'application/pdf',
        ExtractedDataJson NVARCHAR(MAX) NULL,
        ExtractionConfidence FLOAT NULL,
        IsFlaggedForReview BIT NOT NULL DEFAULT 0,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy NVARCHAR(256) NULL,
        UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        UpdatedBy NVARCHAR(256) NULL,
        IsDeleted BIT NOT NULL DEFAULT 0,
        CONSTRAINT FK_Invoices_DocumentPackages FOREIGN KEY (PackageId) REFERENCES DocumentPackages(Id) ON DELETE CASCADE,
        CONSTRAINT FK_Invoices_Documents FOREIGN KEY (PODocumentId) REFERENCES Documents(Id) ON DELETE NO ACTION
    );
    CREATE INDEX IX_Invoices_PackageId ON Invoices(PackageId);
    CREATE INDEX IX_Invoices_PODocumentId ON Invoices(PODocumentId);
    PRINT 'Created Invoices table';
END
ELSE
    PRINT 'Invoices table already exists';
GO

-- Step 2: Create Campaigns table
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Campaigns')
BEGIN
    CREATE TABLE Campaigns (
        Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
        InvoiceId UNIQUEIDENTIFIER NOT NULL,
        PackageId UNIQUEIDENTIFIER NOT NULL,
        CampaignName NVARCHAR(500) NULL,
        StartDate DATETIME2 NULL,
        EndDate DATETIME2 NULL,
        WorkingDays INT NULL,
        DealershipName NVARCHAR(500) NULL,
        DealershipAddress NVARCHAR(1000) NULL,
        GPSLocation NVARCHAR(100) NULL,
        State NVARCHAR(100) NULL,
        TotalCost DECIMAL(18,2) NULL,
        CostBreakdownJson NVARCHAR(MAX) NULL,
        TeamsJson NVARCHAR(MAX) NULL,
        CostSummaryFileName NVARCHAR(512) NULL,
        CostSummaryBlobUrl NVARCHAR(2048) NULL,
        CostSummaryExtractedDataJson NVARCHAR(MAX) NULL,
        CostSummaryExtractionConfidence FLOAT NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy NVARCHAR(256) NULL,
        UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        UpdatedBy NVARCHAR(256) NULL,
        IsDeleted BIT NOT NULL DEFAULT 0,
        CONSTRAINT FK_Campaigns_Invoices FOREIGN KEY (InvoiceId) REFERENCES Invoices(Id) ON DELETE CASCADE,
        CONSTRAINT FK_Campaigns_DocumentPackages FOREIGN KEY (PackageId) REFERENCES DocumentPackages(Id) ON DELETE NO ACTION
    );
    CREATE INDEX IX_Campaigns_InvoiceId ON Campaigns(InvoiceId);
    CREATE INDEX IX_Campaigns_PackageId ON Campaigns(PackageId);
    PRINT 'Created Campaigns table';
END
ELSE
    PRINT 'Campaigns table already exists';
GO

-- Step 3: Create CampaignPhotos table
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CampaignPhotos')
BEGIN
    CREATE TABLE CampaignPhotos (
        Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
        CampaignId UNIQUEIDENTIFIER NOT NULL,
        PackageId UNIQUEIDENTIFIER NOT NULL,
        FileName NVARCHAR(512) NOT NULL,
        BlobUrl NVARCHAR(2048) NOT NULL,
        FileSizeBytes BIGINT NOT NULL DEFAULT 0,
        ContentType NVARCHAR(128) NOT NULL DEFAULT 'image/jpeg',
        Caption NVARCHAR(1000) NULL,
        PhotoTimestamp DATETIME2 NULL,
        Latitude FLOAT NULL,
        Longitude FLOAT NULL,
        DeviceModel NVARCHAR(200) NULL,
        ExtractedMetadataJson NVARCHAR(MAX) NULL,
        ExtractionConfidence FLOAT NULL,
        IsFlaggedForReview BIT NOT NULL DEFAULT 0,
        DisplayOrder INT NOT NULL DEFAULT 0,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy NVARCHAR(256) NULL,
        UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        UpdatedBy NVARCHAR(256) NULL,
        IsDeleted BIT NOT NULL DEFAULT 0,
        CONSTRAINT FK_CampaignPhotos_Campaigns FOREIGN KEY (CampaignId) REFERENCES Campaigns(Id) ON DELETE CASCADE,
        CONSTRAINT FK_CampaignPhotos_DocumentPackages FOREIGN KEY (PackageId) REFERENCES DocumentPackages(Id) ON DELETE NO ACTION
    );
    CREATE INDEX IX_CampaignPhotos_CampaignId ON CampaignPhotos(CampaignId);
    CREATE INDEX IX_CampaignPhotos_PackageId ON CampaignPhotos(PackageId);
    PRINT 'Created CampaignPhotos table';
END
ELSE
    PRINT 'CampaignPhotos table already exists';
GO

-- Step 4: Update EF Migrations History
IF NOT EXISTS (SELECT 1 FROM [__EFMigrationsHistory] WHERE MigrationId = '20260309100000_AddHierarchicalStructure')
BEGIN
    INSERT INTO [__EFMigrationsHistory] (MigrationId, ProductVersion)
    VALUES ('20260309100000_AddHierarchicalStructure', '8.0.0');
    PRINT 'Added migration record';
END
GO

PRINT '';
PRINT '=== MIGRATION COMPLETE ===';
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME IN ('Invoices', 'Campaigns', 'CampaignPhotos');
