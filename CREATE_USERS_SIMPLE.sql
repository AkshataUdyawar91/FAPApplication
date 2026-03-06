-- Create Test Users
-- Password for all users: Password123!
-- BCrypt hash: $2a$12$TnTokTq7TofO02Oc.n/F0uyBQP5Hdj6789hF.E97KZS92RThQN8Aq

USE BajajDocumentProcessing;
GO

-- Delete existing users
DELETE FROM Users;
GO

-- Create Agency User
INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, IsActive, IsDeleted, CreatedAt, UpdatedAt)
VALUES (
    NEWID(),
    'agency@bajaj.com',
    '$2a$12$TnTokTq7TofO02Oc.n/F0uyBQP5Hdj6789hF.E97KZS92RThQN8Aq',
    'Agency User',
    0,
    1,
    0,
    GETUTCDATE(),
    GETUTCDATE()
);

-- Create ASM User
INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, IsActive, IsDeleted, CreatedAt, UpdatedAt)
VALUES (
    NEWID(),
    'asm@bajaj.com',
    '$2a$12$TnTokTq7TofO02Oc.n/F0uyBQP5Hdj6789hF.E97KZS92RThQN8Aq',
    'ASM User',
    1,
    1,
    0,
    GETUTCDATE(),
    GETUTCDATE()
);

-- Create HQ User
INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, IsActive, IsDeleted, CreatedAt, UpdatedAt)
VALUES (
    NEWID(),
    'hq@bajaj.com',
    '$2a$12$TnTokTq7TofO02Oc.n/F0uyBQP5Hdj6789hF.E97KZS92RThQN8Aq',
    'HQ User',
    2,
    1,
    0,
    GETUTCDATE(),
    GETUTCDATE()
);
GO

-- Verify users were created
PRINT '';
PRINT 'Users created successfully:';
PRINT '';
SELECT 
    Email,
    FullName,
    CASE Role 
        WHEN 0 THEN 'Agency'
        WHEN 1 THEN 'ASM'
        WHEN 2 THEN 'HQ'
    END AS RoleName,
    CASE WHEN IsActive = 1 THEN 'Active' ELSE 'Inactive' END AS Status,
    CASE WHEN IsDeleted = 1 THEN 'Deleted' ELSE 'Not Deleted' END AS DeleteStatus
FROM Users
ORDER BY Role;
GO

PRINT '';
PRINT 'Password for all users: Password123!';
PRINT '';
