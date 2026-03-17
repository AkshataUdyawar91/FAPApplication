-- Drop GstCode column and add GstRate column
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_StateGstMasters_GstCode')
    DROP INDEX IX_StateGstMasters_GstCode ON StateGstMasters;

IF COL_LENGTH('StateGstMasters', 'GstCode') IS NOT NULL
    ALTER TABLE StateGstMasters DROP COLUMN GstCode;

IF COL_LENGTH('StateGstMasters', 'GstRate') IS NULL
    ALTER TABLE StateGstMasters ADD GstRate decimal(5,2) NOT NULL DEFAULT 18.00;

-- Seed all 36 states if empty, else update GstRate to 18
IF NOT EXISTS (SELECT 1 FROM StateGstMasters)
BEGIN
  INSERT INTO StateGstMasters (Id,StateCode,StateName,GstRate,IsActive,CreatedAt,IsDeleted) VALUES
  (NEWID(),'JK','Jammu and Kashmir',18.00,1,GETUTCDATE(),0),
  (NEWID(),'HP','Himachal Pradesh',18.00,1,GETUTCDATE(),0),
  (NEWID(),'PB','Punjab',18.00,1,GETUTCDATE(),0),
  (NEWID(),'CH','Chandigarh',18.00,1,GETUTCDATE(),0),
  (NEWID(),'UK','Uttarakhand',18.00,1,GETUTCDATE(),0),
  (NEWID(),'HR','Haryana',18.00,1,GETUTCDATE(),0),
  (NEWID(),'DL','Delhi',18.00,1,GETUTCDATE(),0),
  (NEWID(),'RJ','Rajasthan',18.00,1,GETUTCDATE(),0),
  (NEWID(),'UP','Uttar Pradesh',18.00,1,GETUTCDATE(),0),
  (NEWID(),'BR','Bihar',18.00,1,GETUTCDATE(),0),
  (NEWID(),'SK','Sikkim',18.00,1,GETUTCDATE(),0),
  (NEWID(),'AR','Arunachal Pradesh',18.00,1,GETUTCDATE(),0),
  (NEWID(),'NL','Nagaland',18.00,1,GETUTCDATE(),0),
  (NEWID(),'MN','Manipur',18.00,1,GETUTCDATE(),0),
  (NEWID(),'MZ','Mizoram',18.00,1,GETUTCDATE(),0),
  (NEWID(),'TR','Tripura',18.00,1,GETUTCDATE(),0),
  (NEWID(),'ML','Meghalaya',18.00,1,GETUTCDATE(),0),
  (NEWID(),'AS','Assam',18.00,1,GETUTCDATE(),0),
  (NEWID(),'WB','West Bengal',18.00,1,GETUTCDATE(),0),
  (NEWID(),'JH','Jharkhand',18.00,1,GETUTCDATE(),0),
  (NEWID(),'OR','Odisha',18.00,1,GETUTCDATE(),0),
  (NEWID(),'CG','Chhattisgarh',18.00,1,GETUTCDATE(),0),
  (NEWID(),'MP','Madhya Pradesh',18.00,1,GETUTCDATE(),0),
  (NEWID(),'GJ','Gujarat',18.00,1,GETUTCDATE(),0),
  (NEWID(),'DD','Dadra and Nagar Haveli and Daman and Diu',18.00,1,GETUTCDATE(),0),
  (NEWID(),'MH','Maharashtra',18.00,1,GETUTCDATE(),0),
  (NEWID(),'KA','Karnataka',18.00,1,GETUTCDATE(),0),
  (NEWID(),'GA','Goa',18.00,1,GETUTCDATE(),0),
  (NEWID(),'LD','Lakshadweep',18.00,1,GETUTCDATE(),0),
  (NEWID(),'KL','Kerala',18.00,1,GETUTCDATE(),0),
  (NEWID(),'TN','Tamil Nadu',18.00,1,GETUTCDATE(),0),
  (NEWID(),'PY','Puducherry',18.00,1,GETUTCDATE(),0),
  (NEWID(),'AN','Andaman and Nicobar Islands',18.00,1,GETUTCDATE(),0),
  (NEWID(),'TS','Telangana',18.00,1,GETUTCDATE(),0),
  (NEWID(),'AP','Andhra Pradesh',18.00,1,GETUTCDATE(),0),
  (NEWID(),'LA','Ladakh',18.00,1,GETUTCDATE(),0);
END
ELSE
  UPDATE StateGstMasters SET GstRate = 18.00;

-- Verify
SELECT StateCode, StateName, GstRate FROM StateGstMasters ORDER BY StateName;
