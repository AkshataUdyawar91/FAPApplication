ALTER TABLE [DocumentPackages] ADD [EnquiryDocFileName] nvarchar(max) NULL;
ALTER TABLE [DocumentPackages] ADD [EnquiryDocBlobUrl] nvarchar(max) NULL;
ALTER TABLE [DocumentPackages] ADD [EnquiryDocContentType] nvarchar(max) NULL;
ALTER TABLE [DocumentPackages] ADD [EnquiryDocFileSizeBytes] bigint NULL;
ALTER TABLE [DocumentPackages] ADD [EnquiryDocExtractedDataJson] nvarchar(max) NULL;
ALTER TABLE [DocumentPackages] ADD [EnquiryDocExtractionConfidence] float NULL;
GO
