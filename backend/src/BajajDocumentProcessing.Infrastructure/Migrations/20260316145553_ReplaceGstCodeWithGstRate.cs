using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BajajDocumentProcessing.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class ReplaceGstCodeWithGstRate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_StateGstMasters_GstCode",
                table: "StateGstMasters");

            migrationBuilder.DropColumn(
                name: "GstCode",
                table: "StateGstMasters");

            migrationBuilder.AddColumn<decimal>(
                name: "GstRate",
                table: "StateGstMasters",
                type: "decimal(5,2)",
                nullable: false,
                defaultValue: 0m);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "GstRate",
                table: "StateGstMasters");

            migrationBuilder.AddColumn<string>(
                name: "GstCode",
                table: "StateGstMasters",
                type: "nvarchar(2)",
                maxLength: 2,
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateIndex(
                name: "IX_StateGstMasters_GstCode",
                table: "StateGstMasters",
                column: "GstCode",
                unique: true);
        }
    }
}
