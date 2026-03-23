-- Seed cost summary for package 28C9823C-1111-4000-A000-000000000001
-- Data from Swift Events - Bajaj CARGO EV TRIALS Activity (Bihar)
INSERT INTO CostSummaries (
    Id, PackageId, TotalCost, PlaceOfSupply, NumberOfDays, NumberOfActivations, NumberOfTeams,
    ElementWiseCostsJson, ElementWiseQuantityJson, CostBreakdownJson,
    FileName, BlobUrl, FileSizeBytes, ContentType, ExtractedDataJson,
    ExtractionConfidence, IsFlaggedForReview, VersionNumber,
    CreatedAt, UpdatedAt, IsDeleted
) VALUES (
    NEWID(),
    '28C9823C-1111-4000-A000-000000000001',
    443721,
    'Bihar',
    90,
    1,
    2,
    '[{"Element":"Vehicle Branding","Amount":16000},{"Element":"POS - Banner","Amount":1200},{"Element":"Transportation of POS","Amount":8000},{"Element":"Inter City Travel","Amount":8000},{"Element":"Uniform for Manpower","Amount":2800},{"Element":"Leaflet","Amount":29250},{"Element":"Promoter","Amount":126000},{"Element":"Promoter DA","Amount":36000},{"Element":"Lodging & Boarding","Amount":63000},{"Element":"Intra City Travel","Amount":15600},{"Element":"Portable PA system (Rent)","Amount":36000},{"Element":"Agency Fees/Cost","Amount":34185}]',
    '[{"Element":"Vehicle Branding","Qty":2},{"Element":"POS - Banner","Qty":2},{"Element":"Transportation of POS","Qty":2},{"Element":"Inter City Travel","Qty":4},{"Element":"Uniform for Manpower","Qty":8},{"Element":"Leaflet","Qty":150},{"Element":"Promoter","Qty":2},{"Element":"Promoter DA","Qty":2},{"Element":"Lodging & Boarding","Qty":2},{"Element":"Intra City Travel","Qty":2},{"Element":"Portable PA system (Rent)","Qty":1}]',
    NULL,
    'SE-01-2025-26-cost-summary.pdf',
    'https://placeholder.blob.core.windows.net/docs/cost-summary.pdf',
    245000,
    'application/pdf',
    NULL,
    0.92,
    0,
    1,
    GETUTCDATE(), GETUTCDATE(), 0
);
PRINT 'Cost summary inserted for package 28C9823C-1111-4000-A000-000000000001';
