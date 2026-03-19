-- Mark all previously applied migrations in __EFMigrationsHistory
-- Run this when the table is empty but the DB already has all tables

IF NOT EXISTS (SELECT 1 FROM [__EFMigrationsHistory] WHERE [MigrationId] = '20260312082915_DatabaseRedesign')
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion]) VALUES ('20260312082915_DatabaseRedesign', '8.0.0');

IF NOT EXISTS (SELECT 1 FROM [__EFMigrationsHistory] WHERE [MigrationId] = '20260312155638_RemoveLegacyDocumentsTable')
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion]) VALUES ('20260312155638_RemoveLegacyDocumentsTable', '8.0.0');

IF NOT EXISTS (SELECT 1 FROM [__EFMigrationsHistory] WHERE [MigrationId] = '20260313082520_AddReferenceDataTables')
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion]) VALUES ('20260313082520_AddReferenceDataTables', '8.0.0');

IF NOT EXISTS (SELECT 1 FROM [__EFMigrationsHistory] WHERE [MigrationId] = '20260316143447_SeedStateGstData')
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion]) VALUES ('20260316143447_SeedStateGstData', '8.0.0');

IF NOT EXISTS (SELECT 1 FROM [__EFMigrationsHistory] WHERE [MigrationId] = '20260316145553_ReplaceGstCodeWithGstRate')
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion]) VALUES ('20260316145553_ReplaceGstCodeWithGstRate', '8.0.0');

IF NOT EXISTS (SELECT 1 FROM [__EFMigrationsHistory] WHERE [MigrationId] = '20260316145644_AddGstRateColumn')
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion]) VALUES ('20260316145644_AddGstRateColumn', '8.0.0');

IF NOT EXISTS (SELECT 1 FROM [__EFMigrationsHistory] WHERE [MigrationId] = '20260317000001_AddActivitySummaryExtractedColumns')
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion]) VALUES ('20260317000001_AddActivitySummaryExtractedColumns', '8.0.0');

IF NOT EXISTS (SELECT 1 FROM [__EFMigrationsHistory] WHERE [MigrationId] = '20260317000002_AddCostSummaryExtractedColumns')
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion]) VALUES ('20260317000002_AddCostSummaryExtractedColumns', '8.0.0');

IF NOT EXISTS (SELECT 1 FROM [__EFMigrationsHistory] WHERE [MigrationId] = '20260317101710_AddPoBalanceLogs')
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion]) VALUES ('20260317101710_AddPoBalanceLogs', '8.0.0');

IF NOT EXISTS (SELECT 1 FROM [__EFMigrationsHistory] WHERE [MigrationId] = '20260318073114_AddRAUserIdToStateMappings')
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion]) VALUES ('20260318073114_AddRAUserIdToStateMappings', '8.0.0');

SELECT [MigrationId] FROM [__EFMigrationsHistory] ORDER BY [MigrationId];
