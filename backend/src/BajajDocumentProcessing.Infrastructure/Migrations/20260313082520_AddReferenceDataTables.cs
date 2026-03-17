using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BajajDocumentProcessing.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddReferenceDataTables : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "CostMasters",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ElementName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    ExpenseNature = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    UpdatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CostMasters", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "CostMasterStateRates",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    StateCode = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    ElementName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    RateValue = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                    RateType = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    UpdatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CostMasterStateRates", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "HsnMasters",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Code = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    UpdatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_HsnMasters", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "StateGstMasters",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    GstCode = table.Column<string>(type: "nvarchar(2)", maxLength: 2, nullable: false),
                    StateCode = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false),
                    StateName = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    UpdatedBy = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StateGstMasters", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_CostMasters_ElementName",
                table: "CostMasters",
                column: "ElementName",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_CostMasterStateRates_StateCode_ElementName",
                table: "CostMasterStateRates",
                columns: new[] { "StateCode", "ElementName" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_HsnMasters_Code",
                table: "HsnMasters",
                column: "Code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_StateGstMasters_GstCode",
                table: "StateGstMasters",
                column: "GstCode",
                unique: true);

            // Seed data
            SeedGstCodes(migrationBuilder);
            SeedHsnCodes(migrationBuilder);
            SeedCostElements(migrationBuilder);
            SeedStateRates(migrationBuilder);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CostMasters");

            migrationBuilder.DropTable(
                name: "CostMasterStateRates");

            migrationBuilder.DropTable(
                name: "HsnMasters");

            migrationBuilder.DropTable(
                name: "StateGstMasters");
        }

        private static void SeedGstCodes(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
INSERT INTO StateGstMasters (Id,GstCode,StateCode,StateName,IsActive,CreatedAt,IsDeleted) VALUES
(NEWID(),'01','JK','Jammu and Kashmir',1,GETUTCDATE(),0),(NEWID(),'02','HP','Himachal Pradesh',1,GETUTCDATE(),0),
(NEWID(),'03','PB','Punjab',1,GETUTCDATE(),0),(NEWID(),'04','CH','Chandigarh',1,GETUTCDATE(),0),
(NEWID(),'05','UK','Uttarakhand',1,GETUTCDATE(),0),(NEWID(),'06','HR','Haryana',1,GETUTCDATE(),0),
(NEWID(),'07','DL','Delhi',1,GETUTCDATE(),0),(NEWID(),'08','RJ','Rajasthan',1,GETUTCDATE(),0),
(NEWID(),'09','UP','Uttar Pradesh',1,GETUTCDATE(),0),(NEWID(),'10','BR','Bihar',1,GETUTCDATE(),0),
(NEWID(),'11','SK','Sikkim',1,GETUTCDATE(),0),(NEWID(),'12','AR','Arunachal Pradesh',1,GETUTCDATE(),0),
(NEWID(),'13','NL','Nagaland',1,GETUTCDATE(),0),(NEWID(),'14','MN','Manipur',1,GETUTCDATE(),0),
(NEWID(),'15','MZ','Mizoram',1,GETUTCDATE(),0),(NEWID(),'16','TR','Tripura',1,GETUTCDATE(),0),
(NEWID(),'17','ML','Meghalaya',1,GETUTCDATE(),0),(NEWID(),'18','AS','Assam',1,GETUTCDATE(),0),
(NEWID(),'19','WB','West Bengal',1,GETUTCDATE(),0),(NEWID(),'20','JH','Jharkhand',1,GETUTCDATE(),0),
(NEWID(),'21','OR','Odisha',1,GETUTCDATE(),0),(NEWID(),'22','CG','Chhattisgarh',1,GETUTCDATE(),0),
(NEWID(),'23','MP','Madhya Pradesh',1,GETUTCDATE(),0),(NEWID(),'24','GJ','Gujarat',1,GETUTCDATE(),0),
(NEWID(),'26','DD','Dadra and Nagar Haveli and Daman and Diu',1,GETUTCDATE(),0),
(NEWID(),'27','MH','Maharashtra',1,GETUTCDATE(),0),(NEWID(),'29','KA','Karnataka',1,GETUTCDATE(),0),
(NEWID(),'30','GA','Goa',1,GETUTCDATE(),0),(NEWID(),'31','LD','Lakshadweep',1,GETUTCDATE(),0),
(NEWID(),'32','KL','Kerala',1,GETUTCDATE(),0),(NEWID(),'33','TN','Tamil Nadu',1,GETUTCDATE(),0),
(NEWID(),'34','PY','Puducherry',1,GETUTCDATE(),0),(NEWID(),'35','AN','Andaman and Nicobar Islands',1,GETUTCDATE(),0),
(NEWID(),'36','TS','Telangana',1,GETUTCDATE(),0),(NEWID(),'37','AP','Andhra Pradesh',1,GETUTCDATE(),0),
(NEWID(),'38','LA','Ladakh',1,GETUTCDATE(),0);");
        }

        private static void SeedHsnCodes(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
INSERT INTO HsnMasters (Id,Code,Description,IsActive,CreatedAt,IsDeleted) VALUES
(NEWID(),'8703','Motor cars and other motor vehicles',1,GETUTCDATE(),0),
(NEWID(),'8704','Motor vehicles for transport of goods',1,GETUTCDATE(),0),
(NEWID(),'8711','Motorcycles and cycles with auxiliary motor',1,GETUTCDATE(),0),
(NEWID(),'8708','Parts and accessories of motor vehicles',1,GETUTCDATE(),0),
(NEWID(),'8714','Parts and accessories of motorcycles',1,GETUTCDATE(),0),
(NEWID(),'8716','Trailers and semi-trailers',1,GETUTCDATE(),0),
(NEWID(),'995411','Event management services',1,GETUTCDATE(),0),
(NEWID(),'995412','Event catering services',1,GETUTCDATE(),0),
(NEWID(),'995413','Event planning services',1,GETUTCDATE(),0),
(NEWID(),'995414','Exhibition services',1,GETUTCDATE(),0),
(NEWID(),'995415','Convention services',1,GETUTCDATE(),0),
(NEWID(),'996511','Rental of transport equipment',1,GETUTCDATE(),0),
(NEWID(),'996512','Rental of other machinery',1,GETUTCDATE(),0),
(NEWID(),'998511','Advisory and consultancy services',1,GETUTCDATE(),0),
(NEWID(),'998512','Management consulting services',1,GETUTCDATE(),0),
(NEWID(),'998513','Business consulting services',1,GETUTCDATE(),0);");
        }

        private static void SeedCostElements(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
INSERT INTO CostMasters (Id,ElementName,ExpenseNature,IsActive,CreatedAt,IsDeleted) VALUES
(NEWID(),'Vehicle Branding - Trial Vehicle','Fixed Cost',1,GETUTCDATE(),0),
(NEWID(),'POS - Standee','Fixed Cost',1,GETUTCDATE(),0),
(NEWID(),'POS - Banner','Fixed Cost',1,GETUTCDATE(),0),
(NEWID(),'POS - Gazebo Tent/Umbrella','Fixed Cost',1,GETUTCDATE(),0),
(NEWID(),'POS - Backdrop','Fixed Cost',1,GETUTCDATE(),0),
(NEWID(),'Transportation of POS','Fixed Cost',1,GETUTCDATE(),0),
(NEWID(),'Uniform for Agency manpower','Fixed Cost',1,GETUTCDATE(),0),
(NEWID(),'POS - Leaflet','Cost per Day',1,GETUTCDATE(),0),
(NEWID(),'Promoter','Cost per Day',1,GETUTCDATE(),0),
(NEWID(),'Promoter DA','Cost per Day',1,GETUTCDATE(),0),
(NEWID(),'Supervisor or/and Emcee','Cost per Day',1,GETUTCDATE(),0),
(NEWID(),'Supervisor or/and Emcee DA','Cost per Day',1,GETUTCDATE(),0),
(NEWID(),'Lodging & Boarding','Cost per Day',1,GETUTCDATE(),0),
(NEWID(),'Inter City Traveling - Agency manpower','Fixed Cost',1,GETUTCDATE(),0),
(NEWID(),'Inter City Travel','Cost per Day',1,GETUTCDATE(),0);");
        }

        private static void SeedStateRates(MigrationBuilder migrationBuilder)
        {
            void InsertRates(string state, string rates)
            {
                migrationBuilder.Sql($@"
INSERT INTO CostMasterStateRates (Id,StateCode,ElementName,RateValue,RateType,IsActive,CreatedAt,IsDeleted) VALUES
{rates}");
            }

            // Delhi: Supervisor=1000
            InsertRates("Delhi", @"
(NEWID(),'Delhi','POS Standee',1200,'Amount',1,GETUTCDATE(),0),(NEWID(),'Delhi','POS Banner',600,'Amount',1,GETUTCDATE(),0),
(NEWID(),'Delhi','POS Gazebo Tent',10000,'Amount',1,GETUTCDATE(),0),(NEWID(),'Delhi','POS Backdrop',6000,'Amount',1,GETUTCDATE(),0),
(NEWID(),'Delhi','POS Canopy/Umbrellas',4500,'Amount',1,GETUTCDATE(),0),(NEWID(),'Delhi','Uniform',350,'Amount',1,GETUTCDATE(),0),
(NEWID(),'Delhi','POS Leaflet',2.5,'Amount',1,GETUTCDATE(),0),(NEWID(),'Delhi','Lodging & Boarding',350,'Amount',1,GETUTCDATE(),0),
(NEWID(),'Delhi','Promoter',700,'Amount',1,GETUTCDATE(),0),(NEWID(),'Delhi','Promoter DA',200,'Amount',1,GETUTCDATE(),0),
(NEWID(),'Delhi','Supervisor',1000,'Amount',1,GETUTCDATE(),0),(NEWID(),'Delhi','Supervisor DA',200,'Amount',1,GETUTCDATE(),0),
(NEWID(),'Delhi','Portable PA System',400,'Amount',1,GETUTCDATE(),0),(NEWID(),'Delhi','Intra City Travel',100,'Amount',1,GETUTCDATE(),0),
(NEWID(),'Delhi','Agency Fee',10,'Percentage',1,GETUTCDATE(),0);");

            // UP & UTT, HAR, BIHAR, OD, WB: Promoter=700, Supervisor=900
            foreach (var state in new[] { "UP & UTT", "HAR", "BIHAR", "OD", "WB" })
            {
                InsertRates(state, $@"
(NEWID(),'{state}','POS Standee',1200,'Amount',1,GETUTCDATE(),0),(NEWID(),'{state}','POS Banner',600,'Amount',1,GETUTCDATE(),0),
(NEWID(),'{state}','POS Gazebo Tent',10000,'Amount',1,GETUTCDATE(),0),(NEWID(),'{state}','POS Backdrop',6000,'Amount',1,GETUTCDATE(),0),
(NEWID(),'{state}','POS Canopy/Umbrellas',4500,'Amount',1,GETUTCDATE(),0),(NEWID(),'{state}','Uniform',350,'Amount',1,GETUTCDATE(),0),
(NEWID(),'{state}','POS Leaflet',2.5,'Amount',1,GETUTCDATE(),0),(NEWID(),'{state}','Lodging & Boarding',350,'Amount',1,GETUTCDATE(),0),
(NEWID(),'{state}','Promoter',700,'Amount',1,GETUTCDATE(),0),(NEWID(),'{state}','Promoter DA',200,'Amount',1,GETUTCDATE(),0),
(NEWID(),'{state}','Supervisor',900,'Amount',1,GETUTCDATE(),0),(NEWID(),'{state}','Supervisor DA',200,'Amount',1,GETUTCDATE(),0),
(NEWID(),'{state}','Portable PA System',400,'Amount',1,GETUTCDATE(),0),(NEWID(),'{state}','Intra City Travel',100,'Amount',1,GETUTCDATE(),0),
(NEWID(),'{state}','Agency Fee',10,'Percentage',1,GETUTCDATE(),0);");
            }

            // RAJ, PUN, JH: Promoter=650, Supervisor=900
            foreach (var state in new[] { "RAJ", "PUN", "JH" })
            {
                InsertRates(state, $@"
(NEWID(),'{state}','POS Standee',1200,'Amount',1,GETUTCDATE(),0),(NEWID(),'{state}','POS Banner',600,'Amount',1,GETUTCDATE(),0),
(NEWID(),'{state}','POS Gazebo Tent',10000,'Amount',1,GETUTCDATE(),0),(NEWID(),'{state}','POS Backdrop',6000,'Amount',1,GETUTCDATE(),0),
(NEWID(),'{state}','POS Canopy/Umbrellas',4500,'Amount',1,GETUTCDATE(),0),(NEWID(),'{state}','Uniform',350,'Amount',1,GETUTCDATE(),0),
(NEWID(),'{state}','POS Leaflet',2.5,'Amount',1,GETUTCDATE(),0),(NEWID(),'{state}','Lodging & Boarding',350,'Amount',1,GETUTCDATE(),0),
(NEWID(),'{state}','Promoter',650,'Amount',1,GETUTCDATE(),0),(NEWID(),'{state}','Promoter DA',200,'Amount',1,GETUTCDATE(),0),
(NEWID(),'{state}','Supervisor',900,'Amount',1,GETUTCDATE(),0),(NEWID(),'{state}','Supervisor DA',200,'Amount',1,GETUTCDATE(),0),
(NEWID(),'{state}','Portable PA System',400,'Amount',1,GETUTCDATE(),0),(NEWID(),'{state}','Intra City Travel',100,'Amount',1,GETUTCDATE(),0),
(NEWID(),'{state}','Agency Fee',10,'Percentage',1,GETUTCDATE(),0);");
            }

            // J&K: Lodging=600, Promoter=900, no Supervisor/Supervisor DA
            migrationBuilder.Sql(@"
INSERT INTO CostMasterStateRates (Id,StateCode,ElementName,RateValue,RateType,IsActive,CreatedAt,IsDeleted) VALUES
(NEWID(),'J&K','POS Standee',1200,'Amount',1,GETUTCDATE(),0),(NEWID(),'J&K','POS Banner',600,'Amount',1,GETUTCDATE(),0),
(NEWID(),'J&K','POS Gazebo Tent',10000,'Amount',1,GETUTCDATE(),0),(NEWID(),'J&K','POS Backdrop',6000,'Amount',1,GETUTCDATE(),0),
(NEWID(),'J&K','POS Canopy/Umbrellas',4500,'Amount',1,GETUTCDATE(),0),(NEWID(),'J&K','Uniform',350,'Amount',1,GETUTCDATE(),0),
(NEWID(),'J&K','POS Leaflet',2.5,'Amount',1,GETUTCDATE(),0),(NEWID(),'J&K','Lodging & Boarding',600,'Amount',1,GETUTCDATE(),0),
(NEWID(),'J&K','Promoter',900,'Amount',1,GETUTCDATE(),0),(NEWID(),'J&K','Promoter DA',200,'Amount',1,GETUTCDATE(),0),
(NEWID(),'J&K','Portable PA System',400,'Amount',1,GETUTCDATE(),0),(NEWID(),'J&K','Intra City Travel',200,'Amount',1,GETUTCDATE(),0),
(NEWID(),'J&K','Agency Fee',10,'Percentage',1,GETUTCDATE(),0);");
        }
    }
}
