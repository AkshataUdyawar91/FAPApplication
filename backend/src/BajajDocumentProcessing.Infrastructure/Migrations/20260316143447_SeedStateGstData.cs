using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BajajDocumentProcessing.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class SeedStateGstData : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "RuleResultsJson",
                table: "ValidationResults",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "POStatus",
                table: "POs",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "RemainingBalance",
                table: "POs",
                type: "decimal(18,2)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "VendorCode",
                table: "POs",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ActivityState",
                table: "DocumentPackages",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "AssignedCircleHeadUserId",
                table: "DocumentPackages",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "CurrentStep",
                table: "DocumentPackages",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<Guid>(
                name: "SelectedPOId",
                table: "DocumentPackages",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SubmissionNumber",
                table: "DocumentPackages",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "StateMappings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    State = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    DealerCode = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    DealerName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    City = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    CircleHeadUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    IsActive = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    UpdatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false, defaultValue: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StateMappings", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "SubmissionSequences",
                columns: table => new
                {
                    Year = table.Column<int>(type: "int", nullable: false),
                    LastNumber = table.Column<int>(type: "int", nullable: false, defaultValue: 0)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SubmissionSequences", x => x.Year);
                });

            migrationBuilder.CreateIndex(
                name: "IX_StateMappings_DealerCode",
                table: "StateMappings",
                column: "DealerCode");

            migrationBuilder.CreateIndex(
                name: "IX_StateMappings_State",
                table: "StateMappings",
                column: "State");

            migrationBuilder.CreateIndex(
                name: "IX_StateMappings_State_IsActive",
                table: "StateMappings",
                columns: new[] { "State", "IsActive" });

            // Seed StateGstMasters if empty
            migrationBuilder.Sql(@"
IF NOT EXISTS (SELECT 1 FROM StateGstMasters)
BEGIN
INSERT INTO StateGstMasters (Id,GstCode,StateCode,StateName,IsActive,CreatedAt,IsDeleted) VALUES
(NEWID(),'01','JK','Jammu and Kashmir',1,GETUTCDATE(),0),
(NEWID(),'02','HP','Himachal Pradesh',1,GETUTCDATE(),0),
(NEWID(),'03','PB','Punjab',1,GETUTCDATE(),0),
(NEWID(),'04','CH','Chandigarh',1,GETUTCDATE(),0),
(NEWID(),'05','UK','Uttarakhand',1,GETUTCDATE(),0),
(NEWID(),'06','HR','Haryana',1,GETUTCDATE(),0),
(NEWID(),'07','DL','Delhi',1,GETUTCDATE(),0),
(NEWID(),'08','RJ','Rajasthan',1,GETUTCDATE(),0),
(NEWID(),'09','UP','Uttar Pradesh',1,GETUTCDATE(),0),
(NEWID(),'10','BR','Bihar',1,GETUTCDATE(),0),
(NEWID(),'11','SK','Sikkim',1,GETUTCDATE(),0),
(NEWID(),'12','AR','Arunachal Pradesh',1,GETUTCDATE(),0),
(NEWID(),'13','NL','Nagaland',1,GETUTCDATE(),0),
(NEWID(),'14','MN','Manipur',1,GETUTCDATE(),0),
(NEWID(),'15','MZ','Mizoram',1,GETUTCDATE(),0),
(NEWID(),'16','TR','Tripura',1,GETUTCDATE(),0),
(NEWID(),'17','ML','Meghalaya',1,GETUTCDATE(),0),
(NEWID(),'18','AS','Assam',1,GETUTCDATE(),0),
(NEWID(),'19','WB','West Bengal',1,GETUTCDATE(),0),
(NEWID(),'20','JH','Jharkhand',1,GETUTCDATE(),0),
(NEWID(),'21','OR','Odisha',1,GETUTCDATE(),0),
(NEWID(),'22','CG','Chhattisgarh',1,GETUTCDATE(),0),
(NEWID(),'23','MP','Madhya Pradesh',1,GETUTCDATE(),0),
(NEWID(),'24','GJ','Gujarat',1,GETUTCDATE(),0),
(NEWID(),'26','DD','Dadra and Nagar Haveli and Daman and Diu',1,GETUTCDATE(),0),
(NEWID(),'27','MH','Maharashtra',1,GETUTCDATE(),0),
(NEWID(),'29','KA','Karnataka',1,GETUTCDATE(),0),
(NEWID(),'30','GA','Goa',1,GETUTCDATE(),0),
(NEWID(),'31','LD','Lakshadweep',1,GETUTCDATE(),0),
(NEWID(),'32','KL','Kerala',1,GETUTCDATE(),0),
(NEWID(),'33','TN','Tamil Nadu',1,GETUTCDATE(),0),
(NEWID(),'34','PY','Puducherry',1,GETUTCDATE(),0),
(NEWID(),'35','AN','Andaman and Nicobar Islands',1,GETUTCDATE(),0),
(NEWID(),'36','TS','Telangana',1,GETUTCDATE(),0),
(NEWID(),'37','AP','Andhra Pradesh',1,GETUTCDATE(),0),
(NEWID(),'38','LA','Ladakh',1,GETUTCDATE(),0);
END");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "StateMappings");

            migrationBuilder.DropTable(
                name: "SubmissionSequences");

            migrationBuilder.DropColumn(
                name: "RuleResultsJson",
                table: "ValidationResults");

            migrationBuilder.DropColumn(
                name: "POStatus",
                table: "POs");

            migrationBuilder.DropColumn(
                name: "RemainingBalance",
                table: "POs");

            migrationBuilder.DropColumn(
                name: "VendorCode",
                table: "POs");

            migrationBuilder.DropColumn(
                name: "ActivityState",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "AssignedCircleHeadUserId",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "CurrentStep",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "SelectedPOId",
                table: "DocumentPackages");

            migrationBuilder.DropColumn(
                name: "SubmissionNumber",
                table: "DocumentPackages");
        }
    }
}
