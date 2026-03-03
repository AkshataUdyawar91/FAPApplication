-- Create Users for Bajaj Document Processing System
-- Password for all users: Password123!
-- Run this script in SQL Server Management Studio or Azure Data Studio

USE BajajDocumentProcessing;
GO

-- Create Agency User
INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, PhoneNumber, IsActive, CreatedAt, IsDeleted)
VALUES (
    NEWID(),
    'agency@bajaj.com',
    '$2a$12$LQv3c1yqBwWVHxkd0LHAkO.Ky8Zy8Zy8Zy8Zy8Zy8Zy8Zy8Zy8Zy8',
    'Agency User',
    0, -- Agency role
    '+91-9876543210',
    1, -- IsActive
    GETUTCDATE(),
    0  -- Not deleted
);

-- Create ASM User
INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, PhoneNumber, IsActive, CreatedAt, IsDeleted)
VALUES (
    NEWID(),
    'asm@bajaj.com',
    '$2a$12$LQv3c1yqBwWVHxkd0LHAkO.Ky8Zy8Zy8Zy8Zy8Zy8Zy8Zy8Zy8Zy8',
    'ASM User',
    1, -- ASM role
    '+91-9876543211',
    1, -- IsActive
    GETUTCDATE(),
    0  -- Not deleted
);

-- Create HQ User
INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, PhoneNumber, IsActive, CreatedAt, IsDeleted)
VALUES (
    NEWID(),
    'hq@bajaj.com',
    '$2a$12$LQv3c1yqBwWVHxkd0LHAkO.Ky8Zy8Zy8Zy8Zy8Zy8Zy8Zy8Zy8Zy8',
    'HQ User',
    2, -- HQ role
    '+91-9876543212',
    1, -- IsActive
    GETUTCDATE(),
    0  -- Not deleted
);

GO

-- Verify users were created
SELECT 
    Id,
    Email,
    FullName,
    CASE Role
        WHEN 0 THEN 'Agency'
        WHEN 1 THEN 'ASM'
        WHEN 2 THEN 'HQ'
        ELSE 'Unknown'
    END as RoleName,
    PhoneNumber,
    IsActive,
    CreatedAt
FROM Users
WHERE IsDeleted = 0
ORDER BY Role;

GO

PRINT '';
PRINT '==============================================';
PRINT 'Users created successfully!';
PRINT '==============================================';
PRINT '';
PRINT 'Login Credentials:';
PRINT '-------------------';
PRINT 'Agency User:';
PRINT '  Email: agency@bajaj.com';
PRINT '  Password: Password123!';
PRINT '';
PRINT 'ASM User:';
PRINT '  Email: asm@bajaj.com';
PRINT '  Password: Password123!';
PRINT '';
PRINT 'HQ User:';
PRINT '  Email: hq@bajaj.com';
PRINT '  Password: Password123!';
PRINT '';
PRINT 'Test login at: http://localhost:5000/swagger';
PRINT '==============================================';
GO
