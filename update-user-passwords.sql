-- Update user passwords with correct BCrypt hash
USE BajajDocumentProcessing;
GO

UPDATE Users 
SET PasswordHash = '$2a$12$.kJ3Z27FJeAdhxdeQWM0Q.Q4yfgKJSjOanDp.o/ZvGHWbygN6e6r6'
WHERE Email IN ('agency@bajaj.com', 'asm@bajaj.com', 'hq@bajaj.com');
GO

-- Verify the update
SELECT Email, PasswordHash 
FROM Users 
WHERE Email IN ('agency@bajaj.com', 'asm@bajaj.com', 'hq@bajaj.com');
GO
