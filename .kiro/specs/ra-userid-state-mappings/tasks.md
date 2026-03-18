# Implementation Plan: RA UserId State Mappings

## Overview

Add `RAUserId` to `StateMappings` and `AssignedRAUserId` to `DocumentPackages`, create an `RAAssignmentService` mirroring the CircleHead pattern, and integrate RA auto-assignment into the ASM approval flow. Each task builds incrementally: domain entities first, then EF configuration and migration, then the service, then controller integration, then tests.

## Tasks

- [x] 1. Add RAUserId to StateMapping entity and AssignedRAUserId to DocumentPackage entity
  - [x] 1.1 Add `RAUserId` property (`Guid?`) to `StateMapping.cs`
    - Add the nullable GUID property with XML doc comment below `CircleHeadUserId`
    - _Requirements: 1.1_
  - [x] 1.2 Add `AssignedRAUserId` property (`Guid?`) to `DocumentPackage.cs`
    - Add the nullable GUID property with XML doc comment below `AssignedCircleHeadUserId`
    - _Requirements: 4.4_

- [x] 2. Configure EF Core mapping and create migration
  - [x] 2.1 Update `StateMappingConfiguration.cs` to configure `RAUserId`
    - Add `builder.Property(s => s.RAUserId);`
    - Add `builder.HasIndex(s => s.RAUserId).HasDatabaseName("IX_StateMappings_RAUserId");`
    - _Requirements: 1.2, 1.3_
  - [x] 2.2 Generate EF Core migration `AddRAUserIdToStateMappings`
    - Run: `dotnet ef migrations add AddRAUserIdToStateMappings --project src/BajajDocumentProcessing.Infrastructure --startup-project src/BajajDocumentProcessing.API`
    - Verify the `Up` method adds nullable `RAUserId` (uniqueidentifier) to `StateMappings`, nullable `AssignedRAUserId` to `DocumentPackages`, and creates index `IX_StateMappings_RAUserId`
    - Verify the `Down` method drops the index and both columns
    - _Requirements: 1.4, 2.1, 2.2, 2.4_

- [x] 3. Checkpoint - Verify domain and migration
  - Ensure the solution builds cleanly (`dotnet build`). Review the generated migration for correctness. Ask the user if questions arise.

- [x] 4. Create IRAAssignmentService interface and RAAssignmentService implementation
  - [x] 4.1 Create `IRAAssignmentService.cs` in `Application/Common/Interfaces/`
    - Define interface with `Task<Guid?> AssignAsync(string submissionState, CancellationToken cancellationToken = default)`
    - Mirror `ICircleHeadAssignmentService` structure
    - _Requirements: 3.1_
  - [x] 4.2 Create `RAAssignmentService.cs` in `Infrastructure/Services/`
    - Inject `IApplicationDbContext` and `ILogger<RAAssignmentService>`
    - Query `StateMappings` with `AsNoTracking()` filtering by `State == submissionState`, `IsActive`, `!IsDeleted`, `RAUserId != null`
    - Select distinct `RAUserId` values
    - If 0 results: return `null`, log warning
    - If 1 result: return it directly
    - If multiple: load-balance by counting `DocumentPackages` where `AssignedRAUserId` is in candidate set, `State == PendingRA`, `!IsDeleted`, grouped by `AssignedRAUserId`, pick lowest count, fall back to first candidate
    - Propagate `CancellationToken` through all async calls
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_
  - [x] 4.3 Register `IRAAssignmentService` in `DependencyInjection.cs`
    - Add `services.AddScoped<IRAAssignmentService, RAAssignmentService>();` after the CircleHead registration line
    - _Requirements: 3.1_

- [x] 5. Integrate RA assignment into ASM approval flow
  - [x] 5.1 Inject `IRAAssignmentService` into `SubmissionsController`
    - Add constructor parameter and private field `_raAssignmentService`
    - _Requirements: 4.1_
  - [x] 5.2 Call `RAAssignmentService.AssignAsync` in `ASMApproveSubmission`
    - After `package.State = PackageState.PendingRA`, call `var raUserId = await _raAssignmentService.AssignAsync(package.ActivityState, cancellationToken);`
    - Set `package.AssignedRAUserId = raUserId`
    - If `raUserId` is null, log a warning but continue the approval flow
    - _Requirements: 4.1, 4.2, 4.3_

- [x] 6. Checkpoint - Verify end-to-end wiring
  - Ensure the solution builds cleanly. Verify DI registration compiles. Ensure all tests pass (`dotnet test`). Ask the user if questions arise.

- [ ]* 7. Write unit tests for RAAssignmentService
  - [ ]* 7.1 Create `RAAssignmentServiceTests.cs` in `tests/BajajDocumentProcessing.Tests/Infrastructure/`
    - Use xUnit `[Fact]` tests with Moq for `IApplicationDbContext` and `ILogger<RAAssignmentService>`
    - `AssignAsync_SingleRA_ReturnsGuid`: single distinct RA user for state returns that GUID
    - `AssignAsync_MultipleRA_ReturnsLeastLoaded`: multiple RA users returns the one with fewest PendingRA packages
    - `AssignAsync_NoRA_ReturnsNull`: no matching RA user returns null
    - `AssignAsync_ExcludesInactiveAndDeleted`: inactive/deleted rows are excluded
    - `AssignAsync_ExcludesNullRAUserId`: rows with null RAUserId are excluded
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [ ]* 8. Write property-based tests for RAAssignmentService
  - [ ]* 8.1 Write property test for filtering invariant
    - **Property 1: RA assignment filtering invariant**
    - Use FsCheck `[Property(MaxTest = 100)]` with random StateMappings rows varying `IsActive`, `IsDeleted`, `State`, `RAUserId` nullability
    - Assert that only rows matching `IsActive == true && !IsDeleted && State == submissionState && RAUserId != null` influence the result
    - `// Feature: ra-userid-state-mappings, Property 1: RA assignment filtering invariant`
    - **Validates: Requirements 3.2, 6.2**
  - [ ]* 8.2 Write property test for single RA user direct return
    - **Property 2: Single RA user direct return**
    - Use FsCheck `[Property(MaxTest = 100)]` generating scenarios with exactly one distinct non-null RAUserId
    - Assert that `AssignAsync` returns that exact RAUserId
    - `// Feature: ra-userid-state-mappings, Property 2: Single RA user direct return`
    - **Validates: Requirements 3.3**
  - [ ]* 8.3 Write property test for load-balanced assignment
    - **Property 3: Load-balanced assignment picks least-loaded RA**
    - Use FsCheck `[Property(MaxTest = 100)]` generating multiple distinct RA users with varying PendingRA package counts
    - Assert that `AssignAsync` returns the RAUserId with the fewest pending packages (or any tied user)
    - `// Feature: ra-userid-state-mappings, Property 3: Load-balanced assignment picks least-loaded RA`
    - **Validates: Requirements 3.4**
  - [ ]* 8.4 Write property test for no matching RA returns null
    - **Property 4: No matching RA returns null**
    - Use FsCheck `[Property(MaxTest = 100)]` generating scenarios where no qualifying rows exist
    - Assert that `AssignAsync` returns null
    - `// Feature: ra-userid-state-mappings, Property 4: No matching RA returns null`
    - **Validates: Requirements 3.5**

- [x] 9. Final checkpoint - Ensure all tests pass
  - Run `dotnet test` and ensure all tests pass. Ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- The EF migration must be generated (task 2.2) — it cannot be hand-written since EF Core scaffolds it from the model snapshot
