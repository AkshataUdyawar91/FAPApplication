-- =============================================
-- Seed Cost Summary and Activity Summary data for ALL PendingASM packages
-- Purpose: Populate typed columns so review details card validations pass
-- Date: 2026-03-17
-- =============================================

-- Package: C1000006-0000-0000-0000-000000000001 (Bajaj Seed Agency)
-- CostSummary: F1000006-0000-0000-0000-000000000001
UPDATE CostSummaries SET
    PlaceOfSupply = N'Maharashtra',
    NumberOfDays = 60,
    NumberOfActivations = 2,
    NumberOfTeams = 3,
    ElementWiseCostsJson = N'[{"Element":"Vehicle Branding","Amount":12000},{"Element":"Canopy Setup","Amount":8000},{"Element":"Manpower","Amount":15000}]',
    ElementWiseQuantityJson = N'[{"Element":"Vehicle Branding","Qty":3},{"Element":"Canopy Setup","Qty":2},{"Element":"Manpower","Qty":5}]',
    TotalCost = 350000
WHERE Id = 'F1000006-0000-0000-0000-000000000001';

-- ActivitySummary: 91000006-0000-0000-0000-000000000001
UPDATE ActivitySummaries SET
    DealerName = N'Bajaj Seed Dealers',
    TotalDays = 45,
    TotalWorkingDays = 38,
    ExtractedDataJson = N'{"Rows":[{"SNo":1,"DealerName":"Bajaj Seed Dealers","Location":"Pune","To":"3/1/2025","From":"4/15/2025","Day":45,"WorkingDay":38,"Team":"T1"}]}'
WHERE Id = '91000006-0000-0000-0000-000000000001';

-- Package: D1000001-AAAA-BBBB-CCCC-000000000001 (Pinnacle Advertising)
-- This package has NO CostSummary or ActivitySummary rows — need to INSERT
IF NOT EXISTS (SELECT 1 FROM CostSummaries WHERE PackageId = 'D1000001-AAAA-BBBB-CCCC-000000000001')
BEGIN
    INSERT INTO CostSummaries (Id, PackageId, TotalCost, PlaceOfSupply, NumberOfDays, NumberOfActivations, NumberOfTeams,
        ElementWiseCostsJson, ElementWiseQuantityJson, FileName, BlobUrl, FileSizeBytes, ContentType,
        IsFlaggedForReview, VersionNumber, IsDeleted, CreatedAt, UpdatedAt)
    VALUES (
        NEWID(), 'D1000001-AAAA-BBBB-CCCC-000000000001', 280000, N'Gujarat', 45, 1, 2,
        N'[{"Element":"Standee","Amount":5000},{"Element":"Pamphlets","Amount":3000},{"Element":"Manpower","Amount":12000}]',
        N'[{"Element":"Standee","Qty":4},{"Element":"Pamphlets","Qty":500},{"Element":"Manpower","Qty":3}]',
        N'cost_summary_pinnacle.pdf', N'https://placeholder.blob.core.windows.net/docs/cs1.pdf', 102400, N'application/pdf',
        0, 1, 0, GETUTCDATE(), GETUTCDATE()
    );
END;

IF NOT EXISTS (SELECT 1 FROM ActivitySummaries WHERE PackageId = 'D1000001-AAAA-BBBB-CCCC-000000000001')
BEGIN
    INSERT INTO ActivitySummaries (Id, PackageId, ActivityDescription, FileName, BlobUrl, FileSizeBytes, ContentType,
        DealerName, TotalDays, TotalWorkingDays, ExtractedDataJson,
        IsFlaggedForReview, VersionNumber, IsDeleted, CreatedAt, UpdatedAt)
    VALUES (
        NEWID(), 'D1000001-AAAA-BBBB-CCCC-000000000001', N'Field activity at Ahmedabad dealership',
        N'activity_summary_pinnacle.pdf', N'https://placeholder.blob.core.windows.net/docs/as1.pdf', 81920, N'application/pdf',
        N'Pinnacle Motors Ahmedabad', 30, 25,
        N'{"Rows":[{"SNo":1,"DealerName":"Pinnacle Motors Ahmedabad","Location":"Ahmedabad","To":"2/1/2025","From":"3/2/2025","Day":30,"WorkingDay":25,"Team":"T1"}]}',
        0, 1, 0, GETUTCDATE(), GETUTCDATE()
    );
END;

-- Package: D2000002-AAAA-BBBB-CCCC-000000000002 (Horizon Media Solutions)
IF NOT EXISTS (SELECT 1 FROM CostSummaries WHERE PackageId = 'D2000002-AAAA-BBBB-CCCC-000000000002')
BEGIN
    INSERT INTO CostSummaries (Id, PackageId, TotalCost, PlaceOfSupply, NumberOfDays, NumberOfActivations, NumberOfTeams,
        ElementWiseCostsJson, ElementWiseQuantityJson, FileName, BlobUrl, FileSizeBytes, ContentType,
        IsFlaggedForReview, VersionNumber, IsDeleted, CreatedAt, UpdatedAt)
    VALUES (
        NEWID(), 'D2000002-AAAA-BBBB-CCCC-000000000002', 520000, N'Karnataka', 75, 3, 4,
        N'[{"Element":"LED Display","Amount":25000},{"Element":"Sound System","Amount":15000},{"Element":"Tent Setup","Amount":20000}]',
        N'[{"Element":"LED Display","Qty":2},{"Element":"Sound System","Qty":1},{"Element":"Tent Setup","Qty":3}]',
        N'cost_summary_horizon.pdf', N'https://placeholder.blob.core.windows.net/docs/cs2.pdf', 112640, N'application/pdf',
        0, 1, 0, GETUTCDATE(), GETUTCDATE()
    );
END;

IF NOT EXISTS (SELECT 1 FROM ActivitySummaries WHERE PackageId = 'D2000002-AAAA-BBBB-CCCC-000000000002')
BEGIN
    INSERT INTO ActivitySummaries (Id, PackageId, ActivityDescription, FileName, BlobUrl, FileSizeBytes, ContentType,
        DealerName, TotalDays, TotalWorkingDays, ExtractedDataJson,
        IsFlaggedForReview, VersionNumber, IsDeleted, CreatedAt, UpdatedAt)
    VALUES (
        NEWID(), 'D2000002-AAAA-BBBB-CCCC-000000000002', N'Campaign at Bangalore showroom',
        N'activity_summary_horizon.pdf', N'https://placeholder.blob.core.windows.net/docs/as2.pdf', 92160, N'application/pdf',
        N'Horizon Bangalore Showroom', 60, 52,
        N'{"Rows":[{"SNo":1,"DealerName":"Horizon Bangalore Showroom","Location":"Bangalore","To":"1/15/2025","From":"3/15/2025","Day":60,"WorkingDay":52,"Team":"T1"}]}',
        0, 1, 0, GETUTCDATE(), GETUTCDATE()
    );
END;

-- Package: E5A1C8F2-3333-4000-A000-000000000003 (Pinnacle Advertising)
-- This package has CostSummary (EE000003) and ActivitySummary (FF000003) but with NULLs — UPDATE them
UPDATE CostSummaries SET
    PlaceOfSupply = N'Tamil Nadu',
    NumberOfDays = 30,
    NumberOfActivations = 1,
    NumberOfTeams = 2,
    ElementWiseCostsJson = N'[{"Element":"Banner","Amount":4000},{"Element":"Flyers","Amount":2000},{"Element":"Refreshments","Amount":5000}]',
    ElementWiseQuantityJson = N'[{"Element":"Banner","Qty":6},{"Element":"Flyers","Qty":1000},{"Element":"Refreshments","Qty":100}]',
    TotalCost = 180000
WHERE PackageId = 'E5A1C8F2-3333-4000-A000-000000000003' AND IsDeleted = 0;

UPDATE ActivitySummaries SET
    DealerName = N'Pinnacle Chennai Motors',
    TotalDays = 28,
    TotalWorkingDays = 22,
    ExtractedDataJson = N'{"Rows":[{"SNo":1,"DealerName":"Pinnacle Chennai Motors","Location":"Chennai","To":"2/10/2025","From":"3/10/2025","Day":28,"WorkingDay":22,"Team":"T1"}]}'
WHERE PackageId = 'E5A1C8F2-3333-4000-A000-000000000003' AND IsDeleted = 0;

PRINT 'All PendingASM packages now have Cost Summary and Activity Summary data populated.';
