-- =============================================
-- Add RAUserId to StateMappings and AssignedRAUserId to DocumentPackages
-- Required for role-based scoping (ASM/RA see only their assigned FAPs)
-- Run against: localhost\SQLEXPRESS / BajajDocumentProcessing
-- Idempotent: safe to run multiple times
-- =============================================

-- 1. Add RAUserId to StateMappings
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'StateMappings' AND COLUMN_NAME = 'RAUserId')
BEGIN
    ALTER TABLE [StateMappings] ADD [RAUserId] uniqueidentifier NULL;
    PRINT 'Added RAUserId to StateMappings';
END
ELSE PRINT 'StateMappings.RAUserId already exists';

-- 2. Add AssignedRAUserId to DocumentPackages
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'AssignedRAUserId')
BEGIN
    ALTER TABLE [DocumentPackages] ADD [AssignedRAUserId] uniqueidentifier NULL;
    PRINT 'Added AssignedRAUserId to DocumentPackages';
END
ELSE PRINT 'DocumentPackages.AssignedRAUserId already exists';

-- 3. Populate RAUserId in StateMappings from seed data
-- ra@bajaj.com  -> Maharashtra, Gujarat, Karnataka, Tamil Nadu, Rajasthan
-- ra2@bajaj.com -> Uttar Pradesh, Madhya Pradesh, West Bengal, Andhra Pradesh, Kerala
DECLARE @ra1 uniqueidentifier = (SELECT TOP 1 Id FROM Users WHERE Email = 'ra@bajaj.com');
DECLARE @ra2 uniqueidentifier = (SELECT TOP 1 Id FROM Users WHERE Email = 'ra2@bajaj.com');

IF @ra1 IS NOT NULL
BEGIN
    UPDATE StateMappings SET RAUserId = @ra1
    WHERE State IN ('Maharashtra', 'Gujarat', 'Karnataka', 'Tamil Nadu', 'Rajasthan')
      AND (RAUserId IS NULL OR RAUserId != @ra1);
    PRINT 'Assigned ra@bajaj.com to 5 states';
END

IF @ra2 IS NOT NULL
BEGIN
    UPDATE StateMappings SET RAUserId = @ra2
    WHERE State IN ('Uttar Pradesh', 'Madhya Pradesh', 'West Bengal', 'Andhra Pradesh', 'Kerala')
      AND (RAUserId IS NULL OR RAUserId != @ra2);
    PRINT 'Assigned ra2@bajaj.com to 5 states';
END

-- 4. Verify
PRINT '';
PRINT '=== Current StateMapping assignments ===';
SELECT sm.State, 
       asm.Email AS ASM_Email, 
       ra.Email AS RA_Email
FROM StateMappings sm
LEFT JOIN Users asm ON sm.CircleHeadUserId = asm.Id
LEFT JOIN Users ra ON sm.RAUserId = ra.Id
WHERE sm.IsActive = 1
ORDER BY sm.State;
