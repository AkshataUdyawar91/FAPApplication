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
            // Idempotent rename: only rename if GstRate still exists (may already be GstPercentage)
            migrationBuilder.Sql(@"
                IF COL_LENGTH('StateGstMasters', 'GstRate') IS NOT NULL
                    AND COL_LENGTH('StateGstMasters', 'GstPercentage') IS NULL
                BEGIN
                    EXEC sp_rename N'[StateGstMasters].[GstRate]', N'GstPercentage', N'COLUMN';
                END
            ");

            migrationBuilder.Sql(@"
                IF COL_LENGTH('StateMappings', 'RAUserId') IS NULL
                    ALTER TABLE StateMappings ADD RAUserId uniqueidentifier NULL;
            ");

            migrationBuilder.Sql(@"
                IF COL_LENGTH('DocumentPackages', 'AssignedRAUserId') IS NULL
                    ALTER TABLE DocumentPackages ADD AssignedRAUserId uniqueidentifier NULL;
            ");

            migrationBuilder.Sql(@"
                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_StateMappings_RAUserId' AND object_id = OBJECT_ID('StateMappings'))
                    CREATE INDEX IX_StateMappings_RAUserId ON StateMappings (RAUserId);
            ");
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

            migrationBuilder.Sql(@"
                IF COL_LENGTH('StateGstMasters', 'GstPercentage') IS NOT NULL
                    AND COL_LENGTH('StateGstMasters', 'GstRate') IS NULL
                BEGIN
                    EXEC sp_rename N'[StateGstMasters].[GstPercentage]', N'GstRate', N'COLUMN';
                END
            ");
        }
    }
}
