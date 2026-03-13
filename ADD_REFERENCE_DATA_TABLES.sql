-- =============================================
-- Migration: Add Reference Data Tables (StateGstMasters, HsnMasters, CostMasters, CostMasterStateRates)
-- Date: 2026-03-13
-- Purpose: Create reference data tables and seed with initial data
-- =============================================
BEGIN TRANSACTION;
BEGIN TRY

-- Create StateGstMasters
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'StateGstMasters')
BEGIN
    CREATE TABLE StateGstMasters (
        Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        GstCode NVARCHAR(2) NOT NULL,
        StateCode NVARCHAR(10) NOT NULL,
        StateName NVARCHAR(100) NOT NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt DATETIME2 NULL,
        CreatedBy NVARCHAR(MAX) NULL,
        UpdatedBy NVARCHAR(MAX) NULL,
        IsDeleted BIT NOT NULL DEFAULT 0
    );
    CREATE UNIQUE INDEX IX_StateGstMasters_GstCode ON StateGstMasters(GstCode);
    PRINT 'Created StateGstMasters table';
END

-- Create HsnMasters
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'HsnMasters')
BEGIN
    CREATE TABLE HsnMasters (
        Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        Code NVARCHAR(20) NOT NULL,
        Description NVARCHAR(500) NOT NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt DATETIME2 NULL,
        CreatedBy NVARCHAR(MAX) NULL,
        UpdatedBy NVARCHAR(MAX) NULL,
        IsDeleted BIT NOT NULL DEFAULT 0
    );
    CREATE UNIQUE INDEX IX_HsnMasters_Code ON HsnMasters(Code);
    PRINT 'Created HsnMasters table';
END

-- Create CostMasters
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CostMasters')
BEGIN
    CREATE TABLE CostMasters (
        Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        ElementName NVARCHAR(200) NOT NULL,
        ExpenseNature NVARCHAR(50) NOT NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt DATETIME2 NULL,
        CreatedBy NVARCHAR(MAX) NULL,
        UpdatedBy NVARCHAR(MAX) NULL,
        IsDeleted BIT NOT NULL DEFAULT 0
    );
    CREATE UNIQUE INDEX IX_CostMasters_ElementName ON CostMasters(ElementName);
    PRINT 'Created CostMasters table';
END

-- Create CostMasterStateRates
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CostMasterStateRates')
BEGIN
    CREATE TABLE CostMasterStateRates (
        Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        StateCode NVARCHAR(50) NOT NULL,
        ElementName NVARCHAR(200) NOT NULL,
        RateValue DECIMAL(18,2) NOT NULL,
        RateType NVARCHAR(20) NOT NULL DEFAULT 'Amount',
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt DATETIME2 NULL,
        CreatedBy NVARCHAR(MAX) NULL,
        UpdatedBy NVARCHAR(MAX) NULL,
        IsDeleted BIT NOT NULL DEFAULT 0
    );
    CREATE UNIQUE INDEX IX_CostMasterStateRates_StateCode_ElementName ON CostMasterStateRates(StateCode, ElementName);
    PRINT 'Created CostMasterStateRates table';
END

-- Seed GST State Codes
IF NOT EXISTS (SELECT 1 FROM StateGstMasters)
BEGIN
    INSERT INTO StateGstMasters (Id, GstCode, StateCode, StateName, IsActive, CreatedAt, IsDeleted) VALUES
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
    PRINT 'Seeded StateGstMasters';
END

-- Seed HSN/SAC Codes
IF NOT EXISTS (SELECT 1 FROM HsnMasters)
BEGIN
    INSERT INTO HsnMasters (Id, Code, Description, IsActive, CreatedAt, IsDeleted) VALUES
    (NEWID(),'8703','Motor cars and other motor vehicles for transport of persons',1,GETUTCDATE(),0),
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
    (NEWID(),'998513','Business consulting services',1,GETUTCDATE(),0);
    PRINT 'Seeded HsnMasters';
END

-- Seed Cost Elements
IF NOT EXISTS (SELECT 1 FROM CostMasters)
BEGIN
    INSERT INTO CostMasters (Id, ElementName, ExpenseNature, IsActive, CreatedAt, IsDeleted) VALUES
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
    (NEWID(),'Inter City Travel','Cost per Day',1,GETUTCDATE(),0);
    PRINT 'Seeded CostMasters';
END

-- Seed State Rates
IF NOT EXISTS (SELECT 1 FROM CostMasterStateRates)
BEGIN
    -- Delhi
    INSERT INTO CostMasterStateRates (Id,StateCode,ElementName,RateValue,RateType,IsActive,CreatedAt,IsDeleted) VALUES
    (NEWID(),'Delhi','POS Standee',1200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'Delhi','POS Banner',600,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'Delhi','POS Gazebo Tent',10000,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'Delhi','POS Backdrop',6000,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'Delhi','POS Canopy/Umbrellas',4500,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'Delhi','Uniform',350,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'Delhi','POS Leaflet',2.5,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'Delhi','Lodging & Boarding',350,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'Delhi','Promoter',700,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'Delhi','Promoter DA',200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'Delhi','Supervisor',1000,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'Delhi','Supervisor DA',200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'Delhi','Portable PA System',400,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'Delhi','Intra City Travel',100,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'Delhi','Agency Fee',10,'Percentage',1,GETUTCDATE(),0);

    -- UP & UTT
    INSERT INTO CostMasterStateRates (Id,StateCode,ElementName,RateValue,RateType,IsActive,CreatedAt,IsDeleted) VALUES
    (NEWID(),'UP & UTT','POS Standee',1200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'UP & UTT','POS Banner',600,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'UP & UTT','POS Gazebo Tent',10000,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'UP & UTT','POS Backdrop',6000,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'UP & UTT','POS Canopy/Umbrellas',4500,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'UP & UTT','Uniform',350,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'UP & UTT','POS Leaflet',2.5,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'UP & UTT','Lodging & Boarding',350,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'UP & UTT','Promoter',700,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'UP & UTT','Promoter DA',200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'UP & UTT','Supervisor',900,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'UP & UTT','Supervisor DA',200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'UP & UTT','Portable PA System',400,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'UP & UTT','Intra City Travel',100,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'UP & UTT','Agency Fee',10,'Percentage',1,GETUTCDATE(),0);

    -- HAR
    INSERT INTO CostMasterStateRates (Id,StateCode,ElementName,RateValue,RateType,IsActive,CreatedAt,IsDeleted) VALUES
    (NEWID(),'HAR','POS Standee',1200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'HAR','POS Banner',600,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'HAR','POS Gazebo Tent',10000,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'HAR','POS Backdrop',6000,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'HAR','POS Canopy/Umbrellas',4500,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'HAR','Uniform',350,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'HAR','POS Leaflet',2.5,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'HAR','Lodging & Boarding',350,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'HAR','Promoter',700,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'HAR','Promoter DA',200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'HAR','Supervisor',900,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'HAR','Supervisor DA',200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'HAR','Portable PA System',400,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'HAR','Intra City Travel',100,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'HAR','Agency Fee',10,'Percentage',1,GETUTCDATE(),0);

    -- RAJ
    INSERT INTO CostMasterStateRates (Id,StateCode,ElementName,RateValue,RateType,IsActive,CreatedAt,IsDeleted) VALUES
    (NEWID(),'RAJ','POS Standee',1200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'RAJ','POS Banner',600,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'RAJ','POS Gazebo Tent',10000,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'RAJ','POS Backdrop',6000,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'RAJ','POS Canopy/Umbrellas',4500,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'RAJ','Uniform',350,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'RAJ','POS Leaflet',2.5,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'RAJ','Lodging & Boarding',350,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'RAJ','Promoter',650,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'RAJ','Promoter DA',200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'RAJ','Supervisor',900,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'RAJ','Supervisor DA',200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'RAJ','Portable PA System',400,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'RAJ','Intra City Travel',100,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'RAJ','Agency Fee',10,'Percentage',1,GETUTCDATE(),0);

    -- PUN
    INSERT INTO CostMasterStateRates (Id,StateCode,ElementName,RateValue,RateType,IsActive,CreatedAt,IsDeleted) VALUES
    (NEWID(),'PUN','POS Standee',1200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'PUN','POS Banner',600,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'PUN','POS Gazebo Tent',10000,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'PUN','POS Backdrop',6000,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'PUN','POS Canopy/Umbrellas',4500,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'PUN','Uniform',350,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'PUN','POS Leaflet',2.5,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'PUN','Lodging & Boarding',350,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'PUN','Promoter',650,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'PUN','Promoter DA',200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'PUN','Supervisor',900,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'PUN','Supervisor DA',200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'PUN','Portable PA System',400,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'PUN','Intra City Travel',100,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'PUN','Agency Fee',10,'Percentage',1,GETUTCDATE(),0);

    -- J&K (Supervisor and Supervisor DA not applicable)
    INSERT INTO CostMasterStateRates (Id,StateCode,ElementName,RateValue,RateType,IsActive,CreatedAt,IsDeleted) VALUES
    (NEWID(),'J&K','POS Standee',1200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'J&K','POS Banner',600,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'J&K','POS Gazebo Tent',10000,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'J&K','POS Backdrop',6000,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'J&K','POS Canopy/Umbrellas',4500,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'J&K','Uniform',350,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'J&K','POS Leaflet',2.5,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'J&K','Lodging & Boarding',600,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'J&K','Promoter',900,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'J&K','Promoter DA',200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'J&K','Portable PA System',400,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'J&K','Intra City Travel',200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'J&K','Agency Fee',10,'Percentage',1,GETUTCDATE(),0);

    -- BIHAR
    INSERT INTO CostMasterStateRates (Id,StateCode,ElementName,RateValue,RateType,IsActive,CreatedAt,IsDeleted) VALUES
    (NEWID(),'BIHAR','POS Standee',1200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'BIHAR','POS Banner',600,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'BIHAR','POS Gazebo Tent',10000,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'BIHAR','POS Backdrop',6000,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'BIHAR','POS Canopy/Umbrellas',4500,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'BIHAR','Uniform',350,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'BIHAR','POS Leaflet',2.5,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'BIHAR','Lodging & Boarding',350,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'BIHAR','Promoter',700,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'BIHAR','Promoter DA',200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'BIHAR','Supervisor',900,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'BIHAR','Supervisor DA',200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'BIHAR','Portable PA System',400,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'BIHAR','Intra City Travel',100,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'BIHAR','Agency Fee',10,'Percentage',1,GETUTCDATE(),0);

    -- JH
    INSERT INTO CostMasterStateRates (Id,StateCode,ElementName,RateValue,RateType,IsActive,CreatedAt,IsDeleted) VALUES
    (NEWID(),'JH','POS Standee',1200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'JH','POS Banner',600,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'JH','POS Gazebo Tent',10000,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'JH','POS Backdrop',6000,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'JH','POS Canopy/Umbrellas',4500,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'JH','Uniform',350,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'JH','POS Leaflet',2.5,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'JH','Lodging & Boarding',350,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'JH','Promoter',650,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'JH','Promoter DA',200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'JH','Supervisor',900,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'JH','Supervisor DA',200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'JH','Portable PA System',400,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'JH','Intra City Travel',100,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'JH','Agency Fee',10,'Percentage',1,GETUTCDATE(),0);

    -- OD
    INSERT INTO CostMasterStateRates (Id,StateCode,ElementName,RateValue,RateType,IsActive,CreatedAt,IsDeleted) VALUES
    (NEWID(),'OD','POS Standee',1200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'OD','POS Banner',600,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'OD','POS Gazebo Tent',10000,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'OD','POS Backdrop',6000,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'OD','POS Canopy/Umbrellas',4500,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'OD','Uniform',350,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'OD','POS Leaflet',2.5,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'OD','Lodging & Boarding',350,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'OD','Promoter',700,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'OD','Promoter DA',200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'OD','Supervisor',900,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'OD','Supervisor DA',200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'OD','Portable PA System',400,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'OD','Intra City Travel',100,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'OD','Agency Fee',10,'Percentage',1,GETUTCDATE(),0);

    -- WB
    INSERT INTO CostMasterStateRates (Id,StateCode,ElementName,RateValue,RateType,IsActive,CreatedAt,IsDeleted) VALUES
    (NEWID(),'WB','POS Standee',1200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'WB','POS Banner',600,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'WB','POS Gazebo Tent',10000,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'WB','POS Backdrop',6000,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'WB','POS Canopy/Umbrellas',4500,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'WB','Uniform',350,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'WB','POS Leaflet',2.5,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'WB','Lodging & Boarding',350,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'WB','Promoter',700,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'WB','Promoter DA',200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'WB','Supervisor',900,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'WB','Supervisor DA',200,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'WB','Portable PA System',400,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'WB','Intra City Travel',100,'Amount',1,GETUTCDATE(),0),
    (NEWID(),'WB','Agency Fee',10,'Percentage',1,GETUTCDATE(),0);

    PRINT 'Seeded CostMasterStateRates';
END

-- Record in EF migrations history
IF NOT EXISTS (SELECT 1 FROM __EFMigrationsHistory WHERE MigrationId = '20260313100000_AddReferenceDataTables')
BEGIN
    INSERT INTO __EFMigrationsHistory (MigrationId, ProductVersion) VALUES ('20260313100000_AddReferenceDataTables', '8.0.0');
END

COMMIT TRANSACTION;
PRINT 'Migration completed successfully';
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    PRINT 'Migration failed: ' + ERROR_MESSAGE();
    THROW;
END CATCH
