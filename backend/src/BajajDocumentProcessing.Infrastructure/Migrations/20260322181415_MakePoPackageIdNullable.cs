using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BajajDocumentProcessing.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class MakePoPackageIdNullable : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_CampaignInvoices_DocumentPackages_PackageId",
                table: "CampaignInvoices");

            migrationBuilder.DropIndex(
                name: "IX_Notifications_RelatedEntityId",
                table: "Notifications");

            migrationBuilder.DropIndex(
                name: "IX_Agencies_IsDeleted",
                table: "Agencies");

            migrationBuilder.AlterColumn<string>(
                name: "AadObjectId",
                table: "Users",
                type: "nvarchar(128)",
                maxLength: 128,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(256)",
                oldMaxLength: 256,
                oldNullable: true);

            migrationBuilder.AlterColumn<bool>(
                name: "IsDeleted",
                table: "StateCities",
                type: "bit",
                nullable: false,
                oldClrType: typeof(bool),
                oldType: "bit",
                oldDefaultValue: false);

            migrationBuilder.AlterColumn<bool>(
                name: "IsDeleted",
                table: "Dealers",
                type: "bit",
                nullable: false,
                oldClrType: typeof(bool),
                oldType: "bit",
                oldDefaultValue: false);

            migrationBuilder.CreateIndex(
                name: "IX_Users_AadObjectId",
                table: "Users",
                column: "AadObjectId",
                unique: true,
                filter: "[AadObjectId] IS NOT NULL");

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

            migrationBuilder.DropIndex(
                name: "IX_Users_AadObjectId",
                table: "Users");

            migrationBuilder.AlterColumn<string>(
                name: "AadObjectId",
                table: "Users",
                type: "nvarchar(256)",
                maxLength: 256,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(128)",
                oldMaxLength: 128,
                oldNullable: true);

            migrationBuilder.AlterColumn<bool>(
                name: "IsDeleted",
                table: "StateCities",
                type: "bit",
                nullable: false,
                defaultValue: false,
                oldClrType: typeof(bool),
                oldType: "bit");

            migrationBuilder.AlterColumn<bool>(
                name: "IsDeleted",
                table: "Dealers",
                type: "bit",
                nullable: false,
                defaultValue: false,
                oldClrType: typeof(bool),
                oldType: "bit");

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_RelatedEntityId",
                table: "Notifications",
                column: "RelatedEntityId");

            migrationBuilder.CreateIndex(
                name: "IX_Agencies_IsDeleted",
                table: "Agencies",
                column: "IsDeleted");

            migrationBuilder.AddForeignKey(
                name: "FK_CampaignInvoices_DocumentPackages_PackageId",
                table: "CampaignInvoices",
                column: "PackageId",
                principalTable: "DocumentPackages",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
