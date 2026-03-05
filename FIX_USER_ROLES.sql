-- Fix User Roles in Database
-- The JWT token shows role = 0, but valid roles are 1, 2, 3

-- Check current user roles
SELECT Id, Email, FullName, Role, IsActive 
FROM Users;

-- Update agency user to have correct role (Agency = 1)
UPDATE Users 
SET Role = 1 
WHERE Email = 'agency@bajaj.com';

-- Update ASM user to have correct role (ASM = 2)
UPDATE Users 
SET Role = 2 
WHERE Email = 'asm@bajaj.com';

-- Update HQ user to have correct role (HQ = 3)
UPDATE Users 
SET Role = 3 
WHERE Email = 'hq@bajaj.com';

-- Verify the update
SELECT Id, Email, FullName, Role, IsActive 
FROM Users;

-- Expected results:
-- agency@bajaj.com: Role = 1 (Agency)
-- asm@bajaj.com: Role = 2 (ASM)
-- hq@bajaj.com: Role = 3 (HQ)
