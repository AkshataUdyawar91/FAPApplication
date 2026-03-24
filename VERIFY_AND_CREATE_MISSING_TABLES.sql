-- =============================================
-- Verify and create all potentially missing tables/columns
-- Run against: localhost\SQLEXPRESS / BajajDocumentProcessing
-- Idempotent: safe to run multiple times
-- =============================================

PRINT '=== Checking for missing tables and columns ==='

-- 1. TeamsConversations
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'TeamsConversations')
BEGIN
    CREATE TABLE [TeamsConversations] (
        [Id]                          uniqueidentifier NOT NULL,
        [UserId]                      uniqueidentifier NULL,
        [TeamsUserId]                 nvarchar(256)    NOT NULL,
        [TeamsUserName]               nvarchar(max)    NOT NULL DEFAULT N'',
        [ConversationId]              nvarchar(256)    NOT NULL,
        [ServiceUrl]                  nvarchar(512)    NOT NULL DEFAULT N'',
        [ChannelId]                   nvarchar(64)     NOT NULL DEFAULT N'',
        [BotId]                       nvarchar(max)    NOT NULL DEFAULT N'',
        [BotName]                     nvarchar(max)    NOT NULL DEFAULT N'',
        [TenantId]                    nvarchar(max)    NULL,
        [ConversationReferenceJson]   nvarchar(max)    NOT NULL DEFAULT N'',
        [IsActive]                    bit              NOT NULL DEFAULT CAST(1 AS bit),
        [LastActivityAt]              datetime2        NULL,
        [LastMessageSentAt]           datetime2        NULL,
        [CreatedAt]                   datetime2        NOT NULL,
        [UpdatedAt]                   datetime2        NULL,
        [CreatedBy]                   nvarchar(max)    NULL,
        [UpdatedBy]                   nvarchar(max)    NULL,
        [IsDeleted]                   bit              NOT NULL DEFAULT CAST(0 AS bit),
        CONSTRAINT [PK_TeamsConversations] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_TeamsConversations_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id])
    );
    CREATE INDEX [IX_TeamsConversations_TeamsUserId] ON [TeamsConversations] ([TeamsUserId]);
    CREATE INDEX [IX_TeamsConversations_ConversationId] ON [TeamsConversations] ([ConversationId]);
    CREATE INDEX [IX_TeamsConversations_UserId] ON [TeamsConversations] ([UserId]) WHERE [IsActive] = 1;
    PRINT '  CREATED: TeamsConversations';
END
ELSE PRINT '  OK: TeamsConversations exists';

-- 2. POBalanceLogs
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'POBalanceLogs')
BEGIN
    CREATE TABLE [POBalanceLogs] (
        [Id]              uniqueidentifier NOT NULL DEFAULT NEWID(),
        [PoNum]           nvarchar(50)     NOT NULL,
        [CompanyCode]     nvarchar(20)     NOT NULL,
        [RequestedBy]     nvarchar(450)    NULL,
        [RequestedAt]     datetime2        NOT NULL,
        [SapRequestBody]  nvarchar(max)    NULL,
        [SapCalledAt]     datetime2        NULL,
        [SapRespondedAt]  datetime2        NULL,
        [SapHttpStatus]   int              NULL,
        [SapResponseBody] nvarchar(4000)   NULL,
        [Balance]         decimal(18,2)    NULL,
        [Currency]        nvarchar(10)     NULL,
        [IsSuccess]       bit              NOT NULL,
        [ErrorMessage]    nvarchar(max)    NULL,
        [ElapsedMs]       bigint           NOT NULL,
        [CorrelationId]   nvarchar(100)    NULL,
        CONSTRAINT [PK_POBalanceLogs] PRIMARY KEY ([Id])
    );
    CREATE INDEX [IX_POBalanceLogs_PoNum] ON [POBalanceLogs] ([PoNum]);
    CREATE INDEX [IX_POBalanceLogs_RequestedAt] ON [POBalanceLogs] ([RequestedAt] DESC);
    CREATE INDEX [IX_POBalanceLogs_IsSuccess] ON [POBalanceLogs] ([IsSuccess]);
    PRINT '  CREATED: POBalanceLogs';
END
ELSE PRINT '  OK: POBalanceLogs exists';

-- 3. Drop InvoiceId from Teams if it still exists (AddPoBalanceLogs migration removes it)
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Teams' AND COLUMN_NAME = 'InvoiceId')
BEGIN
    -- Drop the index first if it exists
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Teams_InvoiceId' AND object_id = OBJECT_ID('Teams'))
        DROP INDEX [IX_Teams_InvoiceId] ON [Teams];
    -- Drop the FK if it exists
    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Teams_Invoices_InvoiceId')
        ALTER TABLE [Teams] DROP CONSTRAINT [FK_Teams_Invoices_InvoiceId];
    ALTER TABLE [Teams] DROP COLUMN [InvoiceId];
    PRINT '  FIXED: Dropped InvoiceId from Teams';
END
ELSE PRINT '  OK: Teams.InvoiceId already removed';

-- 4. Add RefreshedAt to POs if missing
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'POs' AND COLUMN_NAME = 'RefreshedAt')
BEGIN
    ALTER TABLE [POs] ADD [RefreshedAt] datetime2 NULL;
    PRINT '  FIXED: Added RefreshedAt to POs';
END
ELSE PRINT '  OK: POs.RefreshedAt exists';

-- 5. Sync __EFMigrationsHistory so migrations don't re-run
PRINT '';
PRINT '=== Syncing migration history ==='

DECLARE @migrations TABLE (MigrationId nvarchar(150));
INSERT INTO @migrations VALUES
    ('20260312082915_DatabaseRedesign'),
    ('20260312155638_RemoveLegacyDocumentsTable'),
    ('20260313082520_AddReferenceDataTables'),
    ('20260316143447_SeedStateGstData'),
    ('20260316145553_ReplaceGstCodeWithGstRate'),
    ('20260316145644_AddGstRateColumn'),
    ('20260317101710_AddPoBalanceLogs');

INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
SELECT m.MigrationId, '8.0.0'
FROM @migrations m
WHERE NOT EXISTS (
    SELECT 1 FROM [__EFMigrationsHistory] h WHERE h.MigrationId = m.MigrationId
);

PRINT '  Migration history synced.';
PRINT '';
PRINT '=== Done ===';
