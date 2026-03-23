-- ============================================================
-- CHECK & CREATE: Teams Bot related tables and columns
-- Run this in SSMS against BajajFAP_Shubhankar
-- ============================================================

-- 1. TeamsConversations table (required for bot conversation persistence)
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'TeamsConversations')
BEGIN
    CREATE TABLE [TeamsConversations] (
        [Id]                        UNIQUEIDENTIFIER    NOT NULL DEFAULT NEWID(),
        [UserId]                    UNIQUEIDENTIFIER    NULL,
        [TeamsUserId]               NVARCHAR(256)       NOT NULL DEFAULT '',
        [TeamsUserName]             NVARCHAR(MAX)       NOT NULL DEFAULT '',
        [ConversationId]            NVARCHAR(256)       NOT NULL DEFAULT '',
        [ServiceUrl]                NVARCHAR(512)       NOT NULL DEFAULT '',
        [ChannelId]                 NVARCHAR(64)        NOT NULL DEFAULT '',
        [BotId]                     NVARCHAR(MAX)       NOT NULL DEFAULT '',
        [BotName]                   NVARCHAR(MAX)       NOT NULL DEFAULT '',
        [TenantId]                  NVARCHAR(MAX)       NULL,
        [ConversationReferenceJson] NVARCHAR(MAX)       NOT NULL DEFAULT '',
        [IsActive]                  BIT                 NOT NULL DEFAULT 1,
        [LastActivityAt]            DATETIME2           NULL,
        [LastMessageSentAt]         DATETIME2           NULL,
        [IsDeleted]                 BIT                 NOT NULL DEFAULT 0,
        [CreatedAt]                 DATETIME2           NOT NULL DEFAULT GETUTCDATE(),
        [UpdatedAt]                 DATETIME2           NULL,
        [CreatedBy]                 NVARCHAR(MAX)       NULL,
        [UpdatedBy]                 NVARCHAR(MAX)       NULL,
        CONSTRAINT [PK_TeamsConversations] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_TeamsConversations_Users] FOREIGN KEY ([UserId])
            REFERENCES [Users]([Id]) ON DELETE SET NULL
    );

    CREATE INDEX [IX_TeamsConversations_TeamsUserId]
        ON [TeamsConversations] ([TeamsUserId]);

    CREATE INDEX [IX_TeamsConversations_ConversationId]
        ON [TeamsConversations] ([ConversationId]);

    CREATE INDEX [IX_TeamsConversations_UserId]
        ON [TeamsConversations] ([UserId])
        WHERE [IsActive] = 1;

    PRINT 'Created TeamsConversations table';
END
ELSE
    PRINT 'TeamsConversations table already exists';

-- 2. Users.AadObjectId (already added earlier — just in case)
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_NAME = 'Users' AND COLUMN_NAME = 'AadObjectId')
BEGIN
    ALTER TABLE [Users] ADD [AadObjectId] NVARCHAR(128) NULL;
    PRINT 'Added AadObjectId to Users';
END
ELSE
    PRINT 'Users.AadObjectId already exists';

-- 3. IX_Users_AadObjectId unique index
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'IX_Users_AadObjectId' AND object_id = OBJECT_ID('Users'))
BEGIN
    CREATE UNIQUE INDEX [IX_Users_AadObjectId]
        ON [Users] ([AadObjectId])
        WHERE [AadObjectId] IS NOT NULL;
    PRINT 'Created IX_Users_AadObjectId index';
END
ELSE
    PRINT 'IX_Users_AadObjectId already exists';

-- 4. DocumentPackages.AssignedRAUserId (used in bot pending query)
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'AssignedRAUserId')
BEGIN
    ALTER TABLE [DocumentPackages] ADD [AssignedRAUserId] UNIQUEIDENTIFIER NULL;
    PRINT 'Added AssignedRAUserId to DocumentPackages';
END
ELSE
    PRINT 'DocumentPackages.AssignedRAUserId already exists';

-- 5. DocumentPackages.AssignedCircleHeadUserId
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'AssignedCircleHeadUserId')
BEGIN
    ALTER TABLE [DocumentPackages] ADD [AssignedCircleHeadUserId] UNIQUEIDENTIFIER NULL;
    PRINT 'Added AssignedCircleHeadUserId to DocumentPackages';
END
ELSE
    PRINT 'DocumentPackages.AssignedCircleHeadUserId already exists';

-- 6. RequestApprovalHistory.Channel (used by bot approve/reject)
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_NAME = 'RequestApprovalHistory' AND COLUMN_NAME = 'Channel')
BEGIN
    ALTER TABLE [RequestApprovalHistory] ADD [Channel] NVARCHAR(MAX) NULL;
    PRINT 'Added Channel to RequestApprovalHistory';
END
ELSE
    PRINT 'RequestApprovalHistory.Channel already exists';

PRINT '=== Done ===';
