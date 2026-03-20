using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BajajDocumentProcessing.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class RestoreValidationDetailsJsonColumn : Migration
    {
        /// <summary>
        /// Helper: adds a column only if it doesn't already exist.
        /// </summary>
        private static void AddColumnIfNotExists(
            MigrationBuilder migrationBuilder,
            string tableName,
            string columnName,
            string columnType,
            int? maxLength = null)
        {
            var typeSql = maxLength.HasValue ? $"{columnType}({maxLength})" : columnType;
            migrationBuilder.Sql($@"
                IF NOT EXISTS (
                    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_NAME = '{tableName}' AND COLUMN_NAME = '{columnName}'
                )
                BEGIN
                    ALTER TABLE [{tableName}] ADD [{columnName}] {typeSql} NULL;
                END;
            ");
        }

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Teams
            AddColumnIfNotExists(migrationBuilder, "Teams", "TeamNumber", "int");

            // TeamPhotos
            AddColumnIfNotExists(migrationBuilder, "TeamPhotos", "BlueTshirtPresent", "bit");
            AddColumnIfNotExists(migrationBuilder, "TeamPhotos", "DateVisible", "bit");
            AddColumnIfNotExists(migrationBuilder, "TeamPhotos", "PhotoDateOverlay", "nvarchar", 100);
            AddColumnIfNotExists(migrationBuilder, "TeamPhotos", "ThreeWheelerPresent", "bit");

            // StateMappings
            AddColumnIfNotExists(migrationBuilder, "StateMappings", "City", "nvarchar(max)");
            AddColumnIfNotExists(migrationBuilder, "StateMappings", "DealerCode", "nvarchar(max)");
            AddColumnIfNotExists(migrationBuilder, "StateMappings", "DealerName", "nvarchar(max)");

            // ValidationResults — restore ValidationDetailsJson
            AddColumnIfNotExists(migrationBuilder, "ValidationResults", "ValidationDetailsJson", "nvarchar(max)");

            // TeamPhotos.Caption — widen from nvarchar(1000) to nvarchar(max) to hold EXIF metadata JSON
            migrationBuilder.Sql(@"
                IF EXISTS (
                    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_NAME = 'TeamPhotos' AND COLUMN_NAME = 'Caption'
                      AND CHARACTER_MAXIMUM_LENGTH <> -1
                )
                BEGIN
                    ALTER TABLE [TeamPhotos] ALTER COLUMN [Caption] NVARCHAR(MAX) NULL;
                END;
            ");

            // Notifications — multi-channel delivery tracking fields (NOT NULL with defaults need raw SQL)
            migrationBuilder.Sql(@"
                IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Notifications' AND COLUMN_NAME = 'Channel')
                BEGIN ALTER TABLE [Notifications] ADD [Channel] int NOT NULL DEFAULT 1; END;
            ");
            migrationBuilder.Sql(@"
                IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Notifications' AND COLUMN_NAME = 'DeliveryStatus')
                BEGIN ALTER TABLE [Notifications] ADD [DeliveryStatus] int NOT NULL DEFAULT 2; END;
            ");
            migrationBuilder.Sql(@"
                IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Notifications' AND COLUMN_NAME = 'RetryCount')
                BEGIN ALTER TABLE [Notifications] ADD [RetryCount] int NOT NULL DEFAULT 0; END;
            ");
            AddColumnIfNotExists(migrationBuilder, "Notifications", "SentAt", "datetime2");
            AddColumnIfNotExists(migrationBuilder, "Notifications", "ExternalMessageId", "nvarchar", 500);
            AddColumnIfNotExists(migrationBuilder, "Notifications", "FailureReason", "nvarchar", 2000);

            // Notifications — composite indexes for multi-channel queries
            migrationBuilder.Sql(@"
                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Notifications_UserId_Channel_DeliveryStatus')
                BEGIN
                    CREATE INDEX [IX_Notifications_UserId_Channel_DeliveryStatus]
                    ON [Notifications] ([UserId], [Channel], [DeliveryStatus]);
                END;
            ");
            migrationBuilder.Sql(@"
                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Notifications_RelatedEntityId_Channel')
                BEGIN
                    CREATE INDEX [IX_Notifications_RelatedEntityId_Channel]
                    ON [Notifications] ([RelatedEntityId], [Channel]);
                END;
            ");

            // RequestApprovalHistory — Channel column
            AddColumnIfNotExists(migrationBuilder, "RequestApprovalHistory", "Channel", "nvarchar", 50);

            // Users — AadObjectId column
            AddColumnIfNotExists(migrationBuilder, "Users", "AadObjectId", "nvarchar", 256);

            // TeamsConversations table
            migrationBuilder.Sql(@"
                IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'TeamsConversations')
                BEGIN
                    CREATE TABLE [TeamsConversations] (
                        [Id] uniqueidentifier NOT NULL,
                        [UserId] uniqueidentifier NULL,
                        [TeamsUserId] nvarchar(256) NOT NULL,
                        [TeamsUserName] nvarchar(max) NOT NULL,
                        [ConversationId] nvarchar(256) NOT NULL,
                        [ServiceUrl] nvarchar(512) NOT NULL,
                        [ChannelId] nvarchar(64) NOT NULL,
                        [BotId] nvarchar(max) NOT NULL,
                        [BotName] nvarchar(max) NOT NULL,
                        [TenantId] nvarchar(max) NULL,
                        [ConversationReferenceJson] nvarchar(max) NOT NULL,
                        [IsActive] bit NOT NULL DEFAULT 1,
                        [LastActivityAt] datetime2 NULL,
                        [LastMessageSentAt] datetime2 NULL,
                        [CreatedAt] datetime2 NOT NULL,
                        [UpdatedAt] datetime2 NULL,
                        [CreatedBy] nvarchar(max) NULL,
                        [UpdatedBy] nvarchar(max) NULL,
                        [IsDeleted] bit NOT NULL DEFAULT 0,
                        CONSTRAINT [PK_TeamsConversations] PRIMARY KEY ([Id]),
                        CONSTRAINT [FK_TeamsConversations_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users]([Id]) ON DELETE SET NULL
                    );

                    CREATE INDEX [IX_TeamsConversations_TeamsUserId] ON [TeamsConversations] ([TeamsUserId]);
                    CREATE INDEX [IX_TeamsConversations_ConversationId] ON [TeamsConversations] ([ConversationId]);
                    CREATE INDEX [IX_TeamsConversations_UserId] ON [TeamsConversations] ([UserId]) WHERE IsActive = 1;

                    PRINT 'Created TeamsConversations table with indexes';
                END;
            ");

            // CampaignInvoices table
            migrationBuilder.Sql(@"
                IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CampaignInvoices')
                BEGIN
                    CREATE TABLE [CampaignInvoices] (
                        [Id] uniqueidentifier NOT NULL,
                        [CampaignId] uniqueidentifier NOT NULL,
                        [PackageId] uniqueidentifier NOT NULL,
                        [InvoiceNumber] nvarchar(100) NULL,
                        [InvoiceDate] datetime2 NULL,
                        [VendorName] nvarchar(500) NULL,
                        [GSTNumber] nvarchar(50) NULL,
                        [SubTotal] decimal(18,2) NULL,
                        [TaxAmount] decimal(18,2) NULL,
                        [TotalAmount] decimal(18,2) NULL,
                        [FileName] nvarchar(500) NOT NULL,
                        [BlobUrl] nvarchar(2000) NOT NULL,
                        [FileSizeBytes] bigint NOT NULL,
                        [ContentType] nvarchar(100) NOT NULL,
                        [ExtractedDataJson] nvarchar(max) NULL,
                        [ExtractionConfidence] float NULL,
                        [IsFlaggedForReview] bit NOT NULL DEFAULT 0,
                        [CreatedAt] datetime2 NOT NULL,
                        [UpdatedAt] datetime2 NULL,
                        [CreatedBy] nvarchar(max) NULL,
                        [UpdatedBy] nvarchar(max) NULL,
                        [IsDeleted] bit NOT NULL DEFAULT 0,
                        CONSTRAINT [PK_CampaignInvoices] PRIMARY KEY ([Id]),
                        CONSTRAINT [FK_CampaignInvoices_Teams_CampaignId] FOREIGN KEY ([CampaignId]) REFERENCES [Teams]([Id]) ON DELETE NO ACTION,
                        CONSTRAINT [FK_CampaignInvoices_DocumentPackages_PackageId] FOREIGN KEY ([PackageId]) REFERENCES [DocumentPackages]([Id]) ON DELETE CASCADE
                    );

                    CREATE INDEX [IX_CampaignInvoices_CampaignId] ON [CampaignInvoices] ([CampaignId]);
                    CREATE INDEX [IX_CampaignInvoices_InvoiceNumber] ON [CampaignInvoices] ([InvoiceNumber]);
                    CREATE INDEX [IX_CampaignInvoices_PackageId] ON [CampaignInvoices] ([PackageId]);

                    PRINT 'Created CampaignInvoices table with indexes';
                END;
            ");

            // EmailDeliveryLogs table
            migrationBuilder.Sql(@"
                IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'EmailDeliveryLogs')
                BEGIN
                    CREATE TABLE [EmailDeliveryLogs] (
                        [Id] uniqueidentifier NOT NULL,
                        [PackageId] uniqueidentifier NOT NULL,
                        [RecipientEmail] nvarchar(2000) NOT NULL,
                        [TemplateName] nvarchar(100) NOT NULL,
                        [Subject] nvarchar(500) NOT NULL,
                        [Success] bit NOT NULL,
                        [MessageId] nvarchar(200) NULL,
                        [ErrorMessage] nvarchar(2000) NULL,
                        [AttemptsCount] int NOT NULL,
                        [SentAt] datetime2 NOT NULL,
                        [CreatedAt] datetime2 NOT NULL,
                        [UpdatedAt] datetime2 NULL,
                        [CreatedBy] nvarchar(max) NULL,
                        [UpdatedBy] nvarchar(max) NULL,
                        [IsDeleted] bit NOT NULL,
                        CONSTRAINT [PK_EmailDeliveryLogs] PRIMARY KEY ([Id])
                    );

                    CREATE INDEX [IX_EmailDeliveryLogs_PackageId] ON [EmailDeliveryLogs] ([PackageId]);
                    CREATE INDEX [IX_EmailDeliveryLogs_TemplateName] ON [EmailDeliveryLogs] ([TemplateName]);
                END;
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
                IF EXISTS (
                    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_NAME = 'ValidationResults' AND COLUMN_NAME = 'ValidationDetailsJson'
                )
                BEGIN
                    ALTER TABLE [ValidationResults] DROP COLUMN [ValidationDetailsJson];
                END;
            ");

            migrationBuilder.Sql(@"
                IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'EmailDeliveryLogs')
                    DROP TABLE [EmailDeliveryLogs];
            ");

            migrationBuilder.DropColumn(name: "TeamNumber", table: "Teams");
            migrationBuilder.DropColumn(name: "BlueTshirtPresent", table: "TeamPhotos");
            migrationBuilder.DropColumn(name: "DateVisible", table: "TeamPhotos");
            migrationBuilder.DropColumn(name: "PhotoDateOverlay", table: "TeamPhotos");
            migrationBuilder.DropColumn(name: "ThreeWheelerPresent", table: "TeamPhotos");
            migrationBuilder.DropColumn(name: "City", table: "StateMappings");
            migrationBuilder.DropColumn(name: "DealerCode", table: "StateMappings");
            migrationBuilder.DropColumn(name: "DealerName", table: "StateMappings");
        }
    }
}
