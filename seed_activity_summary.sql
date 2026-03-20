-- Seed activity summary for package 28C9823C-1111-4000-A000-000000000001
-- Data: Magadh Auto Agency, Patna, 49 days, 39 working days
INSERT INTO ActivitySummaries (
    Id, PackageId, ActivityDescription, DealerName, TotalDays, TotalWorkingDays,
    FileName, BlobUrl, FileSizeBytes, ContentType,
    ExtractedDataJson, ExtractionConfidence, IsFlaggedForReview, VersionNumber,
    CreatedAt, UpdatedAt, IsDeleted
) VALUES (
    NEWID(),
    '28C9823C-1111-4000-A000-000000000001',
    'Bajaj CARGO EV TRIALS Activity - Magadh Auto Agency, Patna',
    'Magadh Auto Agency',
    49,
    39,
    'activity-summary.xlsx',
    'https://placeholder.blob.core.windows.net/docs/activity-summary.xlsx',
    85000,
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    '{"Rows":[{"SNo":1,"DealerName":"Magadh Auto Agency","Location":"Patna","To":"2/14/2025","From":"4/3/2025","Day":49,"WorkingDay":39,"Team":"T1"}]}',
    0.95,
    0,
    1,
    GETUTCDATE(), GETUTCDATE(), 0
);
PRINT 'Activity summary inserted for package 28C9823C-1111-4000-A000-000000000001';
