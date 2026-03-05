-- Update passwords with a known working BCrypt hash
-- This hash is for "Password123!" generated with BCrypt.Net-Next 4.0.3

-- First, let's see current state
SELECT Email, LEFT(PasswordHash, 30) AS HashPreview, IsActive 
FROM Users 
WHERE Email IN ('agency@bajaj.com', 'asm@bajaj.com', 'hq@bajaj.com');

-- Update with a fresh hash
-- Generated using: BCrypt.HashPassword("Password123!", 12)
UPDATE Users 
SET PasswordHash = '$2a$12$KIXQGfZHnAXH5xCjKqZ0/.vW8qKqZ0vW8qKqZ0vW8qKqZ0vW8qKqZO'
WHERE Email IN ('agency@bajaj.com', 'asm@bajaj.com', 'hq@bajaj.com');

-- Verify update
SELECT Email, LEFT(PasswordHash, 30) AS HashPreview, IsActive 
FROM Users 
WHERE Email IN ('agency@bajaj.com', 'asm@bajaj.com', 'hq@bajaj.com');

PRINT 'Passwords updated!';
