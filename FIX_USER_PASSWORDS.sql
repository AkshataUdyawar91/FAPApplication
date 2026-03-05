-- Fix user passwords with proper BCrypt hash for "Password123!"
-- BCrypt hash generated with work factor 12

UPDATE Users 
SET PasswordHash = '$2a$12$LQv3c1yqBWEFRqvCpnGH.OMJmkImpbefqqHQXSNTLUpbRS2uKU/Iy'
WHERE Email IN ('agency@bajaj.com', 'asm@bajaj.com', 'hq@bajaj.com');

-- Verify the update
SELECT Id, Email, FullName, Role, 
       LEFT(PasswordHash, 20) + '...' AS PasswordHashPreview,
       IsActive, LastLoginAt
FROM Users;

PRINT 'Passwords updated successfully!';
PRINT 'All users can now login with password: Password123!';
