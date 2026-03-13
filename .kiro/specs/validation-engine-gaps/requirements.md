# Requirements Document

## Introduction

This specification addresses five gaps identified in a validation engine audit for the Bajaj Document Processing system. The gaps span proactive upload-time validation, duplicate image detection, dedicated face detection, database-backed reference data, and persistence of validation results. Closing these gaps improves data quality, reduces user friction, and ensures auditability of validation outcomes.

## Glossary

- **Validation_Engine**: The backend subsystem that performs field presence checks, cross-document validation, and reference data lookups on document packages.
- **Proactive_Validator**: A new component that runs field presence validations immediately when a document is uploaded, before the package is submitted for full processing.
- **Reactive_Validator**: The existing `ValidatePackageAsync` flow that runs all validations (field presence + cross-document + SAP) during the submit/workflow pipeline.
- **Perceptual_Hash**: A hash derived from image visual content (not file bytes) that produces similar values for visually similar images, enabling duplicate detection even when files differ at the byte level.
- **Face_Detector**: A component that uses Azure OpenAI GPT-4 Vision to detect human faces in uploaded photos, independent of blue t-shirt detection.
- **Reference_Data_Store**: SQL Server tables (`State_GST_Master`, `HSN_Master`, `Cost_Master`, `Cost_Master_State_Rates`) that replace in-memory dictionaries for GST mappings, HSN codes, cost elements, and state-wise cost rates.
- **Validation_Result_Persister**: The component responsible for saving per-document-type validation results to the `ValidationResults` database table.
- **PhotoMetadata**: The DTO representing AI-extracted and EXIF metadata for uploaded photos.
- **DocumentPackage**: A collection of related documents (PO, Invoice, Cost Summary, Activity Summary, Enquiry Dump, Photos) submitted together for processing.
- **Agency_User**: A user who uploads document packages and tracks processing status.

## Requirements

### Requirement 1: Proactive Validation on Upload

**User Story:** As an Agency_User, I want to receive instant field presence validation errors when I upload a document, so that I can correct and re-upload before submitting the full package.

#### Acceptance Criteria

1. WHEN an Agency_User uploads a document via the upload endpoint, THE Proactive_Validator SHALL extract data from the document and run field presence checks for that document type within the same request.
2. WHEN field presence validation detects missing fields, THE Proactive_Validator SHALL return the list of missing fields and a pass/fail status in the upload response.
3. WHEN field presence validation passes with no missing fields, THE Proactive_Validator SHALL return a success status with an empty missing fields list in the upload response.
4. WHEN the Proactive_Validator encounters an extraction or validation error, THE Proactive_Validator SHALL return the upload success response with a warning indicating validation could not be completed, rather than failing the upload.
5. THE Reactive_Validator SHALL continue to perform all validations (field presence, cross-document, SAP) during the submit workflow, independent of whether proactive validation ran on upload.
6. WHEN a new API endpoint for proactive validation is exposed, THE API SHALL require JWT authentication and verify resource ownership before returning results.

### Requirement 2: Duplicate Image Detection

**User Story:** As an Agency_User, I want the system to detect duplicate photos within my uploaded package, so that I do not accidentally submit the same photo multiple times.

#### Acceptance Criteria

1. WHEN photos are uploaded to a DocumentPackage, THE Validation_Engine SHALL compute a Perceptual_Hash for each photo.
2. WHEN two or more photos within the same DocumentPackage have Perceptual_Hash values within a configurable similarity threshold, THE Validation_Engine SHALL flag those photos as potential duplicates.
3. WHEN duplicate photos are detected, THE Validation_Engine SHALL include the duplicate photo pairs and their similarity scores in the validation result.
4. THE PhotoMetadata SHALL include a `PerceptualHash` field that stores the computed hash string for each photo.
5. WHEN the Perceptual_Hash computation fails for a photo, THE Validation_Engine SHALL log a warning and skip duplicate detection for that photo rather than failing the entire validation.

### Requirement 3: Dedicated Face Detection

**User Story:** As an Agency_User, I want the system to detect human faces in uploaded photos independently of blue t-shirt detection, so that photo validation accurately reflects whether people are present.

#### Acceptance Criteria

1. THE PhotoMetadata SHALL include a `HasHumanFace` boolean field indicating whether a human face was detected in the photo.
2. THE PhotoMetadata SHALL include a `FaceCount` integer field indicating the number of human faces detected.
3. THE PhotoMetadata SHALL include a `FaceDetectionConfidence` numeric field (0-100) indicating the AI confidence score for face detection.
4. WHEN the DocumentAgent extracts photo metadata via Azure OpenAI GPT-4 Vision, THE DocumentAgent SHALL request face detection as a separate analysis from blue t-shirt detection.
5. WHEN face detection data is available, THE Validation_Engine SHALL use the `HasHumanFace` field instead of `HasBlueTshirtPerson` as the indicator for human presence in photo validation reports.

### Requirement 4: Database-Backed Reference Data

**User Story:** As a system administrator, I want reference data (GST state mappings, HSN codes, cost elements, state-wise cost rates) stored in SQL Server tables, so that the data can be updated without code deployments.

#### Acceptance Criteria

1. THE Reference_Data_Store SHALL provide a `State_GST_Master` table containing GST state code to state name mappings, with columns for GST code (2-digit string) and state code (string).
2. THE Reference_Data_Store SHALL provide an `HSN_Master` table containing valid HSN/SAC codes, with columns for code (string), description (string), and active status (boolean).
3. THE Reference_Data_Store SHALL provide a `Cost_Master` table containing cost element definitions, with columns for element name (string) and expense nature (string, either "Fixed Cost" or "Cost per Day").
4. THE Reference_Data_Store SHALL provide a `Cost_Master_State_Rates` table containing state-wise cost rates, with columns for state code (string), element name (string), rate value (decimal), and rate type (string, either "Amount" or "Percentage").
5. WHEN the Validation_Engine validates GST state mappings, THE Validation_Engine SHALL query the `State_GST_Master` table instead of in-memory dictionaries.
6. WHEN the Validation_Engine validates HSN/SAC codes, THE Validation_Engine SHALL query the `HSN_Master` table instead of in-memory dictionaries.
7. WHEN the Validation_Engine validates cost element rates against state limits, THE Validation_Engine SHALL query the `Cost_Master` and `Cost_Master_State_Rates` tables instead of in-memory dictionaries.
8. THE Reference_Data_Store SHALL be seeded with the initial reference data via an EF Core migration, including all 15 cost elements, all 10 state rate rows, all GST state codes, and the initial HSN/SAC codes.
9. THE IReferenceDataService interface SHALL remain unchanged so that existing consumers are not affected by the storage migration.

### Requirement 5: Validation Result Persistence

**User Story:** As a system administrator, I want validation results persisted to the database for each document type, so that validation history is auditable and queryable.

#### Acceptance Criteria

1. WHEN the Reactive_Validator completes validation for a DocumentPackage, THE Validation_Result_Persister SHALL save a separate ValidationResult entity for each document type that was validated (PO, Invoice, CostSummary, ActivitySummary, EnquiryDocument, TeamPhotos).
2. WHEN a ValidationResult entity is saved, THE Validation_Result_Persister SHALL populate the `DocumentType`, `DocumentId`, `AllValidationsPassed`, `ValidationDetailsJson`, and `FailureReason` fields.
3. WHEN a DocumentPackage is re-validated, THE Validation_Result_Persister SHALL update existing ValidationResult entities for that package rather than creating duplicates.
4. WHEN saving a ValidationResult fails, THE Validation_Result_Persister SHALL log the error and continue the workflow without blocking the validation pipeline.
5. THE Validation_Result_Persister SHALL serialize the full per-document validation details (field presence result and cross-document result) into the `ValidationDetailsJson` field.
