using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BajajDocumentProcessing.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class MultiLevelApproval : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ASMReviewNotes",
                table: "DocumentPackages",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ASMReviewedAt",
                table: "DocumentPackages",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ASMReviewedById",
                table: "DocumentPackages",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ASMReviewedByUserId",
                table: "DocumentPackages",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "HQReviewNotes",
                table: "DocumentPackages",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "HQReviewedAt",
                table: "DocumentPackages",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "HQReviewedById",
                table: "DocumentPackages",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "HQReviewedByUserId",
                table: "DocumentPackages",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_DocumentPackages_ASMReviewedById",
                table: "DocumentPackages",
                column: "ASMReviewedById");

            migrationBuilder.CreateIndex(
                name: "IX_DocumentPackages_HQReviewedById",
                table: "DocumentPackages",
                column: "HQReviewedById");

            migrationBuilder.AddForeignKey(
                name: "FK_DocumentPackages_Users_ASMReviewedById",
                table: "DocumentPackages",
                column: "ASMReviewedById",
                principalTable: "Users",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_DocumentPackages_Users_HQReviewedById",
                table: "DocumentPackages",
                column: "HQReviewedById",
                principalTable: "Users",
                principalColumn: "Id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_DocumentPackages_Users_ASMReviewedById",
                table: "DocumentPackages");

            migrationBuilder.DropForeignKey(
                name: "FK_DocumentPackages_Users_HQReviewedById",
                table: "DocumentPackages");

            migrationBuilder.DropIndex(
                name: "IX_DocumentPackages_ASMReviewedById",
                table: "DocumentPackages");

            migrationBuilder.DropIndex(
                name: "IX_DocumentPackages_HQReviewedById",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "ASMReviewNotes",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "ASMReviewedAt",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "ASMReviewedById",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "ASMReviewedByUserId",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "HQReviewNotes",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "HQReviewedAt",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "HQReviewedById",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "HQReviewedByUserId",
                table: "DocumentPackages");
        }
    }
}
