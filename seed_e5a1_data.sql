-- Seed Cost Summary and Activity Summary for E5A1C8F2-3333-4000-A000-000000000003
IF NOT EXISTS (SELECT 1 FROM CostSummaries WHERE PackageId = 'E5A1C8F2-3333-4000-A000-000000000003')
BEGIN
    INSERT INTO CostSummaries (Id, PackageId, TotalCost, PlaceOfSupply, NumberOfDays, NumberOfActivations, NumberOfTeams,
        ElementWiseCostsJson, ElementWiseQuantityJson, FileName, BlobUrl, FileSizeBytes, ContentType,
        IsFlaggedForReview, VersionNumber, IsDeleted, CreatedAt, UpdatedAt)
    VALUES (
        NEWID(), 'E5A1C8F2-3333-4000-A000-000000000003', 180000, N'Tamil Nadu', 30, 1, 2,
        N'[{"Element":"Banner","Amount":4000},{"Element":"Flyers","Amount":2000},{"Element":"Refreshments","Amount":5000}]',
        N'[{"Element":"Banner","Qty":6},{"Element":"Flyers","Qty":1000},{"Element":"Refreshments","Qty":100}]',
        N'cost_summary_e5a1.pdf', N'https://placeholder.blob.core.windows.net/docs/cs_e5a1.pdf', 92160, N'application/pdf',
        0, 1, 0, GETUTCDATE(), GETUTCDATE()
    );
    PRINT 'Inserted CostSummary for E5A1C8F2';
END;

IF NOT EXISTS (SELECT 1 FROM ActivitySummaries WHERE PackageId = 'E5A1C8F2-3333-4000-A000-000000000003')
BEGIN
    INSERT INTO ActivitySummaries (Id, PackageId, ActivityDescription, FileName, BlobUrl, FileSizeBytes, ContentType,
        DealerName, TotalDays, TotalWorkingDays, ExtractedDataJson,
        IsFlaggedForReview, VersionNumber, IsDeleted, CreatedAt, UpdatedAt)
    VALUES (
        NEWID(), 'E5A1C8F2-3333-4000-A000-000000000003', N'Campaign at Chennai showroom',
        N'activity_summary_e5a1.pdf', N'https://placeholder.blob.core.windows.net/docs/as_e5a1.pdf', 81920, N'application/pdf',
        N'Pinnacle Chennai Motors', 28, 22,
        N'{"Rows":[{"SNo":1,"DealerName":"Pinnacle Chennai Motors","Location":"Chennai","To":"2/10/2025","From":"3/10/2025","Day":28,"WorkingDay":22,"Team":"T1"}]}',
        0, 1, 0, GETUTCDATE(), GETUTCDATE()
    );
    PRINT 'Inserted ActivitySummary for E5A1C8F2';
END;
