-- =============================================
-- Create Dealers table and populate from StateMappings
-- Run this once against your database
-- =============================================

-- 1. Create Dealers table if not exists
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Dealers')
BEGIN
    CREATE TABLE Dealers (
        Id              UNIQUEIDENTIFIER    NOT NULL DEFAULT NEWID(),
        DealerCode      NVARCHAR(50)        NOT NULL,
        DealerName      NVARCHAR(200)       NOT NULL,
        State           NVARCHAR(100)       NOT NULL,
        City            NVARCHAR(100)       NULL,
        IsActive        BIT                 NOT NULL DEFAULT 1,
        IsDeleted       BIT                 NOT NULL DEFAULT 0,
        CreatedAt       DATETIME2           NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt       DATETIME2           NULL,
        CreatedBy       NVARCHAR(256)       NULL,
        UpdatedBy       NVARCHAR(256)       NULL,
        CONSTRAINT PK_Dealers PRIMARY KEY (Id)
    );
    PRINT 'Dealers table created.';
END
ELSE
    PRINT 'Dealers table already exists.';

-- 2. Copy all dealer records from StateMappings into Dealers
INSERT INTO Dealers (Id, DealerCode, DealerName, State, City, IsActive, IsDeleted, CreatedAt, UpdatedAt, CreatedBy, UpdatedBy)
SELECT
    Id,
    ISNULL(DealerCode, ''),
    ISNULL(DealerName, ''),
    State,
    City,
    IsActive,
    IsDeleted,
    CreatedAt,
    UpdatedAt,
    CreatedBy,
    UpdatedBy
FROM StateMappings
WHERE DealerName IS NOT NULL AND DealerName <> ''
  AND NOT EXISTS (
    SELECT 1 FROM Dealers d WHERE d.Id = StateMappings.Id
  );

PRINT CAST(@@ROWCOUNT AS NVARCHAR) + ' dealer(s) copied from StateMappings into Dealers.';
