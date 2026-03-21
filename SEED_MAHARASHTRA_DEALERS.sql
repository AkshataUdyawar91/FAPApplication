-- =============================================
-- Seed: Maharashtra Dealers — same dealer names across multiple cities
-- Idempotent — skips existing dealer codes
-- Run on: localhost\SQLEXPRESS / BajajFAP_Shubhankar
-- =============================================
SET NOCOUNT ON;

-- First clean up old seed data so we can re-seed with new codes
DELETE FROM Dealers WHERE DealerCode LIKE 'DL-MH-%' OR DealerCode LIKE 'DL-PN-%';

DECLARE @inserted INT = 0;

-- Sharma Motors — present in Mumbai, Pune, Nagpur
IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-101')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-101', 'Sharma Motors', 'Maharashtra', 'Mumbai', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-102')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-102', 'Sharma Motors', 'Maharashtra', 'Pune', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-103')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-103', 'Sharma Motors', 'Maharashtra', 'Nagpur', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

-- Patil Auto — present in Pune, Nashik, Kolhapur
IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-104')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-104', 'Patil Auto', 'Maharashtra', 'Pune', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-105')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-105', 'Patil Auto', 'Maharashtra', 'Nashik', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-106')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-106', 'Patil Auto', 'Maharashtra', 'Kolhapur', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

-- Deshmukh Bajaj — present in Mumbai, Thane, Navi Mumbai, Sambhaji Nagar
IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-107')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-107', 'Deshmukh Bajaj', 'Maharashtra', 'Mumbai', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-108')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-108', 'Deshmukh Bajaj', 'Maharashtra', 'Thane', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-109')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-109', 'Deshmukh Bajaj', 'Maharashtra', 'Navi Mumbai', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-110')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-110', 'Deshmukh Bajaj', 'Maharashtra', 'Sambhaji Nagar', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

-- Kulkarni Two Wheelers — present in Pune, Solapur, Satara
IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-111')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-111', 'Kulkarni Two Wheelers', 'Maharashtra', 'Pune', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-112')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-112', 'Kulkarni Two Wheelers', 'Maharashtra', 'Solapur', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-113')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-113', 'Kulkarni Two Wheelers', 'Maharashtra', 'Satara', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

-- Jadhav Motors — present in Nagpur, Amravati, Chandrapur, Jalgaon
IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-114')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-114', 'Jadhav Motors', 'Maharashtra', 'Nagpur', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-115')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-115', 'Jadhav Motors', 'Maharashtra', 'Amravati', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-116')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-116', 'Jadhav Motors', 'Maharashtra', 'Chandrapur', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-117')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-117', 'Jadhav Motors', 'Maharashtra', 'Jalgaon', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

-- Marathe Automobiles — present in Mumbai, Pune, Nashik, Latur
IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-118')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-118', 'Marathe Automobiles', 'Maharashtra', 'Mumbai', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-119')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-119', 'Marathe Automobiles', 'Maharashtra', 'Pune', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-120')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-120', 'Marathe Automobiles', 'Maharashtra', 'Nashik', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-121')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-121', 'Marathe Automobiles', 'Maharashtra', 'Latur', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

-- Shinde Bajaj World — present in Thane, Panvel, Ratnagiri
IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-122')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-122', 'Shinde Bajaj World', 'Maharashtra', 'Thane', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-123')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-123', 'Shinde Bajaj World', 'Maharashtra', 'Panvel', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-124')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-124', 'Shinde Bajaj World', 'Maharashtra', 'Ratnagiri', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

-- Gaikwad Rides — present in Kolhapur, Sangli, Ahilya Nagar
IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-125')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-125', 'Gaikwad Rides', 'Maharashtra', 'Kolhapur', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-126')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-126', 'Gaikwad Rides', 'Maharashtra', 'Sangli', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

IF NOT EXISTS (SELECT 1 FROM Dealers WHERE DealerCode = 'DL-MH-127')
BEGIN INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt) VALUES (NEWID(), 'DL-MH-127', 'Gaikwad Rides', 'Maharashtra', 'Ahilya Nagar', 1, 0, GETUTCDATE()); SET @inserted = @inserted + 1; END

PRINT CAST(@inserted AS NVARCHAR) + ' Maharashtra dealer(s) inserted.';
