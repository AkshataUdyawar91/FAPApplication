-- =============================================
-- Purpose: Seed mock Agency data
-- Run against: BajajDocumentProcessing on localhost\SQLEXPRESS
-- =============================================

-- Agency 1: Demo Agency (matches seed code)
IF NOT EXISTS (SELECT 1 FROM [Agencies] WHERE [SupplierCode] = 'V001')
BEGIN
    INSERT INTO [Agencies] ([Id], [SupplierCode], [SupplierName], [CreatedAt], [IsDeleted])
    VALUES (NEWID(), 'V001', 'Demo Agency', GETUTCDATE(), 0);
    PRINT 'Inserted Demo Agency (V001)';
END
ELSE PRINT 'V001 already exists';

-- Agency 2
IF NOT EXISTS (SELECT 1 FROM [Agencies] WHERE [SupplierCode] = 'V002')
BEGIN
    INSERT INTO [Agencies] ([Id], [SupplierCode], [SupplierName], [CreatedAt], [IsDeleted])
    VALUES (NEWID(), 'V002', 'Pinnacle Media Solutions', GETUTCDATE(), 0);
    PRINT 'Inserted Pinnacle Media Solutions (V002)';
END
ELSE PRINT 'V002 already exists';

-- Agency 3
IF NOT EXISTS (SELECT 1 FROM [Agencies] WHERE [SupplierCode] = 'V003')
BEGIN
    INSERT INTO [Agencies] ([Id], [SupplierCode], [SupplierName], [CreatedAt], [IsDeleted])
    VALUES (NEWID(), 'V003', 'Horizon Advertising Pvt Ltd', GETUTCDATE(), 0);
    PRINT 'Inserted Horizon Advertising (V003)';
END
ELSE PRINT 'V003 already exists';

-- Agency 4
IF NOT EXISTS (SELECT 1 FROM [Agencies] WHERE [SupplierCode] = 'V004')
BEGIN
    INSERT INTO [Agencies] ([Id], [SupplierCode], [SupplierName], [CreatedAt], [IsDeleted])
    VALUES (NEWID(), 'V004', 'Catalyst Events & Activations', GETUTCDATE(), 0);
    PRINT 'Inserted Catalyst Events (V004)';
END
ELSE PRINT 'V004 already exists';

-- Agency 5
IF NOT EXISTS (SELECT 1 FROM [Agencies] WHERE [SupplierCode] = 'V005')
BEGIN
    INSERT INTO [Agencies] ([Id], [SupplierCode], [SupplierName], [CreatedAt], [IsDeleted])
    VALUES (NEWID(), 'V005', 'Spark Digital Marketing', GETUTCDATE(), 0);
    PRINT 'Inserted Spark Digital Marketing (V005)';
END
ELSE PRINT 'V005 already exists';

-- Verify
SELECT [Id], [SupplierCode], [SupplierName], [CreatedAt], [IsDeleted] FROM [Agencies];
