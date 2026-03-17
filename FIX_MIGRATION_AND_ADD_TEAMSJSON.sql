-- =============================================
-- Script: Fix Migration History and Add TeamsJson
-- Purpose: Mark migrations as applied and add missing TeamsJson column
-- Date: 2026-03-09
-- =============================================

-- Step 1: Insert missing migration records into __EFMigrationsHistory
-- This tells EF Core that these migrations have already been applied

IF NOT EXISTS (SELECT 1 FROM __EFMigrationsHistory WHERE MigrationId = '20260306082019_AddResubmissionCounts')
BEGIN
    INSERT INTO __EFMigrationsHistory (MigrationId, ProductVersion)
    VALUES ('20260306082019_AddResubmissionCounts', '8.0.0');
    PRINT 'Marked AddResubmissionCounts migration as applied';
END
ELSE
BEGIN
    PRINT 'AddResubmissionCounts migration already in history';
END

IF NOT EXISTS (SELECT 1 FROM __EFMigrationsHistory WHERE MigrationId = '20260309100000_AddHierarchicalStructure')
BEGIN
    INSERT INTO __EFMigrationsHistory (MigrationId, ProductVersion)
    VALUES ('20260309100000_AddHierarchicalStructure', '8.0.0');
    PRINT 'Marked AddHierarchicalStructure migration as applied';
END
ELSE
BEGIN
    PRINT 'AddHierarchicalStructure migration already in history';
END
GO

-- Step 2: Add TeamsJson column to DocumentPackages if it doesn't exist
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'TeamsJson')
BEGIN
    ALTER TABLE DocumentPackages ADD TeamsJson NVARCHAR(MAX) NULL;
    PRINT 'Added TeamsJson column to DocumentPackages';
END
ELSE
BEGIN
    PRINT 'TeamsJson column already exists';
END
GO

-- Step 3: Create Invoices table if it doesn't exist
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
    CREATE INDEX IX_Invoices_InvoiceNumber ON Invoices(InvoiceNumber);
    
    PRINT 'Created Invoices table';
END
ELSE
BEGIN
    PRINT 'Invoices table already exists';
END
GO

-- Step 4: Create Campaigns table if it doesn't exist
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
    CREATE INDEX IX_Campaigns_State ON Campaigns(State);
    CREATE INDEX IX_Campaigns_CampaignName ON Campaigns(CampaignName);
    
    PRINT 'Created Campaigns table';
END
ELSE
BEGIN
    PRINT 'Campaigns table already exists';
END
GO

-- Step 5: Create CampaignPhotos table if it doesn't exist
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
    CREATE INDEX IX_CampaignPhotos_PhotoTimestamp ON CampaignPhotos(PhotoTimestamp);
    
    PRINT 'Created CampaignPhotos table';
END
ELSE
BEGIN
    PRINT 'CampaignPhotos table already exists';
END
GO

PRINT '';
PRINT '=== Migration fix complete! ===';
PRINT 'You can now run the application.';
