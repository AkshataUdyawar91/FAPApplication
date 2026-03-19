using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BajajDocumentProcessing.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddRAUserIdToStateMappings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "GstRate",
                table: "StateGstMasters",
                newName: "GstPercentage");

            migrationBuilder.AddColumn<Guid>(
                name: "RAUserId",
                table: "StateMappings",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "AssignedRAUserId",
                table: "DocumentPackages",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_StateMappings_RAUserId",
                table: "StateMappings",
                column: "RAUserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_StateMappings_RAUserId",
                table: "StateMappings");

            migrationBuilder.DropColumn(
                name: "RAUserId",
                table: "StateMappings");

            migrationBuilder.DropColumn(
                name: "AssignedRAUserId",
                table: "DocumentPackages");

            migrationBuilder.RenameColumn(
                name: "GstPercentage",
                table: "StateGstMasters",
                newName: "GstRate");
        }
    }
}
