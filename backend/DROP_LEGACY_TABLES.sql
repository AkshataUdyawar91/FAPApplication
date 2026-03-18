-- =============================================
-- Migration: Drop CampaignInvoices and ASMs tables
-- Date: 2026-03-18
-- Author: Kiro
-- Purpose:
--   CampaignInvoices — legacy table superseded by Invoices table.
--                      No service or controller queries it at runtime.
--   ASMs             — legacy table superseded by Users table (Role = ASM).
--                      No service or controller queries it at runtime.
-- Rollback: DROP_LEGACY_TABLES_ROLLBACK.sql
-- Safe to run multiple times (idempotent)
-- =============================================

BEGIN TRANSACTION;

BEGIN TRY

    -- ── 1. CampaignInvoices ──────────────────────────────────────────

    -- Drop foreign key constraints first (required before dropping table)
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
        WHERE TABLE_NAME = 'CampaignInvoices' AND CONSTRAINT_NAME = 'FK_CampaignInvoices_DocumentPackages_PackageId'
    )
        ALTER TABLE CampaignInvoices DROP CONSTRAINT FK_CampaignInvoices_DocumentPackages_PackageId;

    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
        WHERE TABLE_NAME = 'CampaignInvoices' AND CONSTRAINT_NAME = 'FK_CampaignInvoices_Teams_CampaignId'
    )
        ALTER TABLE CampaignInvoices DROP CONSTRAINT FK_CampaignInvoices_Teams_CampaignId;

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CampaignInvoices')
    BEGIN
        DROP TABLE CampaignInvoices;
        PRINT 'Dropped table: CampaignInvoices';
    END
    ELSE
        PRINT 'Table CampaignInvoices does not exist — skipping';

    -- ── 2. ASMs ──────────────────────────────────────────────────────

    -- Drop foreign key constraints first
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
        WHERE TABLE_NAME = 'ASMs' AND CONSTRAINT_NAME = 'FK_ASMs_Users_UserId'
    )
        ALTER TABLE ASMs DROP CONSTRAINT FK_ASMs_Users_UserId;

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'ASMs')
    BEGIN
        DROP TABLE ASMs;
        PRINT 'Dropped table: ASMs';
    END
    ELSE
        PRINT 'Table ASMs does not exist — skipping';

    PRINT 'DROP_LEGACY_TABLES: completed successfully.';

    COMMIT TRANSACTION;

END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
