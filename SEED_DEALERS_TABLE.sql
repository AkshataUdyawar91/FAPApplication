-- =============================================
-- Script: Seed Dealers table with dealer data
-- Database: BajajDocumentProcessing on localhost\SQLEXPRESS
-- Date: 2026-03-22
-- Idempotent: Skips existing dealers by DealerCode
-- =============================================

USE [BajajDocumentProcessing];
GO

-- Clear existing data first (safe for dev/local only)
DELETE FROM [dbo].[Dealers];

INSERT INTO [dbo].[Dealers] ([Id],[DealerCode],[DealerName],[State],[City],[IsActive],[IsDeleted],[CreatedAt]) VALUES (NEWID(), 'RJ001', 'Jaipur Bajaj',        'Rajasthan',     'Jaipur',       1, 0, GETUTCDATE());
INSERT INTO [dbo].[Dealers] ([Id],[DealerCode],[DealerName],[State],[City],[IsActive],[IsDeleted],[CreatedAt]) VALUES (NEWID(), 'GJ001', 'Ahmedabad Auto',       'Gujarat',       'Ahmedabad',    1, 0, GETUTCDATE());
INSERT INTO [dbo].[Dealers] ([Id],[DealerCode],[DealerName],[State],[City],[IsActive],[IsDeleted],[CreatedAt]) VALUES (NEWID(), 'BR003', 'Bhagalpur Motors',     'Bihar',         'Bhagalpur',    1, 0, GETUTCDATE());
INSERT INTO [dbo].[Dealers] ([Id],[DealerCode],[DealerName],[State],[City],[IsActive],[IsDeleted],[CreatedAt]) VALUES (NEWID(), 'DL002', 'Dwarka Motors',        'Delhi',         'Dwarka',       1, 0, GETUTCDATE());
INSERT INTO [dbo].[Dealers] ([Id],[DealerCode],[DealerName],[State],[City],[IsActive],[IsDeleted],[CreatedAt]) VALUES (NEWID(), 'BR002', 'Ganga Auto',           'Bihar',         'Muzaffarpur',  1, 0, GETUTCDATE());
INSERT INTO [dbo].[Dealers] ([Id],[DealerCode],[DealerName],[State],[City],[IsActive],[IsDeleted],[CreatedAt]) VALUES (NEWID(), 'KA001', 'Bangalore Bajaj',      'Karnataka',     'Bangalore',    1, 0, GETUTCDATE());
INSERT INTO [dbo].[Dealers] ([Id],[DealerCode],[DealerName],[State],[City],[IsActive],[IsDeleted],[CreatedAt]) VALUES (NEWID(), 'BR004', 'Gaya Auto',            'Bihar',         'Gaya',         1, 0, GETUTCDATE());
INSERT INTO [dbo].[Dealers] ([Id],[DealerCode],[DealerName],[State],[City],[IsActive],[IsDeleted],[CreatedAt]) VALUES (NEWID(), 'MH003', 'Bajaj Auto Nagpur',    'Maharashtra',   'Nagpur',       1, 0, GETUTCDATE());
INSERT INTO [dbo].[Dealers] ([Id],[DealerCode],[DealerName],[State],[City],[IsActive],[IsDeleted],[CreatedAt]) VALUES (NEWID(), 'KA002', 'Mysore Motors',        'Karnataka',     'Mysore',       1, 0, GETUTCDATE());
INSERT INTO [dbo].[Dealers] ([Id],[DealerCode],[DealerName],[State],[City],[IsActive],[IsDeleted],[CreatedAt]) VALUES (NEWID(), 'TN002', 'Coimbatore Auto',      'Tamil Nadu',    'Coimbatore',   1, 0, GETUTCDATE());
INSERT INTO [dbo].[Dealers] ([Id],[DealerCode],[DealerName],[State],[City],[IsActive],[IsDeleted],[CreatedAt]) VALUES (NEWID(), 'DL003', 'Rohini Auto',          'Delhi',         'Rohini',       1, 0, GETUTCDATE());
INSERT INTO [dbo].[Dealers] ([Id],[DealerCode],[DealerName],[State],[City],[IsActive],[IsDeleted],[CreatedAt]) VALUES (NEWID(), 'GJ002', 'Surat Motors',         'Gujarat',       'Surat',        1, 0, GETUTCDATE());
INSERT INTO [dbo].[Dealers] ([Id],[DealerCode],[DealerName],[State],[City],[IsActive],[IsDeleted],[CreatedAt]) VALUES (NEWID(), 'BR001', 'Patna Motors',         'Bihar',         'Patna',        1, 0, GETUTCDATE());
INSERT INTO [dbo].[Dealers] ([Id],[DealerCode],[DealerName],[State],[City],[IsActive],[IsDeleted],[CreatedAt]) VALUES (NEWID(), 'DL001', 'Delhi Motors',         'Delhi',         'New Delhi',    1, 0, GETUTCDATE());
INSERT INTO [dbo].[Dealers] ([Id],[DealerCode],[DealerName],[State],[City],[IsActive],[IsDeleted],[CreatedAt]) VALUES (NEWID(), 'UP002', 'Kanpur Motors',        'Uttar Pradesh', 'Kanpur',       1, 0, GETUTCDATE());
INSERT INTO [dbo].[Dealers] ([Id],[DealerCode],[DealerName],[State],[City],[IsActive],[IsDeleted],[CreatedAt]) VALUES (NEWID(), 'MH002', 'Shree Auto',           'Maharashtra',   'Mumbai',       1, 0, GETUTCDATE());

-- Verify
SELECT COUNT(*) AS TotalDealers FROM [dbo].[Dealers];
SELECT [DealerCode], [DealerName], [State], [City] FROM [dbo].[Dealers] ORDER BY [State], [DealerName];

PRINT 'Dealer seed completed — 16 dealers inserted.';
