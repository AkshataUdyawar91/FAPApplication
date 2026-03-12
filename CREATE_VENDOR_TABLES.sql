-- =============================================
-- Create Vendor and VendorContacts tables
-- Relationship: Vendor 1:many VendorContacts
-- Used for PO extraction → vendor email lookup
-- =============================================

-- Create Vendors table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Vendors')
BEGIN
    CREATE TABLE [dbo].[Vendors] (
        [Id]            UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
        [VendorCode]    NVARCHAR(50)     NOT NULL,
        [VendorName]    NVARCHAR(500)    NOT NULL,
        [IsActive]      BIT              NOT NULL DEFAULT 1,
        [CreatedAt]     DATETIME2        NOT NULL DEFAULT GETUTCDATE(),
        [UpdatedAt]     DATETIME2        NULL,
        [CreatedBy]     NVARCHAR(MAX)    NULL,
        [UpdatedBy]     NVARCHAR(MAX)    NULL,
        [IsDeleted]     BIT              NOT NULL DEFAULT 0,
        CONSTRAINT [PK_Vendors] PRIMARY KEY ([Id])
    );

    -- Unique index on VendorCode (primary lookup key)
    CREATE UNIQUE INDEX [IX_Vendors_VendorCode] ON [dbo].[Vendors] ([VendorCode]);
    
    -- Index on VendorName (secondary/fallback lookup)
    CREATE INDEX [IX_Vendors_VendorName] ON [dbo].[Vendors] ([VendorName]);

    PRINT 'Vendors table created successfully.';
END
ELSE
    PRINT 'Vendors table already exists.';
GO

-- Create VendorContacts table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'VendorContacts')
BEGIN
    CREATE TABLE [dbo].[VendorContacts] (
        [Id]            UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
        [VendorId]      UNIQUEIDENTIFIER NOT NULL,
        [ContactName]   NVARCHAR(200)    NOT NULL,
        [Email]         NVARCHAR(320)    NOT NULL,
        [IsActive]      BIT              NOT NULL DEFAULT 1,
        [CreatedAt]     DATETIME2        NOT NULL DEFAULT GETUTCDATE(),
        [UpdatedAt]     DATETIME2        NULL,
        [CreatedBy]     NVARCHAR(MAX)    NULL,
        [UpdatedBy]     NVARCHAR(MAX)    NULL,
        [IsDeleted]     BIT              NOT NULL DEFAULT 0,
        CONSTRAINT [PK_VendorContacts] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_VendorContacts_Vendors] FOREIGN KEY ([VendorId]) 
            REFERENCES [dbo].[Vendors]([Id]) ON DELETE CASCADE
    );

    CREATE INDEX [IX_VendorContacts_VendorId] ON [dbo].[VendorContacts] ([VendorId]);
    CREATE INDEX [IX_VendorContacts_Email] ON [dbo].[VendorContacts] ([Email]);

    PRINT 'VendorContacts table created successfully.';
END
ELSE
    PRINT 'VendorContacts table already exists.';
GO

-- =============================================
-- Seed data: Swift Events (VendorCode: 115287)
-- =============================================
DECLARE @VendorId UNIQUEIDENTIFIER = NEWID();

IF NOT EXISTS (SELECT 1 FROM [dbo].[Vendors] WHERE [VendorCode] = '115287')
BEGIN
    INSERT INTO [dbo].[Vendors] ([Id], [VendorCode], [VendorName], [IsActive], [CreatedAt], [IsDeleted])
    VALUES (@VendorId, '115287', 'Swift Events', 1, GETUTCDATE(), 0);

    INSERT INTO [dbo].[VendorContacts] ([Id], [VendorId], [ContactName], [Email], [IsActive], [CreatedAt], [IsDeleted])
    VALUES 
        (NEWID(), @VendorId, 'Rahul Sharma', 'rahul.sharma@swiftevents.in', 1, GETUTCDATE(), 0),
        (NEWID(), @VendorId, 'Priya Mehta', 'priya.mehta@swiftevents.in', 1, GETUTCDATE(), 0);

    PRINT 'Seed data inserted: Swift Events with 2 contacts.';
END
ELSE
    PRINT 'Vendor 115287 (Swift Events) already exists.';
GO
