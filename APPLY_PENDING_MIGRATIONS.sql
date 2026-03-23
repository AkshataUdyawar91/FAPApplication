-- =============================================
-- Script: APPLY_PENDING_MIGRATIONS.sql
-- Purpose: Apply missing columns from 3 pending EF Core migrations
--          that were skipped by the auto-mark logic in Program.cs.
-- Date: 2026-03-18
-- Idempotent: Yes — uses IF NOT EXISTS / COL_LENGTH guards.
-- =============================================

BEGIN TRANSACTION;
BEGIN TRY

-- ============================================================
-- Migration 1: 20260317000001_AddActivitySummaryExtractedColumns
-- ============================================================
IF COL_LENGTH('ActivitySummaries', 'DealerName') IS NULL
BEGIN
    ALTER TABLE ActivitySummaries ADD DealerName NVARCHAR(500) NULL;
    PRINT 'Added ActivitySummaries.DealerName';
END
ELSE PRINT 'ActivitySummaries.DealerName already exists — skipping';

IF COL_LENGTH('ActivitySummaries', 'TotalDays') IS NULL
BEGIN
    ALTER TABLE ActivitySummaries ADD TotalDays INT NULL;
    PRINT 'Added ActivitySummaries.TotalDays';
END
ELSE PRINT 'ActivitySummaries.TotalDays already exists — skipping';

IF COL_LENGTH('ActivitySummaries', 'TotalWorkingDays') IS NULL
BEGIN
    ALTER TABLE ActivitySummaries ADD TotalWorkingDays INT NULL;
    PRINT 'Added ActivitySummaries.TotalWorkingDays';
END
ELSE PRINT 'ActivitySummaries.TotalWorkingDays already exists — skipping';

-- Mark as applied
IF NOT EXISTS (SELECT 1 FROM [__EFMigrationsHistory] WHERE MigrationId = '20260317000001_AddActivitySummaryExtractedColumns')
BEGIN
    INSERT INTO [__EFMigrationsHistory] (MigrationId, ProductVersion) VALUES ('20260317000001_AddActivitySummaryExtractedColumns', '8.0.0');
    PRINT 'Marked 20260317000001_AddActivitySummaryExtractedColumns as applied';
END

-- ============================================================
-- Migration 2: 20260317000002_AddCostSummaryExtractedColumns
-- ============================================================
IF COL_LENGTH('CostSummaries', 'PlaceOfSupply') IS NULL
BEGIN
    ALTER TABLE CostSummaries ADD PlaceOfSupply NVARCHAR(500) NULL;
    PRINT 'Added CostSummaries.PlaceOfSupply';
END
ELSE PRINT 'CostSummaries.PlaceOfSupply already exists — skipping';

IF COL_LENGTH('CostSummaries', 'NumberOfDays') IS NULL
BEGIN
    ALTER TABLE CostSummaries ADD NumberOfDays INT NULL;
    PRINT 'Added CostSummaries.NumberOfDays';
END
ELSE PRINT 'CostSummaries.NumberOfDays already exists — skipping';

IF COL_LENGTH('CostSummaries', 'NumberOfActivations') IS NULL
BEGIN
    ALTER TABLE CostSummaries ADD NumberOfActivations INT NULL;
    PRINT 'Added CostSummaries.NumberOfActivations';
END
ELSE PRINT 'CostSummaries.NumberOfActivations already exists — skipping';

IF COL_LENGTH('CostSummaries', 'NumberOfTeams') IS NULL
BEGIN
    ALTER TABLE CostSummaries ADD NumberOfTeams INT NULL;
    PRINT 'Added CostSummaries.NumberOfTeams';
END
ELSE PRINT 'CostSummaries.NumberOfTeams already exists — skipping';

IF COL_LENGTH('CostSummaries', 'ElementWiseCostsJson') IS NULL
BEGIN
    ALTER TABLE CostSummaries ADD ElementWiseCostsJson NVARCHAR(MAX) NULL;
    PRINT 'Added CostSummaries.ElementWiseCostsJson';
END
ELSE PRINT 'CostSummaries.ElementWiseCostsJson already exists — skipping';

IF COL_LENGTH('CostSummaries', 'ElementWiseQuantityJson') IS NULL
BEGIN
    ALTER TABLE CostSummaries ADD ElementWiseQuantityJson NVARCHAR(MAX) NULL;
    PRINT 'Added CostSummaries.ElementWiseQuantityJson';
END
ELSE PRINT 'CostSummaries.ElementWiseQuantityJson already exists — skipping';

-- Mark as applied
IF NOT EXISTS (SELECT 1 FROM [__EFMigrationsHistory] WHERE MigrationId = '20260317000002_AddCostSummaryExtractedColumns')
BEGIN
    INSERT INTO [__EFMigrationsHistory] (MigrationId, ProductVersion) VALUES ('20260317000002_AddCostSummaryExtractedColumns', '8.0.0');
    PRINT 'Marked 20260317000002_AddCostSummaryExtractedColumns as applied';
END

-- ============================================================
-- Migration 3: 20260615120000_AddNotificationMultiChannelFields
-- ============================================================

-- Notifications table columns
IF COL_LENGTH('Notifications', 'Channel') IS NULL
BEGIN
    ALTER TABLE Notifications ADD Channel INT NOT NULL DEFAULT 1;
    PRINT 'Added Notifications.Channel';
END
ELSE PRINT 'Notifications.Channel already exists — skipping';

IF COL_LENGTH('Notifications', 'DeliveryStatus') IS NULL
BEGIN
    ALTER TABLE Notifications ADD DeliveryStatus INT NOT NULL DEFAULT 2;
    PRINT 'Added Notifications.DeliveryStatus';
END
ELSE PRINT 'Notifications.DeliveryStatus already exists — skipping';

IF COL_LENGTH('Notifications', 'RetryCount') IS NULL
BEGIN
    ALTER TABLE Notifications ADD RetryCount INT NOT NULL DEFAULT 0;
    PRINT 'Added Notifications.RetryCount';
END
ELSE PRINT 'Notifications.RetryCount already exists — skipping';

IF COL_LENGTH('Notifications', 'SentAt') IS NULL
BEGIN
    ALTER TABLE Notifications ADD SentAt DATETIME2 NULL;
    PRINT 'Added Notifications.SentAt';
END
ELSE PRINT 'Notifications.SentAt already exists — skipping';

IF COL_LENGTH('Notifications', 'ExternalMessageId') IS NULL
BEGIN
    ALTER TABLE Notifications ADD ExternalMessageId NVARCHAR(500) NULL;
    PRINT 'Added Notifications.ExternalMessageId';
END
ELSE PRINT 'Notifications.ExternalMessageId already exists — skipping';

IF COL_LENGTH('Notifications', 'FailureReason') IS NULL
BEGIN
    ALTER TABLE Notifications ADD FailureReason NVARCHAR(2000) NULL;
    PRINT 'Added Notifications.FailureReason';
END
ELSE PRINT 'Notifications.FailureReason already exists — skipping';

-- RequestApprovalHistory table
IF COL_LENGTH('RequestApprovalHistory', 'Channel') IS NULL
BEGIN
    ALTER TABLE RequestApprovalHistory ADD Channel NVARCHAR(50) NULL;
    PRINT 'Added RequestApprovalHistory.Channel';
END
ELSE PRINT 'RequestApprovalHistory.Channel already exists — skipping';

-- Indexes
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Notifications_UserId_Channel_DeliveryStatus')
BEGIN
    CREATE INDEX IX_Notifications_UserId_Channel_DeliveryStatus ON Notifications (UserId, Channel, DeliveryStatus);
    PRINT 'Created IX_Notifications_UserId_Channel_DeliveryStatus';
END

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Notifications_RelatedEntityId_Channel')
BEGIN
    CREATE INDEX IX_Notifications_RelatedEntityId_Channel ON Notifications (RelatedEntityId, Channel);
    PRINT 'Created IX_Notifications_RelatedEntityId_Channel';
END

-- Mark as applied
IF NOT EXISTS (SELECT 1 FROM [__EFMigrationsHistory] WHERE MigrationId = '20260615120000_AddNotificationMultiChannelFields')
BEGIN
    INSERT INTO [__EFMigrationsHistory] (MigrationId, ProductVersion) VALUES ('20260615120000_AddNotificationMultiChannelFields', '8.0.0');
    PRINT 'Marked 20260615120000_AddNotificationMultiChannelFields as applied';
END

COMMIT TRANSACTION;
PRINT '';
PRINT 'All 3 pending migrations applied successfully.';

END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    THROW;
END CATCH
