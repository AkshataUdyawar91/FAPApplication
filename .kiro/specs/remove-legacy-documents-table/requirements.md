# Requirements Document

## Introduction

Remove the legacy `Documents` table and `Document` entity from the codebase. The database redesign spec introduced dedicated tables for each document type (PO, Invoice, CostSummary, ActivitySummary, EnquiryDocument, AdditionalDocument, Teams, TeamPhotos), but the old generic `Documents` table — where all document types were stored with a `Type` discriminator column — is still referenced across many services. This spec covers migrating all service code to use the new dedicated tables and removing the legacy entity, DbSet, navigation properties, and related test code.

## Glossary

- **Legacy_Documents_Table**: The generic `Documents` database table and `Document` entity class that stores all document types in a single table with a `Type` discriminator column
- **Dedicated_Document_Tables**: The new normalized tables (PO, Invoice, CostSummary, ActivitySummary, EnquiryDocument, AdditionalDocument, Teams, TeamPhotos) that each store a specific document type
- **DocumentService**: The infrastructure service responsible for uploading documents, saving extracted data, and retrieving documents
- **ConfidenceScoreService**: The infrastructure service that calculates weighted confidence scores from document extraction confidence values
- **EnhancedValidationReportService**: The infrastructure service that generates validation reports by reading extracted data from documents
- **WorkflowOrchestrator**: The infrastructure service that orchestrates the document processing pipeline (extraction, validation, scoring, recommendation)
- **ValidationAgent**: The infrastructure service that performs cross-document validation and SAP verification
- **ChatService**: The infrastructure service that provides conversational AI by querying document data for context
- **DocumentAgent**: The infrastructure service that classifies documents and extracts structured data using Azure OpenAI
- **IApplicationDbContext**: The application-layer interface defining all DbSet properties for database access
- **ApplicationDbContext**: The EF Core DbContext implementation
- **DocumentPackage**: The central submission entity that owns all document relationships
- **PackageId**: The foreign key linking documents to their parent DocumentPackage

## Requirements

### Requirement 1: Migrate DocumentService to Dedicated Tables

**User Story:** As a developer, I want the DocumentService to create and retrieve documents using the dedicated tables, so that uploads are stored in the correct normalized table instead of the legacy Documents table.

#### Acceptance Criteria

1. WHEN a PO file is uploaded, THE DocumentService SHALL create a PO entity in the POs table instead of a Document entity in the Documents table
2. WHEN an Invoice file is uploaded, THE DocumentService SHALL create an Invoice entity in the Invoices table instead of a Document entity in the Documents table
3. WHEN a CostSummary file is uploaded, THE DocumentService SHALL create a CostSummary entity in the CostSummaries table instead of a Document entity in the Documents table
4. WHEN an ActivitySummary file is uploaded, THE DocumentService SHALL create an ActivitySummary entity in the ActivitySummaries table instead of a Document entity in the Documents table
5. WHEN an EnquiryDocument file is uploaded, THE DocumentService SHALL create an EnquiryDocument entity in the EnquiryDocuments table instead of a Document entity in the Documents table
6. WHEN a TeamPhoto file is uploaded, THE DocumentService SHALL create a TeamPhotos entity in the TeamPhotos table instead of a Document entity in the Documents table
7. WHEN a photo count limit check is performed, THE DocumentService SHALL query the TeamPhotos table instead of filtering Documents by Type
8. WHEN extraction data is saved after upload, THE DocumentService SHALL update the ExtractedDataJson and ExtractionConfidence on the dedicated entity instead of the Document entity
9. WHEN GetDocumentAsync is called, THE DocumentService SHALL query the appropriate dedicated table based on document type
10. IF an unsupported DocumentType is provided, THEN THE DocumentService SHALL return a descriptive error

### Requirement 2: Migrate ConfidenceScoreService to Dedicated Tables

**User Story:** As a developer, I want the ConfidenceScoreService to read extraction confidence from the dedicated tables, so that confidence scoring works without the legacy Documents collection.

#### Acceptance Criteria

1. WHEN calculating confidence scores, THE ConfidenceScoreService SHALL load the package with dedicated document navigations (PO, CostSummary, ActivitySummary, Invoices, Teams with TeamPhotos) instead of the Documents collection
2. WHEN reading PO confidence, THE ConfidenceScoreService SHALL read ExtractionConfidence from the PO entity
3. WHEN reading Invoice confidence, THE ConfidenceScoreService SHALL read ExtractionConfidence from the first Invoice entity in the package
4. WHEN reading CostSummary confidence, THE ConfidenceScoreService SHALL read ExtractionConfidence from the CostSummary entity
5. WHEN reading ActivitySummary confidence, THE ConfidenceScoreService SHALL read ExtractionConfidence from the ActivitySummary entity
6. WHEN reading photo confidence, THE ConfidenceScoreService SHALL calculate the average ExtractionConfidence across all TeamPhotos in the package
7. IF a dedicated document entity is missing for a document type, THEN THE ConfidenceScoreService SHALL use confidence value 0.0 for that type

### Requirement 3: Migrate EnhancedValidationReportService to Dedicated Tables

**User Story:** As a developer, I want the EnhancedValidationReportService to read extracted data from the dedicated tables, so that validation reports are generated from the normalized schema.

#### Acceptance Criteria

1. WHEN loading package data for a report, THE EnhancedValidationReportService SHALL include dedicated document navigations (PO, CostSummary, Invoices, Teams with TeamPhotos) instead of the Documents collection
2. WHEN building PO validation categories, THE EnhancedValidationReportService SHALL read ExtractedDataJson from the PO entity instead of filtering Documents by Type
3. WHEN building Invoice validation categories, THE EnhancedValidationReportService SHALL read ExtractedDataJson from the first Invoice entity instead of filtering Documents by Type
4. WHEN building completeness checks, THE EnhancedValidationReportService SHALL check for the existence of PO, Invoice, CostSummary, and TeamPhotos entities instead of filtering Documents by Type
5. WHEN building photo quality and branding validations, THE EnhancedValidationReportService SHALL iterate over TeamPhotos entities instead of filtering Documents by TeamPhoto type

### Requirement 4: Migrate WorkflowOrchestrator to Dedicated Tables

**User Story:** As a developer, I want the WorkflowOrchestrator to process documents through the dedicated tables, so that the workflow pipeline no longer depends on the legacy Documents collection.

#### Acceptance Criteria

1. WHEN loading a package for processing, THE WorkflowOrchestrator SHALL include dedicated document navigations (PO, CostSummary, ActivitySummary, EnquiryDocument, Invoices, Teams with TeamPhotos) instead of the Documents collection
2. WHEN executing the extraction step, THE WorkflowOrchestrator SHALL extract data from dedicated entities (PO, CostSummary, ActivitySummary, EnquiryDocument) and save results to those entities
3. WHEN executing the extraction step for photos, THE WorkflowOrchestrator SHALL process TeamPhotos entities instead of Documents filtered by TeamPhoto type
4. THE WorkflowOrchestrator SHALL remove the backward-compatibility code path that processes the old Documents collection

### Requirement 5: Migrate ValidationAgent to Dedicated Tables

**User Story:** As a developer, I want the ValidationAgent to read document data from the dedicated tables, so that validation logic no longer depends on the legacy Documents collection.

#### Acceptance Criteria

1. WHEN loading a package for validation, THE ValidationAgent SHALL include dedicated document navigations (PO, CostSummary, ActivitySummary, EnquiryDocument, Invoices, Teams with TeamPhotos) instead of the Documents collection
2. WHEN extracting PO data for validation, THE ValidationAgent SHALL read ExtractedDataJson from the PO entity instead of filtering Documents by Type
3. WHEN extracting Invoice data for validation, THE ValidationAgent SHALL read ExtractedDataJson from the first Invoice entity instead of filtering Documents by Type
4. WHEN extracting CostSummary data for validation, THE ValidationAgent SHALL read ExtractedDataJson from the CostSummary entity instead of filtering Documents by Type
5. WHEN extracting ActivitySummary data for validation, THE ValidationAgent SHALL read ExtractedDataJson from the ActivitySummary entity instead of filtering Documents by Type
6. WHEN extracting EnquiryDocument data for validation, THE ValidationAgent SHALL read ExtractedDataJson from the EnquiryDocument entity instead of filtering Documents by Type
7. WHEN counting photos for validation, THE ValidationAgent SHALL count TeamPhotos entities instead of filtering Documents by TeamPhoto type
8. WHEN populating FileNames for validation output, THE ValidationAgent SHALL read file names from dedicated entities instead of the Documents collection

### Requirement 6: Migrate ChatService to Dedicated Tables

**User Story:** As a developer, I want the ChatService to query document data from the dedicated tables, so that chat context is built from the normalized schema.

#### Acceptance Criteria

1. WHEN loading packages for chat context, THE ChatService SHALL include dedicated document navigations (PO, Invoices, Teams with TeamPhotos) instead of the Documents collection
2. WHEN extracting invoice details for chat context, THE ChatService SHALL read from Invoice entities instead of filtering Documents by Type
3. WHEN extracting PO details for chat context, THE ChatService SHALL read from the PO entity instead of filtering Documents by Type
4. WHEN counting documents for chat context, THE ChatService SHALL sum counts from dedicated tables instead of counting Documents

### Requirement 7: Remove Legacy Document Entity and DbSet

**User Story:** As a developer, I want the legacy Document entity, DbSet, and navigation properties removed, so that the codebase has a single source of truth for document storage.

#### Acceptance Criteria

1. THE IApplicationDbContext SHALL remove the `DbSet<Document> Documents` property
2. THE ApplicationDbContext SHALL remove the `DbSet<Document> Documents` property and its soft-delete query filter
3. THE DocumentPackage entity SHALL remove the `ICollection<Document> Documents` navigation property
4. THE Document.cs entity file SHALL be deleted from the Domain layer
5. THE IDocumentService interface SHALL replace the `GetDocumentAsync` return type to no longer reference the Document entity
6. IF any EF Core configuration exists for the Document entity, THEN THE configuration file SHALL be deleted

### Requirement 8: Update Tests to Use Dedicated Tables

**User Story:** As a developer, I want all tests updated to use the dedicated tables, so that the test suite validates the new schema without referencing the legacy Documents table.

#### Acceptance Criteria

1. WHEN tests create document data, THE test code SHALL create dedicated entities (PO, Invoice, CostSummary, etc.) instead of Document entities
2. WHEN tests query document data, THE test code SHALL query dedicated DbSets instead of the Documents DbSet
3. WHEN tests set up package data with documents, THE test code SHALL use dedicated navigation properties instead of the Documents collection
4. THE test project SHALL compile and pass after all Document references are removed

### Requirement 9: Create EF Core Migration

**User Story:** As a developer, I want an EF Core migration generated that drops the Documents table, so that the database schema matches the updated entity model.

#### Acceptance Criteria

1. WHEN the migration is applied, THE migration SHALL drop the Documents table from the database
2. WHEN the migration is applied, THE migration SHALL remove the Documents foreign key from DocumentPackages if it exists
3. THE migration SHALL be idempotent and safe to run on databases where the Documents table has already been removed
