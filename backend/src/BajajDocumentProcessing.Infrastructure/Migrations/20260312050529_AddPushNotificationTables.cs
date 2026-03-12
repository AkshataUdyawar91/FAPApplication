using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BajajDocumentProcessing.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddPushNotificationTables : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "CampaignEndDate",
                table: "DocumentPackages",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "CampaignStartDate",
                table: "DocumentPackages",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "CampaignWorkingDays",
                table: "DocumentPackages",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DealershipAddress",
                table: "DocumentPackages",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DealershipName",
                table: "DocumentPackages",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "EnquiryDocBlobUrl",
                table: "DocumentPackages",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "EnquiryDocContentType",
                table: "DocumentPackages",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "EnquiryDocExtractedDataJson",
                table: "DocumentPackages",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "EnquiryDocExtractionConfidence",
                table: "DocumentPackages",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "EnquiryDocFileName",
                table: "DocumentPackages",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<long>(
                name: "EnquiryDocFileSizeBytes",
                table: "DocumentPackages",
                type: "bigint",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "GPSLocation",
                table: "DocumentPackages",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "DeviceTokens",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Platform = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    Token = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    RegisteredAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    LastUsedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    UpdatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DeviceTokens", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DeviceTokens_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Invoices",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PackageId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PODocumentId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    InvoiceNumber = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    InvoiceDate = table.Column<DateTime>(type: "datetime2", nullable: true),
                    VendorName = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    GSTNumber = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    SubTotal = table.Column<decimal>(type: "decimal(18,2)", nullable: true),
                    TaxAmount = table.Column<decimal>(type: "decimal(18,2)", nullable: true),
                    TotalAmount = table.Column<decimal>(type: "decimal(18,2)", nullable: true),
                    FileName = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: false),
                    BlobUrl = table.Column<string>(type: "nvarchar(2048)", maxLength: 2048, nullable: false),
                    FileSizeBytes = table.Column<long>(type: "bigint", nullable: false),
                    ContentType = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    ExtractedDataJson = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    ExtractionConfidence = table.Column<double>(type: "float", nullable: true),
                    IsFlaggedForReview = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    UpdatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Invoices", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Invoices_DocumentPackages_PackageId",
                        column: x => x.PackageId,
                        principalTable: "DocumentPackages",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_Invoices_Documents_PODocumentId",
                        column: x => x.PODocumentId,
                        principalTable: "Documents",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "NotificationPreferences",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    NotificationType = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    IsPushEnabled = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    IsEmailEnabled = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    UpdatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NotificationPreferences", x => x.Id);
                    table.ForeignKey(
                        name: "FK_NotificationPreferences_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "NotificationLogs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DeviceTokenId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    NotificationType = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Channel = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    Platform = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    ErrorMessage = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    SentAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    CorrelationId = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    UpdatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NotificationLogs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_NotificationLogs_DeviceTokens_DeviceTokenId",
                        column: x => x.DeviceTokenId,
                        principalTable: "DeviceTokens",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_NotificationLogs_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Campaigns",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PackageId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CampaignName = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    TeamCode = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    StartDate = table.Column<DateTime>(type: "datetime2", nullable: true),
                    EndDate = table.Column<DateTime>(type: "datetime2", nullable: true),
                    WorkingDays = table.Column<int>(type: "int", nullable: true),
                    DealershipName = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    DealershipAddress = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    GPSLocation = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    State = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    TeamsJson = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    TotalCost = table.Column<decimal>(type: "decimal(18,2)", nullable: true),
                    CostBreakdownJson = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    CostSummaryFileName = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: true),
                    CostSummaryBlobUrl = table.Column<string>(type: "nvarchar(2048)", maxLength: 2048, nullable: true),
                    CostSummaryContentType = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    CostSummaryFileSizeBytes = table.Column<long>(type: "bigint", nullable: true),
                    CostSummaryExtractedDataJson = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    CostSummaryExtractionConfidence = table.Column<double>(type: "float", nullable: true),
                    ActivitySummaryFileName = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: true),
                    ActivitySummaryBlobUrl = table.Column<string>(type: "nvarchar(2048)", maxLength: 2048, nullable: true),
                    ActivitySummaryContentType = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    ActivitySummaryFileSizeBytes = table.Column<long>(type: "bigint", nullable: true),
                    ActivitySummaryExtractedDataJson = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    ActivitySummaryExtractionConfidence = table.Column<double>(type: "float", nullable: true),
                    InvoiceId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    UpdatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Campaigns", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Campaigns_DocumentPackages_PackageId",
                        column: x => x.PackageId,
                        principalTable: "DocumentPackages",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_Campaigns_Invoices_InvoiceId",
                        column: x => x.InvoiceId,
                        principalTable: "Invoices",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "CampaignInvoices",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CampaignId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PackageId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    InvoiceNumber = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    InvoiceDate = table.Column<DateTime>(type: "datetime2", nullable: true),
                    VendorName = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    GSTNumber = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    SubTotal = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: true),
                    TaxAmount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: true),
                    TotalAmount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: true),
                    FileName = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    BlobUrl = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false),
                    FileSizeBytes = table.Column<long>(type: "bigint", nullable: false),
                    ContentType = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    ExtractedDataJson = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    ExtractionConfidence = table.Column<double>(type: "float", nullable: true),
                    IsFlaggedForReview = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    UpdatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CampaignInvoices", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CampaignInvoices_Campaigns_CampaignId",
                        column: x => x.CampaignId,
                        principalTable: "Campaigns",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CampaignInvoices_DocumentPackages_PackageId",
                        column: x => x.PackageId,
                        principalTable: "DocumentPackages",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "CampaignPhotos",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CampaignId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PackageId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    FileName = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: false),
                    BlobUrl = table.Column<string>(type: "nvarchar(2048)", maxLength: 2048, nullable: false),
                    FileSizeBytes = table.Column<long>(type: "bigint", nullable: false),
                    ContentType = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    Caption = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    PhotoTimestamp = table.Column<DateTime>(type: "datetime2", nullable: true),
                    Latitude = table.Column<double>(type: "float", nullable: true),
                    Longitude = table.Column<double>(type: "float", nullable: true),
                    DeviceModel = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    ExtractedMetadataJson = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    ExtractionConfidence = table.Column<double>(type: "float", nullable: true),
                    IsFlaggedForReview = table.Column<bool>(type: "bit", nullable: false),
                    DisplayOrder = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    UpdatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CampaignPhotos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CampaignPhotos_Campaigns_CampaignId",
                        column: x => x.CampaignId,
                        principalTable: "Campaigns",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_CampaignPhotos_DocumentPackages_PackageId",
                        column: x => x.PackageId,
                        principalTable: "DocumentPackages",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

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

            migrationBuilder.CreateIndex(
                name: "IX_CampaignPhotos_CampaignId",
                table: "CampaignPhotos",
                column: "CampaignId");

            migrationBuilder.CreateIndex(
                name: "IX_CampaignPhotos_PackageId",
                table: "CampaignPhotos",
                column: "PackageId");

            migrationBuilder.CreateIndex(
                name: "IX_CampaignPhotos_PhotoTimestamp",
                table: "CampaignPhotos",
                column: "PhotoTimestamp");

            migrationBuilder.CreateIndex(
                name: "IX_Campaigns_CampaignName",
                table: "Campaigns",
                column: "CampaignName");

            migrationBuilder.CreateIndex(
                name: "IX_Campaigns_InvoiceId",
                table: "Campaigns",
                column: "InvoiceId");

            migrationBuilder.CreateIndex(
                name: "IX_Campaigns_PackageId",
                table: "Campaigns",
                column: "PackageId");

            migrationBuilder.CreateIndex(
                name: "IX_Campaigns_State",
                table: "Campaigns",
                column: "State");

            migrationBuilder.CreateIndex(
                name: "IX_Campaigns_TeamCode",
                table: "Campaigns",
                column: "TeamCode");

            migrationBuilder.CreateIndex(
                name: "IX_DeviceTokens_IsActive",
                table: "DeviceTokens",
                column: "IsActive");

            migrationBuilder.CreateIndex(
                name: "IX_DeviceTokens_UserId_Platform",
                table: "DeviceTokens",
                columns: new[] { "UserId", "Platform" });

            migrationBuilder.CreateIndex(
                name: "IX_DeviceTokens_UserId_Platform_Token",
                table: "DeviceTokens",
                columns: new[] { "UserId", "Platform", "Token" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Invoices_InvoiceNumber",
                table: "Invoices",
                column: "InvoiceNumber");

            migrationBuilder.CreateIndex(
                name: "IX_Invoices_PackageId",
                table: "Invoices",
                column: "PackageId");

            migrationBuilder.CreateIndex(
                name: "IX_Invoices_PODocumentId",
                table: "Invoices",
                column: "PODocumentId");

            migrationBuilder.CreateIndex(
                name: "IX_NotificationLogs_CorrelationId",
                table: "NotificationLogs",
                column: "CorrelationId");

            migrationBuilder.CreateIndex(
                name: "IX_NotificationLogs_DeviceTokenId",
                table: "NotificationLogs",
                column: "DeviceTokenId");

            migrationBuilder.CreateIndex(
                name: "IX_NotificationLogs_UserId_SentAt",
                table: "NotificationLogs",
                columns: new[] { "UserId", "SentAt" });

            migrationBuilder.CreateIndex(
                name: "IX_NotificationPreferences_UserId",
                table: "NotificationPreferences",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_NotificationPreferences_UserId_NotificationType",
                table: "NotificationPreferences",
                columns: new[] { "UserId", "NotificationType" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CampaignInvoices");

            migrationBuilder.DropTable(
                name: "CampaignPhotos");

            migrationBuilder.DropTable(
                name: "NotificationLogs");

            migrationBuilder.DropTable(
                name: "NotificationPreferences");

            migrationBuilder.DropTable(
                name: "Campaigns");

            migrationBuilder.DropTable(
                name: "DeviceTokens");

            migrationBuilder.DropTable(
                name: "Invoices");

            migrationBuilder.DropColumn(
                name: "CampaignEndDate",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "CampaignStartDate",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "CampaignWorkingDays",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "DealershipAddress",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "DealershipName",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "EnquiryDocBlobUrl",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "EnquiryDocContentType",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "EnquiryDocExtractedDataJson",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "EnquiryDocExtractionConfidence",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "EnquiryDocFileName",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "EnquiryDocFileSizeBytes",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "GPSLocation",
                table: "DocumentPackages");
        }
    }
}
