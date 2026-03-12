# Implementation Plan: Remove Legacy Documents Table

## Overview

Systematically migrate all services from the legacy `Documents` table to dedicated per-type tables, then remove the legacy entity, DbSet, navigation properties, and database table. Each task builds on the previous one, with tests validating each migration step.

## Tasks

- [x] 1. Create DocumentInfoDto and update IDocumentService interface
  - [x] 1.1 Create `DocumentInfoDto` in `Application/DTOs/Documents/DocumentInfoDto.cs` with properties: Id, PackageId, Type, FileName, BlobUrl, FileSizeBytes, ContentType, ExtractedDataJson, ExtractionConfidence, IsFlaggedForReview
    - _Requirements: 7.5_
  - [x] 1.2 Update `IDocumentService.GetDocumentAsync` signature to return `Task<DocumentInfoDto?>` and accept `(Guid documentId, DocumentType documentType)` instead of `Task<Document?>`
    - _Requirements: 7.5_

- [ ] 2. Migrate DocumentService to dedicated tables
  - [x] 2.1 Refactor `UploadDocumentAsync` to create dedicated entities (PO, Invoice, CostSummary, ActivitySummary, EnquiryDocument, TeamPhotos) based on DocumentType instead of creating a Document entity
    - Replace `_context.Documents.AddAsync(document)` with a switch on documentType that creates the appropriate entity in the correct DbSet
    - Update photo count limit check to query `_context.TeamPhotos` instead of `_context.Documents`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7_
  - [x] 2.2 Refactor `ExtractDocumentDataAsync` to find and update the dedicated entity instead of `_context.Documents.FindAsync(documentId)`
    - Use a switch on documentType to query the correct DbSet
    - _Requirements: 1.8_
  - [x] 2.3 Refactor `GetDocumentAsync` to query the appropriate dedicated table based on documentType and return a `DocumentInfoDto`
    - _Requirements: 1.9, 1.10_
  - [ ]* 2.4 Write property test for upload routing (Property 1)
    - **Property 1: Upload routing by document type**
    - **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.6**
  - [ ]* 2.5 Write property test for upload-then-retrieve round trip (Property 2)
    - **Property 2: Upload-then-retrieve round trip**
    - **Validates: Requirements 1.8, 1.9**

- [x] 3. Migrate ConfidenceScoreService to dedicated tables
  - [x] 3.1 Replace `Include(p => p.Documents)` with dedicated navigations (`Include(p => p.PO)`, `.Include(p => p.Invoices)`, `.Include(p => p.CostSummary)`, `.Include(p => p.ActivitySummary)`, `.Include(p => p.Teams).ThenInclude(t => t.Photos)`) and use `AsSplitQuery()`
    - _Requirements: 2.1_
  - [x] 3.2 Replace `GetDocumentConfidence` and `GetAveragePhotoConfidence` helper methods to read from dedicated entity properties instead of filtering `ICollection<Document>`
    - _Requirements: 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_
  - [ ]* 3.3 Write property test for confidence score calculation from dedicated tables (Property 3)
    - **Property 3: Confidence score calculation from dedicated tables**
    - **Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7**

- [x] 4. Migrate EnhancedValidationReportService to dedicated tables
  - [x] 4.1 Replace `LoadPackageWithAllDataAsync` to use dedicated navigations instead of `Include(p => p.Documents)`
    - _Requirements: 3.1_
  - [x] 4.2 Replace all `package.Documents.FirstOrDefault(d => d.Type == ...)` patterns with dedicated navigation properties (`package.PO`, `package.Invoices.FirstOrDefault()`, `package.Teams.SelectMany(t => t.Photos)`, etc.)
    - Update: BuildPONumberValidation, BuildInvoiceAmountValidation, BuildDateValidation, BuildVendorValidation, BuildCompletenessValidation, BuildTeamPhotoValidation, BuildBrandingValidation
    - _Requirements: 3.2, 3.3, 3.4, 3.5_
  - [ ]* 4.3 Write property test for completeness check from dedicated tables (Property 4)
    - **Property 4: Completeness check from dedicated tables**
    - **Validates: Requirements 3.4, 5.7**

- [ ] 5. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Migrate ValidationAgent to dedicated tables
  - [x] 6.1 Replace package loading query to use dedicated navigations instead of `Include(p => p.Documents)`
    - _Requirements: 5.1_
  - [x] 6.2 Replace all document data extraction patterns: `package.Documents.FirstOrDefault(d => d.Type == ...)` → dedicated navigation properties for PO, Invoice, CostSummary, ActivitySummary, EnquiryDocument
    - _Requirements: 5.2, 5.3, 5.4, 5.5, 5.6_
  - [x] 6.3 Replace photo counting and FileNames population to use TeamPhotos from Teams instead of Documents filtered by TeamPhoto type
    - _Requirements: 5.7, 5.8_

- [x] 7. Migrate WorkflowOrchestrator to dedicated tables
  - [x] 7.1 Replace package loading query to include dedicated navigations (PO, CostSummary, ActivitySummary, EnquiryDocument) alongside existing Teams includes
    - _Requirements: 4.1_
  - [x] 7.2 Add extraction logic for package-level dedicated entities (PO, CostSummary, ActivitySummary, EnquiryDocument) in `ExecuteExtractionStepAsync`
    - _Requirements: 4.2_
  - [x] 7.3 Remove the entire "OLD MODEL" backward-compatibility code path that processes `package.Documents` in `ExecuteExtractionStepAsync`
    - _Requirements: 4.3, 4.4_

- [x] 8. Migrate ChatService to dedicated tables
  - [x] 8.1 Replace `Include(p => p.Documents)` with `Include(p => p.PO)` and `Include(p => p.Invoices)` in the packages query
    - _Requirements: 6.1_
  - [x] 8.2 Replace the document iteration loop that reads from `p.Documents` to read from `p.PO` and `p.Invoices` for extracting invoice/PO details and document counts
    - _Requirements: 6.2, 6.3, 6.4_

- [ ] 9. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 10. Remove legacy Document entity and DbSet
  - [ ] 10.1 Remove `ICollection<Document> Documents` navigation property from `DocumentPackage.cs`
    - _Requirements: 7.3_
  - [ ] 10.2 Remove `DbSet<Document> Documents` from `IApplicationDbContext.cs`
    - _Requirements: 7.1_
  - [ ] 10.3 Remove `DbSet<Document> Documents` property and its soft-delete query filter from `ApplicationDbContext.cs`
    - _Requirements: 7.2_
  - [ ] 10.4 Delete `Document.cs` entity file from `Domain/Entities/`
    - _Requirements: 7.4_
  - [ ] 10.5 Delete any EF Core configuration file for the Document entity if it exists
    - _Requirements: 7.6_

- [ ] 11. Update tests to use dedicated tables
  - [ ] 11.1 Find and update all test files that reference `Document` entity, `context.Documents`, or `package.Documents` to use dedicated entities and DbSets
    - _Requirements: 8.1, 8.2, 8.3_
  - [ ]* 11.2 Write unit tests for edge cases: upload with invalid DocumentType, GetDocumentAsync with non-existent ID, confidence score with missing document types, photo count limit at 50
    - _Requirements: 1.10, 2.7, 1.7_

- [ ] 12. Generate EF Core migration to drop Documents table
  - [ ] 12.1 Run `dotnet ef migrations add RemoveLegacyDocumentsTable` to generate the migration that drops the Documents table and removes related foreign keys
    - _Requirements: 9.1, 9.2, 9.3_

- [ ] 13. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
- The migration (task 12) should be the last code change to ensure the model is fully updated before generating
