# Implementation Plan: Validation Engine Gaps

## Overview

Implements five validation engine gaps in order: reference data tables (foundation), photo metadata fields, duplicate detection, face detection, proactive validation endpoint, and validation result persistence. Each task builds incrementally, with tests close to implementation.

## Tasks

- [x] 1. Create reference data domain entities and EF Core migration
  - [x] 1.1 Create domain entities `StateGstMaster`, `HsnMaster`, `CostMaster`, `CostMasterStateRate` in `BajajDocumentProcessing.Domain/Entities/`
    - Each entity extends `BaseEntity` with fields per design (GstCode/StateCode/StateName/IsActive, Code/Description/IsActive, ElementName/ExpenseNature/IsActive, StateCode/ElementName/RateValue/RateType/IsActive)
    - _Requirements: 4.1, 4.2, 4.3, 4.4_
  - [x] 1.2 Add `DbSet` properties to `IApplicationDbContext` and `ApplicationDbContext` for the four new entities, add soft-delete query filters
    - _Requirements: 4.1, 4.2, 4.3, 4.4_
  - [x] 1.3 Create EF Core entity configurations in `Infrastructure/Persistence/Configurations/` for indexes and constraints
    - Index `StateGstMaster` on `GstCode`; index `HsnMaster` on `Code`; index `CostMasterStateRate` on `(StateCode, ElementName)`
    - _Requirements: 4.1, 4.2, 4.3, 4.4_
  - [x] 1.4 Create EF Core migration that creates the four tables and seeds initial data (38 GST codes, ~15 HSN codes, 15 cost elements, 10 states × 15 rate rows)
    - _Requirements: 4.8_

- [x] 2. Refactor ReferenceDataService to use database tables
  - [x] 2.1 Inject `IApplicationDbContext` and `IMemoryCache` into `ReferenceDataService`, replace static dictionaries with DB queries cached with 1-hour TTL
    - `ValidateGSTStateMapping` → query `StateGstMasters`
    - `ValidateHSNSACCode` → query `HsnMasters`
    - `ValidateElementCostAgainstStateRate`, `ValidateFixedCostLimit`, `ValidateVariableCostLimit`, `GetStateRate` → query `CostMasterStateRates`
    - `GetStateCodeFromGST` → query `StateGstMasters`
    - `GetDefaultGSTPercentage` → unchanged (returns 18%)
    - _Requirements: 4.5, 4.6, 4.7, 4.9_
  - [ ]* 2.2 Write property test: GST validation from DB matches seeded data
    - **Property 4: GST state mapping validation matches seeded data**
    - **Validates: Requirements 4.5**
  - [ ]* 2.3 Write property test: HSN validation from DB matches seeded data
    - **Property 5: HSN/SAC code validation matches seeded data**
    - **Validates: Requirements 4.6**
  - [ ]* 2.4 Write property test: Cost rate validation uses database rates
    - **Property 6: Cost rate validation uses database rates**
    - **Validates: Requirements 4.7**

- [x] 3. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Add face detection and perceptual hash fields to PhotoMetadata
  - [x] 4.1 Add `HasHumanFace` (bool), `FaceCount` (int), `FaceDetectionConfidence` (double), and `PerceptualHash` (string?) fields to `PhotoMetadata` DTO
    - _Requirements: 3.1, 3.2, 3.3, 2.4_
  - [x] 4.2 Add `HasHumanFace`, `FaceCount`, `FaceDetectionConfidence` fields to `PhotoVisionResponse` internal class in `DocumentAgent.cs` and extend the GPT-4 Vision prompt to request face detection
    - _Requirements: 3.4_
  - [x] 4.3 Update `DocumentAgent.ExtractPhotoMetadataAsync` to map the new face detection fields from `PhotoVisionResponse` to `PhotoMetadata`
    - _Requirements: 3.4_

- [x] 5. Implement duplicate image detection
  - [x] 5.1 Create `IPerceptualHashService` interface in `Application/Common/Interfaces/` with `ComputeHashAsync` and `ComputeSimilarity` methods
    - _Requirements: 2.1_
  - [x] 5.2 Implement `PerceptualHashService` in `Infrastructure/Services/` using average hash (aHash) algorithm: resize to 8×8 grayscale, compute mean, generate 64-bit hash, Hamming distance for similarity
    - _Requirements: 2.1_
  - [x] 5.3 Register `IPerceptualHashService` in `DependencyInjection.cs`, integrate into `DocumentAgent.ExtractPhotoMetadataAsync` to compute and store `PerceptualHash` in `PhotoMetadata`
    - _Requirements: 2.1_
  - [x] 5.4 Add `DuplicatePhotoPair` class and `DuplicatePhotos` list to `PhotoFieldPresenceResult`, add `PhotosWithFace` count field
    - _Requirements: 2.3, 3.5_
  - [x] 5.5 Update `ValidationAgent.ValidatePhotoFieldPresence` to compare perceptual hashes across photos and populate `DuplicatePhotos` list, and count `PhotosWithFace` using `HasHumanFace` instead of `HasBlueTshirtPerson`
    - _Requirements: 2.2, 3.5_
  - [x] 5.6 Update `EnhancedValidationReportService` to use `HasHumanFace` instead of `HasBlueTshirtPerson` for face counting
    - _Requirements: 3.5_
  - [ ]* 5.7 Write property test: Duplicate photo detection identifies all pairs within threshold
    - **Property 2: Duplicate photo detection identifies all pairs within threshold**
    - **Validates: Requirements 2.2, 2.3**
  - [ ]* 5.8 Write property test: Face detection field used for human presence in reports
    - **Property 3: Face detection field usage in reports**
    - **Validates: Requirements 3.5**

- [x] 6. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Implement proactive validation on upload
  - [x] 7.1 Create `ProactiveValidationResult` DTO in `Application/DTOs/Documents/` and `IProactiveValidator` interface in `Application/Common/Interfaces/`
    - _Requirements: 1.2, 1.3_
  - [x] 7.2 Implement `ProactiveValidator` service in `Infrastructure/Services/` that loads a document by ID, deserializes `ExtractedDataJson`, and runs the appropriate field presence check method (reuse existing validation logic from `ValidationAgent`)
    - _Requirements: 1.1_
  - [x] 7.3 Register `IProactiveValidator` in `DependencyInjection.cs`
    - _Requirements: 1.1_
  - [x] 7.4 Add `POST /api/documents/{id}/validate` endpoint to `DocumentsController` with JWT auth, resource ownership check, and error handling that returns warnings instead of failures
    - _Requirements: 1.1, 1.4, 1.6_
  - [ ]* 7.5 Write property test: Proactive validation pass/fail is consistent with missing fields
    - **Property 1: Proactive validation pass/fail consistency**
    - **Validates: Requirements 1.1, 1.2, 1.3**

- [x] 8. Implement validation result persistence
  - [x] 8.1 Refactor `SaveValidationResultAsync` in `ValidationAgent` to save per-document-type `ValidationResult` entities (create or update pattern), serialize per-document details into `ValidationDetailsJson`
    - _Requirements: 5.1, 5.2, 5.5_
  - [x] 8.2 Re-enable the `SaveValidationResultAsync` call in `ValidatePackageAsync`, remove the TODO comment and commented-out code in `WorkflowOrchestrator.ExecuteValidationStepAsync`
    - _Requirements: 5.1_
  - [x] 8.3 Add error handling: wrap each per-document save in try/catch, log errors, continue with remaining document types
    - _Requirements: 5.4_
  - [ ]* 8.4 Write property test: Per-document-type ValidationResult count matches validated documents
    - **Property 7: Per-document-type ValidationResult count**
    - **Validates: Requirements 5.1**
  - [ ]* 8.5 Write property test: ValidationResult fields are fully populated
    - **Property 8: ValidationResult field population**
    - **Validates: Requirements 5.2**
  - [ ]* 8.6 Write property test: Re-validation is idempotent on ValidationResult count
    - **Property 9: Re-validation idempotency**
    - **Validates: Requirements 5.3**
  - [ ]* 8.7 Write property test: ValidationDetailsJson round-trip serialization
    - **Property 10: ValidationDetailsJson round-trip**
    - **Validates: Requirements 5.5**

- [x] 9. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- The `IReferenceDataService` interface is intentionally unchanged to maintain backward compatibility
- The existing `ValidatePackageAsync` reactive flow is not modified except for re-enabling persistence and adding duplicate/face detection to photo validation
