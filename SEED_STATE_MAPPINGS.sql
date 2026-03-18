-- =============================================
-- Seed: Users (10 ASMs + 2 RAs) and StateMappings
-- Each ASM has exactly ONE state (1:1 mapping)
-- Password for all: Password123!
-- Idempotent: safe to run multiple times
-- =============================================

-- 1. Ensure RAUserId column exists
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'StateMappings' AND COLUMN_NAME = 'RAUserId'
)
ALTER TABLE StateMappings ADD RAUserId UNIQUEIDENTIFIER NULL;
GO

-- 2. Clear existing StateMappings FIRST (before index creation)
DELETE FROM StateMappings;
GO

-- 3. Drop and recreate indexes
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_StateMappings_State' AND object_id = OBJECT_ID('StateMappings'))
    DROP INDEX IX_StateMappings_State ON StateMappings;
GO
CREATE UNIQUE INDEX IX_StateMappings_State ON StateMappings (State);
GO

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_StateMappings_CircleHeadUserId' AND object_id = OBJECT_ID('StateMappings'))
    DROP INDEX IX_StateMappings_CircleHeadUserId ON StateMappings;
GO
CREATE UNIQUE INDEX IX_StateMappings_CircleHeadUserId ON StateMappings (CircleHeadUserId) WHERE CircleHeadUserId IS NOT NULL;
GO

-- 4. Insert ASM and RA users (skip if exists)
DECLARE @PWD NVARCHAR(200) = '$2a$11$5Rc/zt79jESA9/NqoZCCk.DNMRrWzhcEOFXcq6RILcJiTWlKw2Bby';

IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'asm2@bajaj.com')
INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, AgencyId, IsActive, IsDeleted, CreatedAt, UpdatedAt)
VALUES ('A2222222-2222-2222-2222-222222222222', 'asm2@bajaj.com', @PWD, 'ASM User 2 - Gujarat', 2, NULL, 1, 0, GETUTCDATE(), GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'asm3@bajaj.com')
INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, AgencyId, IsActive, IsDeleted, CreatedAt, UpdatedAt)
VALUES ('A3333333-3333-3333-3333-333333333333', 'asm3@bajaj.com', @PWD, 'ASM User 3 - Karnataka', 2, NULL, 1, 0, GETUTCDATE(), GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'asm4@bajaj.com')
INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, AgencyId, IsActive, IsDeleted, CreatedAt, UpdatedAt)
VALUES ('A4444444-4444-4444-4444-444444444444', 'asm4@bajaj.com', @PWD, 'ASM User 4 - Tamil Nadu', 2, NULL, 1, 0, GETUTCDATE(), GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'asm5@bajaj.com')
INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, AgencyId, IsActive, IsDeleted, CreatedAt, UpdatedAt)
VALUES ('A5555555-5555-5555-5555-555555555555', 'asm5@bajaj.com', @PWD, 'ASM User 5 - Rajasthan', 2, NULL, 1, 0, GETUTCDATE(), GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'asm6@bajaj.com')
INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, AgencyId, IsActive, IsDeleted, CreatedAt, UpdatedAt)
VALUES ('A6666666-6666-6666-6666-666666666666', 'asm6@bajaj.com', @PWD, 'ASM User 6 - Uttar Pradesh', 2, NULL, 1, 0, GETUTCDATE(), GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'asm7@bajaj.com')
INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, AgencyId, IsActive, IsDeleted, CreatedAt, UpdatedAt)
VALUES ('A7777777-7777-7777-7777-777777777777', 'asm7@bajaj.com', @PWD, 'ASM User 7 - Madhya Pradesh', 2, NULL, 1, 0, GETUTCDATE(), GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'asm8@bajaj.com')
INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, AgencyId, IsActive, IsDeleted, CreatedAt, UpdatedAt)
VALUES ('A8888888-8888-8888-8888-888888888888', 'asm8@bajaj.com', @PWD, 'ASM User 8 - West Bengal', 2, NULL, 1, 0, GETUTCDATE(), GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'asm9@bajaj.com')
INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, AgencyId, IsActive, IsDeleted, CreatedAt, UpdatedAt)
VALUES ('A9999999-9999-9999-9999-999999999999', 'asm9@bajaj.com', @PWD, 'ASM User 9 - Andhra Pradesh', 2, NULL, 1, 0, GETUTCDATE(), GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'asm10@bajaj.com')
INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, AgencyId, IsActive, IsDeleted, CreatedAt, UpdatedAt)
VALUES ('A1010101-1010-1010-1010-101010101010', 'asm10@bajaj.com', @PWD, 'ASM User 10 - Kerala', 2, NULL, 1, 0, GETUTCDATE(), GETUTCDATE());

IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'ra2@bajaj.com')
INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, AgencyId, IsActive, IsDeleted, CreatedAt, UpdatedAt)
VALUES ('B4444444-4444-4444-4444-444444444444', 'ra2@bajaj.com', @PWD, 'RA User 2', 3, NULL, 1, 0, GETUTCDATE(), GETUTCDATE());

PRINT 'Users seeded.';
GO

-- 5. Insert StateMappings (1 ASM per state, 1:1)
DECLARE @RA1 UNIQUEIDENTIFIER = 'CFC3D2EF-8E6B-413C-A143-80DB594FC7DC';
DECLARE @RA2 UNIQUEIDENTIFIER = 'B4444444-4444-4444-4444-444444444444';

INSERT INTO StateMappings (Id, State, DealerCode, DealerName, City, CircleHeadUserId, RAUserId, IsActive, IsDeleted, CreatedAt, UpdatedAt)
VALUES
    (NEWID(), 'Maharashtra',    'MOCK-MH', 'Mock Dealer - Maharashtra',    NULL, '5B5B075F-36B6-4245-B8E7-AD88C786258E', @RA1, 1, 0, GETUTCDATE(), GETUTCDATE()),
    (NEWID(), 'Gujarat',        'MOCK-GJ', 'Mock Dealer - Gujarat',        NULL, 'A2222222-2222-2222-2222-222222222222', @RA1, 1, 0, GETUTCDATE(), GETUTCDATE()),
    (NEWID(), 'Karnataka',      'MOCK-KA', 'Mock Dealer - Karnataka',      NULL, 'A3333333-3333-3333-3333-333333333333', @RA1, 1, 0, GETUTCDATE(), GETUTCDATE()),
    (NEWID(), 'Tamil Nadu',     'MOCK-TN', 'Mock Dealer - Tamil Nadu',     NULL, 'A4444444-4444-4444-4444-444444444444', @RA1, 1, 0, GETUTCDATE(), GETUTCDATE()),
    (NEWID(), 'Rajasthan',      'MOCK-RJ', 'Mock Dealer - Rajasthan',      NULL, 'A5555555-5555-5555-5555-555555555555', @RA1, 1, 0, GETUTCDATE(), GETUTCDATE()),
    (NEWID(), 'Uttar Pradesh',  'MOCK-UP', 'Mock Dealer - Uttar Pradesh',  NULL, 'A6666666-6666-6666-6666-666666666666', @RA2, 1, 0, GETUTCDATE(), GETUTCDATE()),
    (NEWID(), 'Madhya Pradesh', 'MOCK-MP', 'Mock Dealer - Madhya Pradesh', NULL, 'A7777777-7777-7777-7777-777777777777', @RA2, 1, 0, GETUTCDATE(), GETUTCDATE()),
    (NEWID(), 'West Bengal',    'MOCK-WB', 'Mock Dealer - West Bengal',    NULL, 'A8888888-8888-8888-8888-888888888888', @RA2, 1, 0, GETUTCDATE(), GETUTCDATE()),
    (NEWID(), 'Andhra Pradesh', 'MOCK-AP', 'Mock Dealer - Andhra Pradesh', NULL, 'A9999999-9999-9999-9999-999999999999', @RA2, 1, 0, GETUTCDATE(), GETUTCDATE()),
    (NEWID(), 'Kerala',         'MOCK-KL', 'Mock Dealer - Kerala',         NULL, 'A1010101-1010-1010-1010-101010101010', @RA2, 1, 0, GETUTCDATE(), GETUTCDATE());

PRINT 'StateMappings seeded — 1 ASM per state (1:1).';
SELECT State, CircleHeadUserId, RAUserId FROM StateMappings ORDER BY State;
