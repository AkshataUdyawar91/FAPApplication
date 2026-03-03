-- Update User Passwords with correct BCrypt hash for "Password123!"
USE BajajDocumentProcessing;
GO

UPDATE Users
SET PasswordHash = '$2a$11$3nkoyQ2QLmsMbza1OGa.oOHXEsi7D9c7FGt4UIK4k.TtCskRFs3DC'
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
PRINT 'Login Credentials:';
PRINT '  agency@bajaj.com / Password123!';
PRINT '  asm@bajaj.com / Password123!';
PRINT '  hq@bajaj.com / Password123!';
PRINT '';
PRINT 'Test at: http://localhost:5000/swagger';
PRINT '==============================================';
GO
