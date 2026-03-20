-- Fix corrupted migration state
-- Step 1: Create missing StateGstMasters table (from AddReferenceDataTables migration)
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'StateGstMasters')
BEGIN
    CREATE TABLE StateGstMasters (
        Id uniqueidentifier NOT NULL,
        GstCode nvarchar(10) NOT NULL,
        StateCode nvarchar(10) NOT NULL,
        StateName nvarchar(100) NOT NULL,
        IsActive bit NOT NULL DEFAULT 1,
        CreatedAt datetime2 NOT NULL,
        UpdatedAt datetime2 NULL,
        CreatedBy nvarchar(max) NULL,
        UpdatedBy nvarchar(max) NULL,
        IsDeleted bit NOT NULL DEFAULT 0,
        CONSTRAINT PK_StateGstMasters PRIMARY KEY (Id)
    );
    CREATE UNIQUE INDEX IX_StateGstMasters_GstCode ON StateGstMasters (GstCode);
    PRINT 'Created StateGstMasters table';
END
ELSE
    PRINT 'StateGstMasters already exists';
GO

-- Step 2: Create missing CostMasters table
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CostMasters')
BEGIN
    CREATE TABLE CostMasters (
        Id uniqueidentifier NOT NULL,
        CostType nvarchar(100) NOT NULL,
        Description nvarchar(500) NULL,
        IsActive bit NOT NULL DEFAULT 1,
        CreatedAt datetime2 NOT NULL,
        UpdatedAt datetime2 NULL,
        CreatedBy nvarchar(max) NULL,
        UpdatedBy nvarchar(max) NULL,
        IsDeleted bit NOT NULL DEFAULT 0,
        CONSTRAINT PK_CostMasters PRIMARY KEY (Id)
    );
    PRINT 'Created CostMasters table';
END
GO

-- Step 3: Create missing CostMasterStateRates table
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CostMasterStateRates')
BEGIN
    CREATE TABLE CostMasterStateRates (
        Id uniqueidentifier NOT NULL,
        CostMasterId uniqueidentifier NOT NULL,
        State nvarchar(100) NOT NULL,
        Rate decimal(18,2) NOT NULL,
        IsActive bit NOT NULL DEFAULT 1,
        CreatedAt datetime2 NOT NULL,
        UpdatedAt datetime2 NULL,
        CreatedBy nvarchar(max) NULL,
        UpdatedBy nvarchar(max) NULL,
        IsDeleted bit NOT NULL DEFAULT 0,
        CONSTRAINT PK_CostMasterStateRates PRIMARY KEY (Id)
    );
    PRINT 'Created CostMasterStateRates table';
END
GO

-- Step 4: Create missing HsnMasters table
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'HsnMasters')
BEGIN
    CREATE TABLE HsnMasters (
        Id uniqueidentifier NOT NULL,
        HsnCode nvarchar(20) NOT NULL,
        Description nvarchar(500) NULL,
        GstRate decimal(5,2) NOT NULL,
        IsActive bit NOT NULL DEFAULT 1,
        CreatedAt datetime2 NOT NULL,
        UpdatedAt datetime2 NULL,
        CreatedBy nvarchar(max) NULL,
        UpdatedBy nvarchar(max) NULL,
        IsDeleted bit NOT NULL DEFAULT 0,
        CONSTRAINT PK_HsnMasters PRIMARY KEY (Id)
    );
    CREATE UNIQUE INDEX IX_HsnMasters_HsnCode ON HsnMasters (HsnCode);
    PRINT 'Created HsnMasters table';
END
GO

-- Step 5: Add missing columns to DocumentPackages
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'ActivityState')
BEGIN
    ALTER TABLE DocumentPackages ADD ActivityState nvarchar(100) NULL;
    PRINT 'Added ActivityState column';
END
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'AssignedCircleHeadUserId')
BEGIN
    ALTER TABLE DocumentPackages ADD AssignedCircleHeadUserId uniqueidentifier NULL;
    PRINT 'Added AssignedCircleHeadUserId column';
END
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'CurrentStep')
BEGIN
    ALTER TABLE DocumentPackages ADD CurrentStep int NOT NULL DEFAULT 0;
    PRINT 'Added CurrentStep column';
END
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'SelectedPOId')
BEGIN
    ALTER TABLE DocumentPackages ADD SelectedPOId uniqueidentifier NULL;
    PRINT 'Added SelectedPOId column';
END
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'SubmissionNumber')
BEGIN
    ALTER TABLE DocumentPackages ADD SubmissionNumber nvarchar(20) NULL;
    PRINT 'Added SubmissionNumber column';
END
GO

-- Step 6: Add missing columns to POs
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'POs' AND COLUMN_NAME = 'POStatus')
BEGIN
    ALTER TABLE POs ADD POStatus nvarchar(50) NULL;
    PRINT 'Added POStatus column';
END
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'POs' AND COLUMN_NAME = 'RemainingBalance')
BEGIN
    ALTER TABLE POs ADD RemainingBalance decimal(18,2) NULL;
    PRINT 'Added RemainingBalance column';
END
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'POs' AND COLUMN_NAME = 'VendorCode')
BEGIN
    ALTER TABLE POs ADD VendorCode nvarchar(50) NULL;
    PRINT 'Added VendorCode column';
END
GO

-- Step 7: Add missing column to ValidationResults
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'ValidationResults' AND COLUMN_NAME = 'RuleResultsJson')
BEGIN
    ALTER TABLE ValidationResults ADD RuleResultsJson nvarchar(max) NULL;
    PRINT 'Added RuleResultsJson column';
END
GO

-- Step 8: Create StateMappings table
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'StateMappings')
BEGIN
    CREATE TABLE StateMappings (
        Id uniqueidentifier NOT NULL,
        State nvarchar(100) NOT NULL,
        DealerCode nvarchar(50) NOT NULL,
        DealerName nvarchar(200) NOT NULL,
        City nvarchar(100) NULL,
        CircleHeadUserId uniqueidentifier NULL,
        IsActive bit NOT NULL DEFAULT 1,
        CreatedAt datetime2 NOT NULL,
        UpdatedAt datetime2 NULL,
        CreatedBy nvarchar(max) NULL,
        UpdatedBy nvarchar(max) NULL,
        IsDeleted bit NOT NULL DEFAULT 0,
        CONSTRAINT PK_StateMappings PRIMARY KEY (Id)
    );
    CREATE INDEX IX_StateMappings_DealerCode ON StateMappings (DealerCode);
    CREATE INDEX IX_StateMappings_State ON StateMappings (State);
    CREATE INDEX IX_StateMappings_State_IsActive ON StateMappings (State, IsActive);
    PRINT 'Created StateMappings table';
END
GO

-- Step 9: Create SubmissionSequences table
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'SubmissionSequences')
BEGIN
    CREATE TABLE SubmissionSequences (
        Year int NOT NULL,
        LastNumber int NOT NULL DEFAULT 0,
        CONSTRAINT PK_SubmissionSequences PRIMARY KEY (Year)
    );
    PRINT 'Created SubmissionSequences table';
END
GO

-- Step 10: Seed StateGstMasters data
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
    PRINT 'Seeded StateGstMasters data';
END
GO
