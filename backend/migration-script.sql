IF OBJECT_ID(N'[__EFMigrationsHistory]') IS NULL
BEGIN
    CREATE TABLE [__EFMigrationsHistory] (
        [MigrationId] nvarchar(150) NOT NULL,
        [ProductVersion] nvarchar(32) NOT NULL,
        CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY ([MigrationId])
    );
END;
GO

BEGIN TRANSACTION;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE TABLE [Users] (
        [Id] uniqueidentifier NOT NULL,
        [Email] nvarchar(256) NOT NULL,
        [PasswordHash] nvarchar(512) NOT NULL,
        [FullName] nvarchar(256) NOT NULL,
        [Role] int NOT NULL,
        [PhoneNumber] nvarchar(20) NULL,
        [IsActive] bit NOT NULL DEFAULT CAST(1 AS bit),
        [LastLoginAt] datetime2 NULL,
        [CreatedAt] datetime2 NOT NULL,
        [UpdatedAt] datetime2 NULL,
        [CreatedBy] nvarchar(max) NULL,
        [UpdatedBy] nvarchar(max) NULL,
        [IsDeleted] bit NOT NULL,
        CONSTRAINT [PK_Users] PRIMARY KEY ([Id])
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE TABLE [AuditLogs] (
        [Id] uniqueidentifier NOT NULL,
        [UserId] uniqueidentifier NOT NULL,
        [Action] nvarchar(128) NOT NULL,
        [EntityType] nvarchar(128) NOT NULL,
        [EntityId] uniqueidentifier NULL,
        [OldValuesJson] nvarchar(max) NULL,
        [NewValuesJson] nvarchar(max) NULL,
        [IpAddress] nvarchar(45) NOT NULL,
        [UserAgent] nvarchar(512) NOT NULL,
        [CreatedAt] datetime2 NOT NULL,
        [UpdatedAt] datetime2 NULL,
        [CreatedBy] nvarchar(max) NULL,
        [UpdatedBy] nvarchar(max) NULL,
        [IsDeleted] bit NOT NULL,
        CONSTRAINT [PK_AuditLogs] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_AuditLogs_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE NO ACTION
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE TABLE [Conversations] (
        [Id] uniqueidentifier NOT NULL,
        [UserId] uniqueidentifier NOT NULL,
        [LastMessageAt] datetime2 NOT NULL,
        [CreatedAt] datetime2 NOT NULL,
        [UpdatedAt] datetime2 NULL,
        [CreatedBy] nvarchar(max) NULL,
        [UpdatedBy] nvarchar(max) NULL,
        [IsDeleted] bit NOT NULL,
        CONSTRAINT [PK_Conversations] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_Conversations_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE TABLE [DocumentPackages] (
        [Id] uniqueidentifier NOT NULL,
        [SubmittedByUserId] uniqueidentifier NOT NULL,
        [ReviewedByUserId] uniqueidentifier NULL,
        [State] int NOT NULL,
        [ReviewedAt] datetime2 NULL,
        [ReviewNotes] nvarchar(2000) NULL,
        [CreatedAt] datetime2 NOT NULL,
        [UpdatedAt] datetime2 NULL,
        [CreatedBy] nvarchar(max) NULL,
        [UpdatedBy] nvarchar(max) NULL,
        [IsDeleted] bit NOT NULL,
        CONSTRAINT [PK_DocumentPackages] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_DocumentPackages_Users_ReviewedByUserId] FOREIGN KEY ([ReviewedByUserId]) REFERENCES [Users] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_DocumentPackages_Users_SubmittedByUserId] FOREIGN KEY ([SubmittedByUserId]) REFERENCES [Users] ([Id]) ON DELETE NO ACTION
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE TABLE [ConversationMessages] (
        [Id] uniqueidentifier NOT NULL,
        [ConversationId] uniqueidentifier NOT NULL,
        [Role] nvarchar(max) NOT NULL,
        [Content] nvarchar(max) NOT NULL,
        [CreatedAt] datetime2 NOT NULL,
        [UpdatedAt] datetime2 NULL,
        [CreatedBy] nvarchar(max) NULL,
        [UpdatedBy] nvarchar(max) NULL,
        [IsDeleted] bit NOT NULL,
        CONSTRAINT [PK_ConversationMessages] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_ConversationMessages_Conversations_ConversationId] FOREIGN KEY ([ConversationId]) REFERENCES [Conversations] ([Id]) ON DELETE CASCADE
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE TABLE [ConfidenceScores] (
        [Id] uniqueidentifier NOT NULL,
        [PackageId] uniqueidentifier NOT NULL,
        [PoConfidence] float(5) NOT NULL,
        [InvoiceConfidence] float(5) NOT NULL,
        [CostSummaryConfidence] float(5) NOT NULL,
        [ActivityConfidence] float(5) NOT NULL,
        [PhotosConfidence] float(5) NOT NULL,
        [OverallConfidence] float(5) NOT NULL,
        [IsFlaggedForReview] bit NOT NULL,
        [CreatedAt] datetime2 NOT NULL,
        [UpdatedAt] datetime2 NULL,
        [CreatedBy] nvarchar(max) NULL,
        [UpdatedBy] nvarchar(max) NULL,
        [IsDeleted] bit NOT NULL,
        CONSTRAINT [PK_ConfidenceScores] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_ConfidenceScores_DocumentPackages_PackageId] FOREIGN KEY ([PackageId]) REFERENCES [DocumentPackages] ([Id]) ON DELETE CASCADE
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE TABLE [Documents] (
        [Id] uniqueidentifier NOT NULL,
        [PackageId] uniqueidentifier NOT NULL,
        [Type] int NOT NULL,
        [FileName] nvarchar(512) NOT NULL,
        [BlobUrl] nvarchar(2048) NOT NULL,
        [FileSizeBytes] bigint NOT NULL,
        [ContentType] nvarchar(128) NOT NULL,
        [ExtractedDataJson] nvarchar(max) NULL,
        [ExtractionConfidence] float NULL,
        [IsFlaggedForReview] bit NOT NULL,
        [CreatedAt] datetime2 NOT NULL,
        [UpdatedAt] datetime2 NULL,
        [CreatedBy] nvarchar(max) NULL,
        [UpdatedBy] nvarchar(max) NULL,
        [IsDeleted] bit NOT NULL,
        CONSTRAINT [PK_Documents] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_Documents_DocumentPackages_PackageId] FOREIGN KEY ([PackageId]) REFERENCES [DocumentPackages] ([Id]) ON DELETE CASCADE
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE TABLE [Notifications] (
        [Id] uniqueidentifier NOT NULL,
        [UserId] uniqueidentifier NOT NULL,
        [Type] int NOT NULL,
        [Title] nvarchar(256) NOT NULL,
        [Message] nvarchar(2000) NOT NULL,
        [IsRead] bit NOT NULL DEFAULT CAST(0 AS bit),
        [ReadAt] datetime2 NULL,
        [RelatedEntityId] uniqueidentifier NULL,
        [CreatedAt] datetime2 NOT NULL,
        [UpdatedAt] datetime2 NULL,
        [CreatedBy] nvarchar(max) NULL,
        [UpdatedBy] nvarchar(max) NULL,
        [IsDeleted] bit NOT NULL,
        CONSTRAINT [PK_Notifications] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_Notifications_DocumentPackages_RelatedEntityId] FOREIGN KEY ([RelatedEntityId]) REFERENCES [DocumentPackages] ([Id]) ON DELETE SET NULL,
        CONSTRAINT [FK_Notifications_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE TABLE [Recommendations] (
        [Id] uniqueidentifier NOT NULL,
        [PackageId] uniqueidentifier NOT NULL,
        [Type] int NOT NULL,
        [Evidence] nvarchar(4000) NOT NULL,
        [ValidationIssuesJson] nvarchar(max) NULL,
        [ConfidenceScore] float(5) NOT NULL,
        [CreatedAt] datetime2 NOT NULL,
        [UpdatedAt] datetime2 NULL,
        [CreatedBy] nvarchar(max) NULL,
        [UpdatedBy] nvarchar(max) NULL,
        [IsDeleted] bit NOT NULL,
        CONSTRAINT [PK_Recommendations] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_Recommendations_DocumentPackages_PackageId] FOREIGN KEY ([PackageId]) REFERENCES [DocumentPackages] ([Id]) ON DELETE CASCADE
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE TABLE [ValidationResults] (
        [Id] uniqueidentifier NOT NULL,
        [PackageId] uniqueidentifier NOT NULL,
        [SapVerificationPassed] bit NOT NULL,
        [AmountConsistencyPassed] bit NOT NULL,
        [LineItemMatchingPassed] bit NOT NULL,
        [CompletenessCheckPassed] bit NOT NULL,
        [DateValidationPassed] bit NOT NULL,
        [VendorMatchingPassed] bit NOT NULL,
        [AllValidationsPassed] bit NOT NULL,
        [ValidationDetailsJson] nvarchar(max) NULL,
        [FailureReason] nvarchar(2000) NULL,
        [CreatedAt] datetime2 NOT NULL,
        [UpdatedAt] datetime2 NULL,
        [CreatedBy] nvarchar(max) NULL,
        [UpdatedBy] nvarchar(max) NULL,
        [IsDeleted] bit NOT NULL,
        CONSTRAINT [PK_ValidationResults] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_ValidationResults_DocumentPackages_PackageId] FOREIGN KEY ([PackageId]) REFERENCES [DocumentPackages] ([Id]) ON DELETE CASCADE
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_AuditLogs_CreatedAt] ON [AuditLogs] ([CreatedAt]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_AuditLogs_EntityId] ON [AuditLogs] ([EntityId]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_AuditLogs_EntityType] ON [AuditLogs] ([EntityType]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_AuditLogs_UserId] ON [AuditLogs] ([UserId]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_ConfidenceScores_OverallConfidence] ON [ConfidenceScores] ([OverallConfidence]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE UNIQUE INDEX [IX_ConfidenceScores_PackageId] ON [ConfidenceScores] ([PackageId]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_ConversationMessages_ConversationId] ON [ConversationMessages] ([ConversationId]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_Conversations_UserId] ON [Conversations] ([UserId]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_DocumentPackages_CreatedAt] ON [DocumentPackages] ([CreatedAt]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_DocumentPackages_ReviewedByUserId] ON [DocumentPackages] ([ReviewedByUserId]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_DocumentPackages_State] ON [DocumentPackages] ([State]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_DocumentPackages_SubmittedByUserId] ON [DocumentPackages] ([SubmittedByUserId]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_Documents_PackageId] ON [Documents] ([PackageId]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_Documents_Type] ON [Documents] ([Type]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_Notifications_CreatedAt] ON [Notifications] ([CreatedAt]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_Notifications_IsRead] ON [Notifications] ([IsRead]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_Notifications_RelatedEntityId] ON [Notifications] ([RelatedEntityId]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_Notifications_UserId] ON [Notifications] ([UserId]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE UNIQUE INDEX [IX_Recommendations_PackageId] ON [Recommendations] ([PackageId]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_Recommendations_Type] ON [Recommendations] ([Type]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE UNIQUE INDEX [IX_Users_Email] ON [Users] ([Email]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    CREATE UNIQUE INDEX [IX_ValidationResults_PackageId] ON [ValidationResults] ([PackageId]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260301170431_InitialCreate'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260301170431_InitialCreate', N'8.0.0');
END;
GO

COMMIT;
GO

BEGIN TRANSACTION;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260305150113_MultiLevelApproval'
)
BEGIN
    ALTER TABLE [DocumentPackages] ADD [ASMReviewNotes] nvarchar(max) NULL;
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260305150113_MultiLevelApproval'
)
BEGIN
    ALTER TABLE [DocumentPackages] ADD [ASMReviewedAt] datetime2 NULL;
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260305150113_MultiLevelApproval'
)
BEGIN
    ALTER TABLE [DocumentPackages] ADD [ASMReviewedById] uniqueidentifier NULL;
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260305150113_MultiLevelApproval'
)
BEGIN
    ALTER TABLE [DocumentPackages] ADD [ASMReviewedByUserId] uniqueidentifier NULL;
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260305150113_MultiLevelApproval'
)
BEGIN
    ALTER TABLE [DocumentPackages] ADD [HQReviewNotes] nvarchar(max) NULL;
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260305150113_MultiLevelApproval'
)
BEGIN
    ALTER TABLE [DocumentPackages] ADD [HQReviewedAt] datetime2 NULL;
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260305150113_MultiLevelApproval'
)
BEGIN
    ALTER TABLE [DocumentPackages] ADD [HQReviewedById] uniqueidentifier NULL;
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260305150113_MultiLevelApproval'
)
BEGIN
    ALTER TABLE [DocumentPackages] ADD [HQReviewedByUserId] uniqueidentifier NULL;
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260305150113_MultiLevelApproval'
)
BEGIN
    CREATE INDEX [IX_DocumentPackages_ASMReviewedById] ON [DocumentPackages] ([ASMReviewedById]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260305150113_MultiLevelApproval'
)
BEGIN
    CREATE INDEX [IX_DocumentPackages_HQReviewedById] ON [DocumentPackages] ([HQReviewedById]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260305150113_MultiLevelApproval'
)
BEGIN
    ALTER TABLE [DocumentPackages] ADD CONSTRAINT [FK_DocumentPackages_Users_ASMReviewedById] FOREIGN KEY ([ASMReviewedById]) REFERENCES [Users] ([Id]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260305150113_MultiLevelApproval'
)
BEGIN
    ALTER TABLE [DocumentPackages] ADD CONSTRAINT [FK_DocumentPackages_Users_HQReviewedById] FOREIGN KEY ([HQReviewedById]) REFERENCES [Users] ([Id]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260305150113_MultiLevelApproval'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260305150113_MultiLevelApproval', N'8.0.0');
END;
GO

COMMIT;
GO

BEGIN TRANSACTION;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260306082019_AddResubmissionCounts'
)
BEGIN
    ALTER TABLE [DocumentPackages] ADD [HQResubmissionCount] int NULL;
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260306082019_AddResubmissionCounts'
)
BEGIN
    ALTER TABLE [DocumentPackages] ADD [ResubmissionCount] int NULL;
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260306082019_AddResubmissionCounts'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260306082019_AddResubmissionCounts', N'8.0.0');
END;
GO

COMMIT;
GO

