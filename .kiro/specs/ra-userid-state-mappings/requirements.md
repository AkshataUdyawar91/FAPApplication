# Requirements Document

## Introduction

Add an `RAUserId` column to the `StateMappings` table to map a Regional Approver (RA) user to each state/dealer combination. This mirrors the existing `CircleHeadUserId` pattern and enables RA auto-assignment when submissions transition from ASM-approved to PendingRA state. Currently, RA assignment is not driven by territory data, which is a gap identified in REQ-32.4 and REQ-32.5. This feature closes that gap by storing the RA-to-state mapping directly in the existing `StateMappings` table.

## Glossary

- **StateMappings_Table**: The `StateMappings` SQL Server table that maps Indian states/UTs to dealers, Circle Head users, and (after this feature) RA users. Queried for dealer typeahead and user auto-assignment.
- **StateMapping_Entity**: The EF Core domain entity (`StateMapping.cs`) that represents a row in the StateMappings_Table.
- **RAUserId**: A nullable GUID column on the StateMappings_Table referencing a User with the RA role, used for RA auto-assignment.
- **CircleHeadUserId**: The existing nullable GUID column on the StateMappings_Table referencing a User with the CircleHead role, used for Circle Head auto-assignment.
- **RA**: Regional Approver — the user role (`UserRole.RA`) responsible for the second-level approval after ASM approval.
- **CircleHeadAssignmentService**: The existing infrastructure service that queries StateMappings_Table to auto-assign a Circle Head user to a submission based on state.
- **RAAssignmentService**: A new infrastructure service (to be created) that queries StateMappings_Table to auto-assign an RA user to a submission based on state, following the same pattern as CircleHeadAssignmentService.
- **DocumentPackage**: The domain entity representing a submission package that flows through the approval workflow (Draft → Uploaded → ... → PendingASM → PendingRA → Approved).
- **EF_Migration**: An Entity Framework Core code-first migration that alters the database schema.
- **StateMappingConfiguration**: The EF Core `IEntityTypeConfiguration<StateMapping>` class that defines column constraints, indexes, and defaults for the StateMappings_Table.

## Requirements

### Requirement 1: Add RAUserId Column to StateMapping Entity

**User Story:** As a system administrator, I want the StateMappings_Table to store an RA user reference per state/dealer row, so that RA users can be auto-assigned to submissions based on territory.

#### Acceptance Criteria

1. THE StateMapping_Entity SHALL include an `RAUserId` property of type `Guid?` (nullable).
2. THE StateMappingConfiguration SHALL configure the `RAUserId` column as an optional column with no default value.
3. THE StateMappingConfiguration SHALL define an index on `RAUserId` with the name `IX_StateMappings_RAUserId`.
4. WHEN the EF_Migration is applied, THE StateMappings_Table SHALL contain a nullable `RAUserId` column of type `uniqueidentifier`.
5. WHEN the EF_Migration is applied, THE StateMappings_Table SHALL preserve all existing rows and column values without data loss.

### Requirement 2: EF Core Migration for RAUserId Column

**User Story:** As a developer, I want a code-first EF Core migration that adds the RAUserId column, so that the schema change is versioned and repeatable.

#### Acceptance Criteria

1. WHEN `dotnet ef migrations add AddRAUserIdToStateMappings` is executed, THE migration tool SHALL generate an `Up` method that adds a nullable `uniqueidentifier` column named `RAUserId` to the `StateMappings` table.
2. WHEN `dotnet ef migrations add AddRAUserIdToStateMappings` is executed, THE migration tool SHALL generate a `Down` method that drops the `RAUserId` column from the `StateMappings` table.
3. WHEN `dotnet ef database update` is executed against a database with existing StateMappings rows, THE migration SHALL complete without errors and all existing rows SHALL have `RAUserId` set to `NULL`.
4. THE EF_Migration SHALL create the index `IX_StateMappings_RAUserId` on the `RAUserId` column.

### Requirement 3: RA Auto-Assignment Service

**User Story:** As a system operator, I want submissions transitioning to PendingRA to be automatically assigned an RA user based on the submission state, so that RA reviewers receive submissions for their territory without manual intervention.

#### Acceptance Criteria

1. THE RAAssignmentService SHALL implement an `IRAAssignmentService` interface with a method `AssignAsync(string submissionState, CancellationToken cancellationToken)` that returns `Task<Guid?>`.
2. WHEN `AssignAsync` is called with a valid state name, THE RAAssignmentService SHALL query the StateMappings_Table for active, non-deleted rows matching the state where `RAUserId` is not null.
3. WHEN exactly one distinct RA user is found for the state, THE RAAssignmentService SHALL return that RA user's GUID.
4. WHEN multiple distinct RA users are found for the state, THE RAAssignmentService SHALL return the RA user with the fewest pending submissions (load-balanced assignment).
5. WHEN no RA user is found for the state, THE RAAssignmentService SHALL return `null` and log a warning indicating manual assignment is required.
6. THE RAAssignmentService SHALL use `AsNoTracking` for all read queries.
7. THE RAAssignmentService SHALL accept and propagate a `CancellationToken` through all async operations.

### Requirement 4: Integration with Submission Approval Workflow

**User Story:** As an ASM, I want the system to automatically assign an RA reviewer when I approve a submission, so that the submission moves to PendingRA with a designated RA user.

#### Acceptance Criteria

1. WHEN an ASM approves a submission and the package transitions to `PendingRA`, THE SubmissionsController SHALL invoke the RAAssignmentService to determine the RA user for the submission's `ActivityState`.
2. WHEN the RAAssignmentService returns a valid RA user GUID, THE SubmissionsController SHALL store the assigned RA user identifier on the DocumentPackage.
3. IF the RAAssignmentService returns `null`, THEN THE SubmissionsController SHALL still transition the submission to `PendingRA` and log a warning that no RA was auto-assigned.
4. THE DocumentPackage entity SHALL include an `AssignedRAUserId` property of type `Guid?` to store the auto-assigned RA user.

### Requirement 5: Dealer Typeahead API Unchanged

**User Story:** As an agency user, I want the dealer search endpoint to continue working without changes, so that adding the RAUserId column does not affect my submission workflow.

#### Acceptance Criteria

1. WHEN the StateController dealer search endpoint is called, THE StateController SHALL return `DealerResult` objects that do not include the `RAUserId` field.
2. THE StateController dealer search query SHALL continue to filter by `IsActive` and `IsDeleted` without any change in behavior.
3. WHEN the StateMappings_Table contains rows where `RAUserId` is `NULL`, THE StateController dealer search SHALL return those rows in results (the `RAUserId` column does not affect dealer visibility).

### Requirement 6: Seed Data and Existing Data Compatibility

**User Story:** As a developer, I want existing StateMappings rows to remain valid after the migration, so that the system continues to function without requiring immediate data backfill.

#### Acceptance Criteria

1. WHEN the EF_Migration is applied, THE StateMappings_Table SHALL set `RAUserId` to `NULL` for all existing rows.
2. WHILE `RAUserId` is `NULL` for a StateMappings row, THE RAAssignmentService SHALL exclude that row from RA assignment queries.
3. IF the ApplicationDbContextSeed contains StateMappings seed data, THEN THE seed data SHALL include `RAUserId` as `null` for all seeded rows.

### Requirement 7: Unit Tests for RA Assignment Logic

**User Story:** As a developer, I want comprehensive tests for the RA assignment service, so that the auto-assignment logic is verified for all scenarios.

#### Acceptance Criteria

1. THE test suite SHALL include a test verifying that `AssignAsync` returns the single RA user GUID when exactly one distinct RA user exists for the state.
2. THE test suite SHALL include a test verifying that `AssignAsync` returns the least-loaded RA user GUID when multiple distinct RA users exist for the state.
3. THE test suite SHALL include a test verifying that `AssignAsync` returns `null` when no RA user mapping exists for the state.
4. THE test suite SHALL include a test verifying that `AssignAsync` excludes inactive (`IsActive = false`) and soft-deleted (`IsDeleted = true`) StateMappings rows.
5. THE test suite SHALL include a test verifying that `AssignAsync` excludes rows where `RAUserId` is `NULL`.
