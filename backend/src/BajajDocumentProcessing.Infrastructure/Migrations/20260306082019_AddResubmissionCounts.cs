using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BajajDocumentProcessing.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddResubmissionCounts : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "HQResubmissionCount",
                table: "DocumentPackages",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "ResubmissionCount",
                table: "DocumentPackages",
                type: "int",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "HQResubmissionCount",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "ResubmissionCount",
                table: "DocumentPackages");
        }
    }
}
