using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BajajDocumentProcessing.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddPoBalanceLogs : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_CampaignInvoices_DocumentPackages_PackageId",
                table: "CampaignInvoices");

            migrationBuilder.DropForeignKey(
                name: "FK_Teams_Invoices_InvoiceId",
                table: "Teams");

            migrationBuilder.DropIndex(
                name: "IX_Teams_InvoiceId",
                table: "Teams");

            migrationBuilder.DropColumn(
                name: "InvoiceId",
                table: "Teams");

            migrationBuilder.CreateTable(
                name: "POBalanceLogs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "NEWID()"),
                    PoNum = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    CompanyCode = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    RequestedBy = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: true),
                    RequestedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    SapRequestBody = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    SapCalledAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    SapRespondedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    SapHttpStatus = table.Column<int>(type: "int", nullable: true),
                    SapResponseBody = table.Column<string>(type: "nvarchar(4000)", maxLength: 4000, nullable: true),
                    Balance = table.Column<decimal>(type: "decimal(18,2)", nullable: true),
                    Currency = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: true),
                    IsSuccess = table.Column<bool>(type: "bit", nullable: false),
                    ErrorMessage = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    ElapsedMs = table.Column<long>(type: "bigint", nullable: false),
                    CorrelationId = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_POBalanceLogs", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_POBalanceLogs_IsSuccess",
                table: "POBalanceLogs",
                column: "IsSuccess");

            migrationBuilder.CreateIndex(
                name: "IX_POBalanceLogs_PoNum",
                table: "POBalanceLogs",
                column: "PoNum");

            migrationBuilder.CreateIndex(
                name: "IX_POBalanceLogs_RequestedAt",
                table: "POBalanceLogs",
                column: "RequestedAt",
                descending: new bool[0]);

            migrationBuilder.AddForeignKey(
                name: "FK_CampaignInvoices_DocumentPackages_PackageId",
                table: "CampaignInvoices",
                column: "PackageId",
                principalTable: "DocumentPackages",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_CampaignInvoices_DocumentPackages_PackageId",
                table: "CampaignInvoices");

            migrationBuilder.DropTable(
                name: "POBalanceLogs");

            migrationBuilder.AddColumn<Guid>(
                name: "InvoiceId",
                table: "Teams",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Teams_InvoiceId",
                table: "Teams",
                column: "InvoiceId");

            migrationBuilder.AddForeignKey(
                name: "FK_CampaignInvoices_DocumentPackages_PackageId",
                table: "CampaignInvoices",
                column: "PackageId",
                principalTable: "DocumentPackages",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_Teams_Invoices_InvoiceId",
                table: "Teams",
                column: "InvoiceId",
                principalTable: "Invoices",
                principalColumn: "Id");
        }
    }
}
