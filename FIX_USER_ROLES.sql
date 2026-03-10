-- Fix User Roles in Database
-- IMPORTANT: The C# enum UserRole is 0-based:
--   Agency = 0
--   ASM    = 1
--   HQ     = 2
-- DO NOT use 1-based values (1, 2, 3) — that is WRONG and causes 403 errors.

-- Check current user roles
SELECT Id, Email, FullName, Role, IsActive 
FROM Users;

-- Update agency user to correct role (Agency = 0)
UPDATE Users 
SET Role = 0 
WHERE Email = 'agency@bajaj.com';

-- Update ASM user to correct role (ASM = 1)
UPDATE Users 
SET Role = 1 
WHERE Email = 'asm@bajaj.com';

-- Update HQ user to correct role (HQ = 2)
UPDATE Users 
SET Role = 2 
WHERE Email = 'hq@bajaj.com';

-- Verify the update
SELECT Id, Email, FullName, 
    Role,
    CASE Role
        WHEN 0 THEN 'Agency'
        WHEN 1 THEN 'ASM'
        WHEN 2 THEN 'HQ'
        ELSE 'UNKNOWN - BUG!'
    END AS RoleName,
    IsActive 
FROM Users;

-- Expected results:
-- agency@bajaj.com: Role = 0 (Agency)
-- asm@bajaj.com:    Role = 1 (ASM)
-- hq@bajaj.com:     Role = 2 (HQ)
