-- =============================================
-- Migration: Add Dealers and StateCities tables,
--            remove DealerCode/DealerName/City from StateMappings
-- Date: 2026-03-19
-- Rollback: re-add columns to StateMappings, drop Dealers and StateCities
-- =============================================
BEGIN TRANSACTION;

BEGIN TRY

    -- 1. Create Dealers table
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

        CREATE UNIQUE INDEX IX_Dealers_DealerCode      ON Dealers (DealerCode);
        CREATE INDEX        IX_Dealers_State            ON Dealers (State);
        CREATE INDEX        IX_Dealers_State_IsActive   ON Dealers (State, IsActive);

        PRINT 'Created Dealers table';
    END
    ELSE
        PRINT 'Dealers table already exists — skipping';

    -- 2. Create StateCities table
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'StateCities')
    BEGIN
        CREATE TABLE StateCities (
            Id          UNIQUEIDENTIFIER    NOT NULL DEFAULT NEWID(),
            State       NVARCHAR(100)       NOT NULL,
            City        NVARCHAR(100)       NOT NULL,
            IsActive    BIT                 NOT NULL DEFAULT 1,
            IsDeleted   BIT                 NOT NULL DEFAULT 0,
            CreatedAt   DATETIME2           NOT NULL DEFAULT GETUTCDATE(),
            UpdatedAt   DATETIME2           NULL,
            CreatedBy   NVARCHAR(256)       NULL,
            UpdatedBy   NVARCHAR(256)       NULL,
            CONSTRAINT PK_StateCities PRIMARY KEY (Id)
        );

        CREATE UNIQUE INDEX IX_StateCities_State_City  ON StateCities (State, City);
        CREATE INDEX        IX_StateCities_State        ON StateCities (State);

        PRINT 'Created StateCities table';
    END
    ELSE
        PRINT 'StateCities table already exists — skipping';

    -- 3. Drop DealerCode, DealerName, City from StateMappings
    --    Drop dependent index on DealerCode first
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_StateMappings_DealerCode' AND object_id = OBJECT_ID('StateMappings'))
    BEGIN
        DROP INDEX IX_StateMappings_DealerCode ON StateMappings;
        PRINT 'Dropped index IX_StateMappings_DealerCode';
    END

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'StateMappings' AND COLUMN_NAME = 'DealerCode')
    BEGIN
        ALTER TABLE StateMappings DROP COLUMN DealerCode;
        PRINT 'Dropped StateMappings.DealerCode';
    END
    ELSE
        PRINT 'StateMappings.DealerCode already absent — skipping';

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'StateMappings' AND COLUMN_NAME = 'DealerName')
    BEGIN
        ALTER TABLE StateMappings DROP COLUMN DealerName;
        PRINT 'Dropped StateMappings.DealerName';
    END
    ELSE
        PRINT 'StateMappings.DealerName already absent — skipping';

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'StateMappings' AND COLUMN_NAME = 'City')
    BEGIN
        ALTER TABLE StateMappings DROP COLUMN City;
        PRINT 'Dropped StateMappings.City';
    END
    ELSE
        PRINT 'StateMappings.City already absent — skipping';

    COMMIT TRANSACTION;
    PRINT 'Migration completed successfully.';

END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    THROW;
END CATCH;
