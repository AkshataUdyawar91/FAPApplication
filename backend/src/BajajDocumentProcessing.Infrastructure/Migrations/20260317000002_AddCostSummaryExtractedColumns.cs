using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BajajDocumentProcessing.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddCostSummaryExtractedColumns : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "PlaceOfSupply",
                table: "CostSummaries",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "NumberOfDays",
                table: "CostSummaries",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "NumberOfActivations",
                table: "CostSummaries",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "NumberOfTeams",
                table: "CostSummaries",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ElementWiseCostsJson",
                table: "CostSummaries",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ElementWiseQuantityJson",
                table: "CostSummaries",
                type: "nvarchar(max)",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(name: "PlaceOfSupply", table: "CostSummaries");
            migrationBuilder.DropColumn(name: "NumberOfDays", table: "CostSummaries");
            migrationBuilder.DropColumn(name: "NumberOfActivations", table: "CostSummaries");
            migrationBuilder.DropColumn(name: "NumberOfTeams", table: "CostSummaries");
            migrationBuilder.DropColumn(name: "ElementWiseCostsJson", table: "CostSummaries");
            migrationBuilder.DropColumn(name: "ElementWiseQuantityJson", table: "CostSummaries");
        }
    }
}
