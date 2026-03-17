using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BajajDocumentProcessing.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddActivitySummaryExtractedColumns : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "DealerName",
                table: "ActivitySummaries",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "TotalDays",
                table: "ActivitySummaries",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "TotalWorkingDays",
                table: "ActivitySummaries",
                type: "int",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DealerName",
                table: "ActivitySummaries");

            migrationBuilder.DropColumn(
                name: "TotalDays",
                table: "ActivitySummaries");

            migrationBuilder.DropColumn(
                name: "TotalWorkingDays",
                table: "ActivitySummaries");
        }
    }
}
