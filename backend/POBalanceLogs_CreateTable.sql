-- =============================================
-- Migration: Create POBalanceLogs table
-- Purpose:   Audit log for every /api/po-balance call
-- Run on:    BajajDocumentProcessing database
-- Idempotent: Yes (IF NOT EXISTS guard)
-- =============================================

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_NAME = 'POBalanceLogs'
)
BEGIN
    CREATE TABLE [dbo].[POBalanceLogs] (
        [Id]              UNIQUEIDENTIFIER    NOT NULL DEFAULT NEWID(),
        [PoNum]           NVARCHAR(50)        NOT NULL,
        [CompanyCode]     NVARCHAR(20)        NOT NULL,
        [RequestedBy]     NVARCHAR(450)       NULL,
        [RequestedAt]     DATETIME2           NOT NULL,
        [SapRequestBody]  NVARCHAR(MAX)       NULL,
        [SapCalledAt]     DATETIME2           NULL,
        [SapRespondedAt]  DATETIME2           NULL,
        [SapHttpStatus]   INT                 NULL,
        [SapResponseBody] NVARCHAR(4000)      NULL,
        [Balance]         DECIMAL(18, 2)      NULL,
        [Currency]        NVARCHAR(10)        NULL,
        [IsSuccess]       BIT                 NOT NULL DEFAULT 0,
        [ErrorMessage]    NVARCHAR(MAX)       NULL,
        [ElapsedMs]       BIGINT              NOT NULL DEFAULT 0,
        [CorrelationId]   NVARCHAR(100)       NULL,

        CONSTRAINT [PK_POBalanceLogs] PRIMARY KEY ([Id])
    );

    CREATE INDEX [IX_POBalanceLogs_PoNum]       ON [dbo].[POBalanceLogs] ([PoNum]);
    CREATE INDEX [IX_POBalanceLogs_RequestedAt] ON [dbo].[POBalanceLogs] ([RequestedAt] DESC);
    CREATE INDEX [IX_POBalanceLogs_IsSuccess]   ON [dbo].[POBalanceLogs] ([IsSuccess]);

    PRINT 'POBalanceLogs table created successfully.';
END
ELSE
BEGIN
    PRINT 'POBalanceLogs table already exists — skipping.';
END;
