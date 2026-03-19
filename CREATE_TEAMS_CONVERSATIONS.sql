-- =============================================
-- Create TeamsConversations table (missing from DB due to migration sync issue)
-- Safe to run multiple times (idempotent)
-- Run against: localhost\SQLEXPRESS / BajajDocumentProcessing
-- =============================================

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

    PRINT 'TeamsConversations table created successfully.';
END
ELSE
BEGIN
    PRINT 'TeamsConversations table already exists — skipping.';
END
