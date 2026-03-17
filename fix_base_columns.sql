-- Add missing BaseEntity columns to Invoices
ALTER TABLE [Invoices] ADD [CreatedBy] nvarchar(max) NULL;
ALTER TABLE [Invoices] ADD [UpdatedBy] nvarchar(max) NULL;
ALTER TABLE [Invoices] ALTER COLUMN [UpdatedAt] datetime2 NULL;
GO

-- Add missing BaseEntity columns to Campaigns
ALTER TABLE [Campaigns] ADD [CreatedBy] nvarchar(max) NULL;
ALTER TABLE [Campaigns] ADD [UpdatedBy] nvarchar(max) NULL;
ALTER TABLE [Campaigns] ALTER COLUMN [UpdatedAt] datetime2 NULL;
GO

-- Add missing BaseEntity columns to CampaignPhotos
ALTER TABLE [CampaignPhotos] ADD [CreatedBy] nvarchar(max) NULL;
ALTER TABLE [CampaignPhotos] ADD [UpdatedBy] nvarchar(max) NULL;
ALTER TABLE [CampaignPhotos] ALTER COLUMN [UpdatedAt] datetime2 NULL;
GO
