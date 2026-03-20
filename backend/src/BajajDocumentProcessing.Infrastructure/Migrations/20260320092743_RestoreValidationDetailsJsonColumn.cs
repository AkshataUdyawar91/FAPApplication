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
