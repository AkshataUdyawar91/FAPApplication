using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BajajDocumentProcessing.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddDealerStateCityTables : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Guard: only drop if exists (may have been dropped manually)
            migrationBuilder.Sql("IF OBJECT_ID('ASMs', 'U') IS NOT NULL DROP TABLE [ASMs]");
            migrationBuilder.Sql("IF OBJECT_ID('CampaignInvoices', 'U') IS NOT NULL DROP TABLE [CampaignInvoices]");

            migrationBuilder.Sql("IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_StateMappings_DealerCode' AND object_id = OBJECT_ID('StateMappings')) DROP INDEX [IX_StateMappings_DealerCode] ON [StateMappings]");
            migrationBuilder.Sql("IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_StateMappings_State' AND object_id = OBJECT_ID('StateMappings')) DROP INDEX [IX_StateMappings_State] ON [StateMappings]");

            migrationBuilder.Sql("IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'ValidationResults' AND COLUMN_NAME = 'ValidationDetailsJson') ALTER TABLE [ValidationResults] DROP COLUMN [ValidationDetailsJson]");
            migrationBuilder.Sql("IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Teams' AND COLUMN_NAME = 'TeamsJson') ALTER TABLE [Teams] DROP COLUMN [TeamsJson]");
            migrationBuilder.Sql("IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'StateMappings' AND COLUMN_NAME = 'City') ALTER TABLE [StateMappings] DROP COLUMN [City]");
            migrationBuilder.Sql("IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'StateMappings' AND COLUMN_NAME = 'DealerCode') ALTER TABLE [StateMappings] DROP COLUMN [DealerCode]");
            migrationBuilder.Sql("IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'StateMappings' AND COLUMN_NAME = 'DealerName') ALTER TABLE [StateMappings] DROP COLUMN [DealerName]");

            migrationBuilder.Sql("IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'POs' AND COLUMN_NAME = 'RefreshedAt') ALTER TABLE [POs] ADD [RefreshedAt] datetime2 NULL");

            migrationBuilder.Sql(@"IF OBJECT_ID('Dealers', 'U') IS NULL
            CREATE TABLE [Dealers] (
                [Id] uniqueidentifier NOT NULL,
                [DealerCode] nvarchar(50) NOT NULL,
                [DealerName] nvarchar(200) NOT NULL,
                [State] nvarchar(100) NOT NULL,
                [City] nvarchar(100) NULL,
                [IsActive] bit NOT NULL DEFAULT 1,
                [CreatedAt] datetime2 NOT NULL,
                [UpdatedAt] datetime2 NULL,
                [CreatedBy] nvarchar(max) NULL,
                [UpdatedBy] nvarchar(max) NULL,
                [IsDeleted] bit NOT NULL DEFAULT 0,
                CONSTRAINT [PK_Dealers] PRIMARY KEY ([Id])
            )");

            migrationBuilder.Sql(@"IF OBJECT_ID('POSyncLogs', 'U') IS NULL
            CREATE TABLE [POSyncLogs] (
                [Id] uniqueidentifier NOT NULL,
                [SourceSystem] nvarchar(max) NOT NULL,
                [FileName] nvarchar(max) NOT NULL,
                [AgencyId] uniqueidentifier NULL,
                [POId] uniqueidentifier NULL,
                [Status] nvarchar(max) NOT NULL,
                [ErrorMessage] nvarchar(max) NULL,
                [ProcessedAt] datetime2 NOT NULL,
                [ImportedRecords] nvarchar(max) NULL,
                [CreatedAt] datetime2 NOT NULL,
                [UpdatedAt] datetime2 NULL,
                [CreatedBy] nvarchar(max) NULL,
                [UpdatedBy] nvarchar(max) NULL,
                [IsDeleted] bit NOT NULL DEFAULT 0,
                CONSTRAINT [PK_POSyncLogs] PRIMARY KEY ([Id]),
                CONSTRAINT [FK_POSyncLogs_Agencies_AgencyId] FOREIGN KEY ([AgencyId]) REFERENCES [Agencies] ([Id]),
                CONSTRAINT [FK_POSyncLogs_POs_POId] FOREIGN KEY ([POId]) REFERENCES [POs] ([Id])
            )");

            migrationBuilder.Sql(@"IF OBJECT_ID('StateCities', 'U') IS NULL
            CREATE TABLE [StateCities] (
                [Id] uniqueidentifier NOT NULL,
                [State] nvarchar(100) NOT NULL,
                [City] nvarchar(100) NOT NULL,
                [IsActive] bit NOT NULL DEFAULT 1,
                [CreatedAt] datetime2 NOT NULL,
                [UpdatedAt] datetime2 NULL,
                [CreatedBy] nvarchar(max) NULL,
                [UpdatedBy] nvarchar(max) NULL,
                [IsDeleted] bit NOT NULL DEFAULT 0,
                CONSTRAINT [PK_StateCities] PRIMARY KEY ([Id])
            )");

            migrationBuilder.Sql(@"
                IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_StateMappings_CircleHeadUserId' AND object_id = OBJECT_ID('StateMappings'))
                    DROP INDEX [IX_StateMappings_CircleHeadUserId] ON [StateMappings];
                CREATE INDEX [IX_StateMappings_CircleHeadUserId] ON [StateMappings] ([CircleHeadUserId]);
            ");
            migrationBuilder.Sql("IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_StateMappings_State' AND object_id = OBJECT_ID('StateMappings')) CREATE UNIQUE INDEX [IX_StateMappings_State] ON [StateMappings] ([State])");
            migrationBuilder.Sql("IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Dealers_DealerCode' AND object_id = OBJECT_ID('Dealers')) CREATE UNIQUE INDEX [IX_Dealers_DealerCode] ON [Dealers] ([DealerCode])");
            migrationBuilder.Sql("IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Dealers_State' AND object_id = OBJECT_ID('Dealers')) CREATE INDEX [IX_Dealers_State] ON [Dealers] ([State])");
            migrationBuilder.Sql("IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Dealers_State_IsActive' AND object_id = OBJECT_ID('Dealers')) CREATE INDEX [IX_Dealers_State_IsActive] ON [Dealers] ([State], [IsActive])");
            migrationBuilder.Sql("IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_POSyncLogs_AgencyId' AND object_id = OBJECT_ID('POSyncLogs')) CREATE INDEX [IX_POSyncLogs_AgencyId] ON [POSyncLogs] ([AgencyId])");
            migrationBuilder.Sql("IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_POSyncLogs_POId' AND object_id = OBJECT_ID('POSyncLogs')) CREATE INDEX [IX_POSyncLogs_POId] ON [POSyncLogs] ([POId])");
            migrationBuilder.Sql("IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_StateCities_State' AND object_id = OBJECT_ID('StateCities')) CREATE INDEX [IX_StateCities_State] ON [StateCities] ([State])");
            migrationBuilder.Sql("IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_StateCities_State_City' AND object_id = OBJECT_ID('StateCities')) CREATE UNIQUE INDEX [IX_StateCities_State_City] ON [StateCities] ([State], [City])");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Dealers");

            migrationBuilder.DropTable(
                name: "POSyncLogs");

            migrationBuilder.DropTable(
                name: "StateCities");

            migrationBuilder.DropIndex(
                name: "IX_StateMappings_CircleHeadUserId",
                table: "StateMappings");

            migrationBuilder.DropIndex(
                name: "IX_StateMappings_State",
                table: "StateMappings");

            migrationBuilder.DropColumn(
                name: "RefreshedAt",
                table: "POs");

            migrationBuilder.AddColumn<string>(
                name: "ValidationDetailsJson",
                table: "ValidationResults",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TeamsJson",
                table: "Teams",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "City",
                table: "StateMappings",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DealerCode",
                table: "StateMappings",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "DealerName",
                table: "StateMappings",
                type: "nvarchar(200)",
                maxLength: 200,
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateTable(
                name: "ASMs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    CreatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    Location = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    UpdatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ASMs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ASMs_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "CampaignInvoices",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CampaignId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PackageId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BlobUrl = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false),
                    ContentType = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    CreatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    ExtractedDataJson = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    ExtractionConfidence = table.Column<double>(type: "float", nullable: true),
                    FileName = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    FileSizeBytes = table.Column<long>(type: "bigint", nullable: false),
                    GSTNumber = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    InvoiceDate = table.Column<DateTime>(type: "datetime2", nullable: true),
                    InvoiceNumber = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false),
                    IsFlaggedForReview = table.Column<bool>(type: "bit", nullable: false),
                    SubTotal = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: true),
                    TaxAmount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: true),
                    TotalAmount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    UpdatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    VendorName = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CampaignInvoices", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CampaignInvoices_DocumentPackages_PackageId",
                        column: x => x.PackageId,
                        principalTable: "DocumentPackages",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CampaignInvoices_Teams_CampaignId",
                        column: x => x.CampaignId,
                        principalTable: "Teams",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_StateMappings_DealerCode",
                table: "StateMappings",
                column: "DealerCode");

            migrationBuilder.CreateIndex(
                name: "IX_StateMappings_State",
                table: "StateMappings",
                column: "State");

            migrationBuilder.CreateIndex(
                name: "IX_ASMs_IsDeleted",
                table: "ASMs",
                column: "IsDeleted");

            migrationBuilder.CreateIndex(
                name: "IX_ASMs_Location",
                table: "ASMs",
                column: "Location");

            migrationBuilder.CreateIndex(
                name: "IX_ASMs_UserId",
                table: "ASMs",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_CampaignInvoices_CampaignId",
                table: "CampaignInvoices",
                column: "CampaignId");

            migrationBuilder.CreateIndex(
                name: "IX_CampaignInvoices_InvoiceNumber",
                table: "CampaignInvoices",
                column: "InvoiceNumber");

            migrationBuilder.CreateIndex(
                name: "IX_CampaignInvoices_PackageId",
                table: "CampaignInvoices",
                column: "PackageId");
        }
    }
}
