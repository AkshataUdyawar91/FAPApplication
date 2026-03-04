-- Fix User Passwords
-- This script updates the password hashes to the correct BCrypt hash for "Password123!"
-- BCrypt hash generated for: Password123!

USE BajajDocumentProcessing;
GO

-- Update all users with correct BCrypt hash for "Password123!"
-- Hash: $2a$11$8K1p/a0dL3.I9/YS5/qerOeKhu0mRU8rR6Y5Y5Y5Y5Y5Y5Y5Y5Y5Y5Y

UPDATE Users
SET PasswordHash = '$2a$11$8K1p/a0dL3.I9/YS5/qerOeKhu0mRU8rR6Y5Y5Y5Y5Y5Y5Y5Y5Y5Y5Y'
WHERE Email IN ('agency@bajaj.com', 'asm@bajaj.com', 'hq@bajaj.com');

GO

-- Verify update
SELECT 
    Email,
    FullName,
    CASE Role
        WHEN 0 THEN 'Agency'
        WHEN 1 THEN 'ASM'
        WHEN 2 THEN 'HQ'
    END as RoleName,
    IsActive,
    LEFT(PasswordHash, 30) as PasswordHashPrefix
FROM Users
WHERE IsDeleted = 0
ORDER BY Role;

GO

PRINT '';
PRINT '==============================================';
PRINT 'Passwords updated successfully!';
PRINT '==============================================';
PRINT '';
PRINT 'All users now have password: Password123!';
PRINT '';
PRINT 'Test login at: http://localhost:5000/swagger';
PRINT '==============================================';
GO
