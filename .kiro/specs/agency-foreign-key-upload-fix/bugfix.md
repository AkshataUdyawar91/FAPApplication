# Bugfix Requirements Document

## Introduction

When agency users attempt to upload documents, the system fails with a database foreign key constraint error. The error occurs because the `DocumentPackage` entity requires a valid `AgencyId`, but the document upload logic does not populate this field when creating new packages. This prevents agency users from uploading any documents, blocking the core submission workflow.

**Error Message:**
```
The INSERT statement conflicted with the FOREIGN KEY constraint "FK_DocumentPackages_Agencies_AgencyId". 
The conflict occurred in database "BajajFAP_Shubhankar", table "dbo.Agencies", column 'Id'.
```

**Impact:** Critical - agency users cannot submit documents, blocking the entire submission workflow.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN an agency user uploads a document and no packageId is provided (first document upload) THEN the system creates a new DocumentPackage without setting the AgencyId field

1.2 WHEN the system attempts to save the DocumentPackage to the database THEN the database rejects the INSERT due to a foreign key constraint violation on AgencyId

1.3 WHEN the foreign key constraint violation occurs THEN the document upload fails with a 500 Internal Server Error and the user cannot proceed

### Expected Behavior (Correct)

2.1 WHEN an agency user uploads a document and no packageId is provided THEN the system SHALL retrieve the user's AgencyId from the User record and set it on the new DocumentPackage

2.2 WHEN the user's AgencyId is null (non-agency user attempting upload) THEN the system SHALL return a 403 Forbidden error with a clear message indicating agency users only

2.3 WHEN the system creates a DocumentPackage with a valid AgencyId THEN the database SHALL accept the INSERT and the document upload SHALL succeed

### Unchanged Behavior (Regression Prevention)

3.1 WHEN an agency user uploads a document with an existing packageId THEN the system SHALL CONTINUE TO use the existing package without creating a new one

3.2 WHEN the system validates file uploads (size, type, malware scan) THEN the system SHALL CONTINUE TO perform all existing validation checks

3.3 WHEN the system extracts document data and stores files in blob storage THEN the system SHALL CONTINUE TO perform these operations as before

3.4 WHEN non-agency users (ASM, HQ) access the system THEN the system SHALL CONTINUE TO function normally for their respective workflows
