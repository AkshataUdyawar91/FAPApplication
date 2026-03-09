-- =============================================
-- Script: Add Hierarchical Structure Columns
-- Purpose: Add missing columns to DocumentPackages and create new tables for hierarchical structure
-- Date: 2026-03-09
-- =============================================

-- Add TeamsJson column to DocumentPackages if it doesn't exist
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'TeamsJson')
BEGIN
    ALTER TABLE DocumentPackages ADD TeamsJson NVARCHAR(MAX) NULL;
    PRINT 'Added TeamsJson column to DocumentPackages';
END
ELSE
BEGIN
    PRINT 'TeamsJson column already exists in DocumentPackages';
END
GO

-- Create Invoices table if it doesn't exist
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Invoices')
BEGIN
    CREATE TABLE Invoices (
        Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
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
        FileSizeBytes BIGINT NOT NULL,
        ContentType NVARCHAR(128) NOT NULL,
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

-- Create Campaigns table if it doesn't exist
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Campaigns')
BEGIN
    CREATE TABLE Campaigns (
        Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
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

-- Create CampaignPhotos table if it doesn't exist
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CampaignPhotos')
BEGIN
    CREATE TABLE CampaignPhotos (
        Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        CampaignId UNIQUEIDENTIFIER NOT NULL,
        PackageId UNIQUEIDENTIFIER NOT NULL,
        FileName NVARCHAR(512) NOT NULL,
        BlobUrl NVARCHAR(2048) NOT NULL,
        FileSizeBytes BIGINT NOT NULL,
        ContentType NVARCHAR(128) NOT NULL,
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

PRINT 'Hierarchical structure migration complete!';
