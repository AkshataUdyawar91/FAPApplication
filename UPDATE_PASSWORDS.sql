-- Update user passwords with correct BCrypt hash
UPDATE Users 
SET PasswordHash = '$2a$12$wc4OTK9Q0DaCP2t8.GrAoe8Bedog6UNDfjC5PY6fdjFxjnicOKIYK'
WHERE Email = 'agency@bajaj.com';

UPDATE Users 
SET PasswordHash = '$2a$12$wc4OTK9Q0DaCP2t8.GrAoe8Bedog6UNDfjC5PY6fdjFxjnicOKIYK'
WHERE Email = 'asm@bajaj.com';

UPDATE Users 
SET PasswordHash = '$2a$12$wc4OTK9Q0DaCP2t8.GrAoe8Bedog6UNDfjC5PY6fdjFxjnicOKIYK'
WHERE Email = 'hq@bajaj.com';

-- Verify
SELECT Email, PasswordHash, LEN(PasswordHash) AS HashLength FROM Users;
GO
