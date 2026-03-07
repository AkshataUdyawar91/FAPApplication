---
inclusion: always
---

# SQL & Database Script Best Practices

This file covers rules for raw SQL scripts, stored procedures, seed data, and database-level concerns. For EF Core LINQ queries, migrations via `dotnet ef`, and DbContext usage, see `dotnet-best-practices.md`.

## General Principles

- Prefer EF Core Code-First migrations over raw SQL scripts. Use raw SQL only when EF Core cannot express the operation (complex data migrations, stored procedures, performance-critical bulk operations, database-level constraints).
- Every SQL script must be idempotent — safe to run multiple times without side effects.
- Every SQL script must be reviewed for data loss risk before execution.
- Never execute raw SQL in production without a tested rollback script.

## Query Performance

### Eager Loading & N+1 Prevention

- Always use `Include()`/`ThenInclude()` in EF Core to load related entities in a single query.
- Never execute separate queries per parent entity to load children (N+1 pattern).
- For complex includes with multiple collection navigations, use `AsSplitQuery()` to avoid cartesian explosion.
- When raw SQL is needed for performance, use `FromSqlInterpolated()` or `FromSqlRaw()` with parameters.

### Pagination

- All list queries MUST support server-side pagination.
- Use `Skip()`/`Take()` with configurable `pageSize` (default: 20, max: 100) and `pageNumber`.
- Always return total count alongside paginated results for UI pagination controls.
- Use `CountAsync()` separately or a single query with window functions when supported.
- Never return unbounded result sets — enforce max page size at the service layer.

### Projection & Filtering

- Use `Select()` projection to retrieve only required columns — never `SELECT *`.
- Apply `WHERE` filters as early as possible to reduce data scanned.
- Use `AsNoTracking()` for all read-only queries.
- Use compiled queries (`EF.CompileAsyncQuery`) for frequently executed, performance-critical queries.

### Indexing

- Index all foreign key columns.
- Index columns used in `WHERE`, `ORDER BY`, and `JOIN` clauses.
- Use composite indexes for multi-column filter patterns (e.g., `UserId + CreatedAt`).
- Define indexes in EF Core configuration files (`HasIndex()`), not as raw SQL.
- Review query execution plans for slow queries — add missing indexes.
- Avoid over-indexing — each index adds write overhead. Index only what's queried.

### Join & Subquery Rules

- Prefer `INNER JOIN` over subqueries when both produce the same result.
- Avoid correlated subqueries in `SELECT` or `WHERE` — they execute per row.
- Use `EXISTS` instead of `IN` for large subquery result sets.
- Use CTEs (Common Table Expressions) for readability in complex queries.

## Stored Procedures

### When to Use

- Complex multi-step data operations that benefit from server-side execution.
- Bulk operations (batch inserts, updates, deletes) where EF Core is too slow.
- Operations requiring database-level locking or transaction isolation control.
- Reporting queries with complex aggregations.

### Naming Conventions

- Prefix with `usp_` (user stored procedure): `usp_GetSubmissionsByAgency`.
- Use PascalCase after the prefix.
- Name describes the action: `usp_CalculateConfidenceScores`, `usp_ArchiveOldPackages`.

### Implementation Rules

- Always use parameterized inputs — never concatenate strings into SQL.
- Include `SET NOCOUNT ON` at the top to suppress row count messages.
- Use `TRY...CATCH` blocks for error handling.
- Return meaningful error codes and messages.
- Include a header comment: purpose, author, date, parameters, example usage.
- Keep procedures under 200 lines — split complex logic into sub-procedures.
- Use `BEGIN TRANSACTION` / `COMMIT` / `ROLLBACK` for multi-statement operations.

```sql
-- =============================================
-- Procedure: usp_GetPaginatedSubmissions
-- Purpose:   Retrieve paginated submissions with eager-loaded documents
-- Author:    [author]
-- Date:      [date]
-- Parameters:
--   @AgencyId   - Filter by agency (NULL for all)
--   @PageNumber - Page number (1-based)
--   @PageSize   - Items per page (default 20, max 100)
-- =============================================
CREATE OR ALTER PROCEDURE usp_GetPaginatedSubmissions
    @AgencyId UNIQUEIDENTIFIER = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Guard: enforce max page size
    IF @PageSize > 100 SET @PageSize = 100;
    IF @PageSize < 1 SET @PageSize = 20;
    IF @PageNumber < 1 SET @PageNumber = 1;
    
    -- Total count for pagination metadata
    SELECT COUNT(*) AS TotalCount
    FROM DocumentPackages dp
    WHERE dp.IsDeleted = 0
      AND (@AgencyId IS NULL OR dp.AgencyId = @AgencyId);
    
    -- Paginated results with eager-loaded documents
    SELECT dp.*, d.*
    FROM DocumentPackages dp
    LEFT JOIN Documents d ON d.PackageId = dp.Id AND d.IsDeleted = 0
    WHERE dp.IsDeleted = 0
      AND (@AgencyId IS NULL OR dp.AgencyId = @AgencyId)
    ORDER BY dp.CreatedAt DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
```

## Seed Data Scripts

### Principles

- Seed scripts must be idempotent — use `IF NOT EXISTS` or `MERGE` patterns.
- Separate seed data by environment: development seeds vs. production reference data.
- Never seed sensitive data (passwords, tokens, real PII) — use placeholders.
- Seed scripts must respect foreign key constraints — insert in dependency order.
- Include a comment header: purpose, environment, dependencies.

### Patterns

```sql
-- Idempotent seed: insert only if not exists
IF NOT EXISTS (SELECT 1 FROM Roles WHERE Name = 'Agency')
BEGIN
    INSERT INTO Roles (Id, Name, Description, CreatedAt)
    VALUES (NEWID(), 'Agency', 'Agency user role', GETUTCDATE());
END;

-- MERGE pattern for upsert
MERGE INTO LookupTable AS target
USING (VALUES
    ('Active', 'Active status'),
    ('Inactive', 'Inactive status')
) AS source (Code, Description)
ON target.Code = source.Code
WHEN NOT MATCHED THEN
    INSERT (Code, Description) VALUES (source.Code, source.Description)
WHEN MATCHED THEN
    UPDATE SET Description = source.Description;
```

## Migration Scripts (Raw SQL)

### When to Use Raw SQL Migrations

- Data migrations that transform existing data (not just schema changes).
- Adding database-level constraints that EF Core doesn't support (check constraints, filtered indexes).
- Creating or altering stored procedures, views, or functions.
- Backfilling data for new required columns.

### Rules

- Every migration script must have a corresponding rollback script.
- Name format: `YYYYMMDD_HHMM_DescriptiveName.sql` (e.g., `20260307_1400_AddStateToDocumentPackage.sql`).
- Include a header: purpose, author, date, dependencies, rollback instructions.
- Test on a copy of production data before applying to production.
- Wrap data modifications in transactions.
- Log progress for long-running migrations (print statements or output tables).

```sql
-- =============================================
-- Migration: Add State column to DocumentPackages
-- Date: 2026-03-07
-- Rollback: 20260307_1400_AddStateToDocumentPackage_ROLLBACK.sql
-- =============================================
BEGIN TRANSACTION;

BEGIN TRY
    -- Add column with default value
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'State'
    )
    BEGIN
        ALTER TABLE DocumentPackages
        ADD State NVARCHAR(50) NOT NULL DEFAULT 'Uploaded';
        
        PRINT 'Column State added to DocumentPackages';
    END
    ELSE
    BEGIN
        PRINT 'Column State already exists — skipping';
    END;
    
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    THROW;
END CATCH;
```

## Security

- Never concatenate user input into SQL — always use parameterized queries.
- Use `sp_executesql` for dynamic SQL — never `EXEC(@sql)` with string concatenation.
- Grant minimum required permissions to application database users.
- Application accounts should NOT have `db_owner` — use specific permissions (SELECT, INSERT, UPDATE, EXECUTE).
- Never store plaintext passwords or secrets in database tables.
- Audit sensitive data access with database-level auditing or application-level logging.
- Use row-level security or application-level filtering for multi-tenant data.

## Transactions & Concurrency

- Wrap multi-statement writes in explicit transactions.
- Keep transactions as short as possible — don't hold locks during external calls.
- Use appropriate isolation levels:
  - `READ COMMITTED` (default) for most operations.
  - `SNAPSHOT` for read-heavy workloads that need consistency without blocking.
  - `SERIALIZABLE` only when absolutely required (highest lock contention).
- Use optimistic concurrency (`RowVersion` / `ROWVERSION`) for entities modified concurrently.
- Handle deadlocks gracefully — retry with exponential backoff (max 3 attempts).

## Naming Conventions

| Object | Convention | Example |
|--------|-----------|---------|
| Tables | PascalCase, plural | `DocumentPackages`, `AuditLogs` |
| Columns | PascalCase | `CreatedAt`, `PackageState` |
| Primary Keys | `Id` | `Id` |
| Foreign Keys | `{RelatedTable}Id` | `PackageId`, `UserId` |
| Indexes | `IX_{Table}_{Columns}` | `IX_Documents_PackageId` |
| Stored Procedures | `usp_{Action}` | `usp_GetPaginatedSubmissions` |
| Views | `vw_{Description}` | `vw_SubmissionSummary` |
| Functions | `fn_{Description}` | `fn_CalculateWeightedScore` |
| Constraints (Check) | `CK_{Table}_{Column}` | `CK_ConfidenceScores_Range` |
| Constraints (FK) | `FK_{Table}_{RelatedTable}` | `FK_Documents_DocumentPackages` |
| Default Constraints | `DF_{Table}_{Column}` | `DF_DocumentPackages_CreatedAt` |

## Performance Monitoring

- Enable EF Core query logging in Development (`EnableSensitiveDataLogging`).
- Use SQL Server Profiler or Extended Events for production query analysis.
- Monitor slow queries (>500ms) and add indexes or optimize.
- Track query execution plans for critical endpoints.
- Monitor database connection pool usage — watch for connection exhaustion.
- Set query timeouts appropriate to the operation (default 30s, bulk operations longer).

## Code Review Checklist (SQL)

Before committing SQL scripts or database changes:

- [ ] Script is idempotent — safe to run multiple times.
- [ ] Rollback script exists and is tested.
- [ ] No string concatenation for dynamic SQL — parameterized only.
- [ ] Transactions used for multi-statement writes.
- [ ] Indexes added for new foreign keys and frequently filtered columns.
- [ ] Pagination enforced — no unbounded result sets.
- [ ] `SELECT *` not used — only required columns projected.
- [ ] N+1 patterns eliminated — eager loading or joins used.
- [ ] Naming conventions followed (see table above).
- [ ] Header comments included (purpose, author, date, rollback).
- [ ] No sensitive data in seed scripts (passwords, tokens, PII).
- [ ] Tested on development environment before production.
- [ ] Performance acceptable — execution plan reviewed for complex queries.
