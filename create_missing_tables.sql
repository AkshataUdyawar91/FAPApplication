-- Create missing tables for BajajFAP_Shubhankar

CREATE TABLE [Invoices] (
    [Id] uniqueidentifier NOT NULL,
    [PackageId] uniqueidentifier NOT NULL,
    [PODocumentId] uniqueidentifier NOT NULL,
    [InvoiceNumber] nvarchar(100) NULL,
    [InvoiceDate] datetime2 NULL,
    [VendorName] nvarchar(500) NULL,
    [GSTNumber] nvarchar(50) NULL,
    [SubTotal] decimal(18,2) NULL,
    [TaxAmount] decimal(18,2) NULL,
    [TotalAmount] decimal(18,2) NULL,
    [FileName] nvarchar(512) NOT NULL,
    [BlobUrl] nvarchar(2048) NOT NULL,
    [FileSizeBytes] bigint NOT NULL,
    [ContentType] nvarchar(128) NOT NULL,
    [ExtractedDataJson] nvarchar(max) NULL,
    [ExtractionConfidence] float NULL,
    [IsFlaggedForReview] bit NOT NULL DEFAULT 0,
    [CreatedAt] datetime2 NOT NULL,
    [UpdatedAt] datetime2 NOT NULL,
    [IsDeleted] bit NOT NULL DEFAULT 0,
    CONSTRAINT [PK_Invoices] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_Invoices_DocumentPackages_PackageId] FOREIGN KEY ([PackageId]) REFERENCES [DocumentPackages]([Id]) ON DELETE CASCADE,
    CONSTRAINT [FK_Invoices_Documents_PODocumentId] FOREIGN KEY ([PODocumentId]) REFERENCES [Documents]([Id])
);
GO

CREATE TABLE [Campaigns] (
    [Id] uniqueidentifier NOT NULL,
    [InvoiceId] uniqueidentifier NOT NULL,
    [PackageId] uniqueidentifier NOT NULL,
    [CampaignName] nvarchar(500) NULL,
    [StartDate] datetime2 NULL,
    [EndDate] datetime2 NULL,
    [WorkingDays] int NULL,
    [DealershipName] nvarchar(500) NULL,
    [DealershipAddress] nvarchar(1000) NULL,
    [GPSLocation] nvarchar(100) NULL,
    [State] nvarchar(100) NULL,
    [TotalCost] decimal(18,2) NULL,
    [CostBreakdownJson] nvarchar(max) NULL,
    [TeamsJson] nvarchar(max) NULL,
    [CostSummaryFileName] nvarchar(512) NULL,
    [CostSummaryBlobUrl] nvarchar(2048) NULL,
    [CostSummaryExtractedDataJson] nvarchar(max) NULL,
    [CostSummaryExtractionConfidence] float NULL,
    [CreatedAt] datetime2 NOT NULL,
    [UpdatedAt] datetime2 NOT NULL,
    [IsDeleted] bit NOT NULL DEFAULT 0,
    CONSTRAINT [PK_Campaigns] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_Campaigns_Invoices_InvoiceId] FOREIGN KEY ([InvoiceId]) REFERENCES [Invoices]([Id]) ON DELETE CASCADE,
    CONSTRAINT [FK_Campaigns_DocumentPackages_PackageId] FOREIGN KEY ([PackageId]) REFERENCES [DocumentPackages]([Id])
);
GO

CREATE TABLE [CampaignPhotos] (
    [Id] uniqueidentifier NOT NULL,
    [CampaignId] uniqueidentifier NOT NULL,
    [PackageId] uniqueidentifier NOT NULL,
    [FileName] nvarchar(512) NOT NULL,
    [BlobUrl] nvarchar(2048) NOT NULL,
    [FileSizeBytes] bigint NOT NULL,
    [ContentType] nvarchar(128) NOT NULL,
    [Caption] nvarchar(1000) NULL,
    [PhotoTimestamp] datetime2 NULL,
    [Latitude] float NULL,
    [Longitude] float NULL,
    [DeviceModel] nvarchar(200) NULL,
    [ExtractedMetadataJson] nvarchar(max) NULL,
    [ExtractionConfidence] float NULL,
    [IsFlaggedForReview] bit NOT NULL DEFAULT 0,
    [DisplayOrder] int NOT NULL DEFAULT 0,
    [CreatedAt] datetime2 NOT NULL,
    [UpdatedAt] datetime2 NOT NULL,
    [IsDeleted] bit NOT NULL DEFAULT 0,
    CONSTRAINT [PK_CampaignPhotos] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_CampaignPhotos_Campaigns_CampaignId] FOREIGN KEY ([CampaignId]) REFERENCES [Campaigns]([Id]) ON DELETE CASCADE,
    CONSTRAINT [FK_CampaignPhotos_DocumentPackages_PackageId] FOREIGN KEY ([PackageId]) REFERENCES [DocumentPackages]([Id])
);
GO

CREATE TABLE [CampaignInvoices] (
    [Id] uniqueidentifier NOT NULL,
    [CampaignId] uniqueidentifier NOT NULL,
    [PackageId] uniqueidentifier NOT NULL,
    [InvoiceNumber] nvarchar(100) NULL,
    [InvoiceDate] datetime2 NULL,
    [VendorName] nvarchar(500) NULL,
    [GSTNumber] nvarchar(50) NULL,
    [SubTotal] decimal(18,2) NULL,
    [TaxAmount] decimal(18,2) NULL,
    [TotalAmount] decimal(18,2) NULL,
    [FileName] nvarchar(500) NOT NULL,
    [BlobUrl] nvarchar(2000) NOT NULL,
    [FileSizeBytes] bigint NOT NULL,
    [ContentType] nvarchar(100) NOT NULL,
    [ExtractedDataJson] nvarchar(max) NULL,
    [ExtractionConfidence] float NULL,
    [IsFlaggedForReview] bit NOT NULL DEFAULT 0,
    [CreatedAt] datetime2 NOT NULL,
    [UpdatedAt] datetime2 NULL,
    [CreatedBy] nvarchar(max) NULL,
    [UpdatedBy] nvarchar(max) NULL,
    [IsDeleted] bit NOT NULL DEFAULT 0,
    CONSTRAINT [PK_CampaignInvoices] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_CampaignInvoices_Campaigns_CampaignId] FOREIGN KEY ([CampaignId]) REFERENCES [Campaigns]([Id]),
    CONSTRAINT [FK_CampaignInvoices_DocumentPackages_PackageId] FOREIGN KEY ([PackageId]) REFERENCES [DocumentPackages]([Id])
);
GO

-- Also add the 4th migration to history
INSERT INTO __EFMigrationsHistory (MigrationId, ProductVersion) VALUES 
('20260309100000_AddHierarchicalStructure', '8.0.0');
GO

-- Create indexes
CREATE INDEX IX_Invoices_PackageId ON [Invoices]([PackageId]);
CREATE INDEX IX_Invoices_PODocumentId ON [Invoices]([PODocumentId]);
CREATE INDEX IX_Invoices_InvoiceNumber ON [Invoices]([InvoiceNumber]);
CREATE INDEX IX_Campaigns_InvoiceId ON [Campaigns]([InvoiceId]);
CREATE INDEX IX_Campaigns_PackageId ON [Campaigns]([PackageId]);
CREATE INDEX IX_Campaigns_State ON [Campaigns]([State]);
CREATE INDEX IX_CampaignPhotos_CampaignId ON [CampaignPhotos]([CampaignId]);
CREATE INDEX IX_CampaignPhotos_PackageId ON [CampaignPhotos]([PackageId]);
CREATE INDEX IX_CampaignInvoices_CampaignId ON [CampaignInvoices]([CampaignId]);
CREATE INDEX IX_CampaignInvoices_PackageId ON [CampaignInvoices]([PackageId]);
CREATE INDEX IX_CampaignInvoices_InvoiceNumber ON [CampaignInvoices]([InvoiceNumber]);
GO
