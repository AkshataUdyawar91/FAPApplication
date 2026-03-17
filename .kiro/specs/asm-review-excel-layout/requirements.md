# Requirements Document

## Introduction

Redesign the ASM/FAP review page to adopt an Excel-based layout structure that presents document validation information in a cleaner, more organized tabular format. The new design moves action buttons to the header, introduces an invoice summary section, and replaces the current document card sections with two main tables: Invoice and Additional Documents table, and Campaign Details table (grouped by dealer with photos).

## Glossary

- **ASM_Review_Page**: The Flutter page where Area Sales Managers review and approve/reject FAP submissions
- **FAP**: Fund Approval Package - a submission containing invoice, PO, cost summary, and event photos
- **Invoice_Summary_Section**: A header area displaying key invoice information (amount, agency, submission date)
- **Invoice_Documents_Table**: A table displaying invoice and additional documents with columns for S.No, Category, Document name, Status, and Remarks
- **Campaign_Details_Table**: A table displaying dealer-wise campaign information with photos, grouped by dealer
- **Validation_Status**: The pass/fail status of document validation (ok/failed)
- **Validation_Remarks**: AI-generated feedback about document validation (e.g., "photo was clear", "photo was not clear")
- **Dealer_Group**: A logical grouping of campaign photos by dealer (D1, D2, etc.)
- **Action_Buttons**: The Approve FAP and Reject FAP buttons used for review decisions

## Requirements

### Requirement 1: Header Section with Action Buttons and Comments

**User Story:** As an ASM, I want the action buttons (Approve/Reject) and comments section in the header area only when the submission is pending review, so that I can quickly access review actions and add comments without scrolling and avoid taking actions on already-processed submissions.

#### Acceptance Criteria

1. THE ASM_Review_Page SHALL display a back button in the header section
2. THE ASM_Review_Page SHALL display action buttons (Reject, Send Back, Approve Request) in the header section ONLY when the submission state is "PendingASMApproval", "PendingApproval", or "RejectedByHQ"
3. THE ASM_Review_Page SHALL display a Comments section in the header below the action buttons ONLY when the submission state is "PendingASMApproval", "PendingApproval", or "RejectedByHQ"
4. THE ASM_Review_Page SHALL NOT display action buttons or comments section when the submission state is "Approved", "Rejected", "ApprovedByASM", "RejectedByASM", or any other final state
5. THE Comments_Section SHALL provide a multi-line text input field for entering review comments
6. THE Comments_Section SHALL be labeled as "Comments (Optional)" to indicate it is not mandatory
7. WHEN the Approve Request button is clicked, THE ASM_Review_Page SHALL include the comments text in the approval API request
8. THE Comments_Section SHALL allow empty comments (optional field)
9. WHEN the Approve Request button is clicked, THE ASM_Review_Page SHALL trigger the approval workflow
10. WHEN the Reject button is clicked, THE ASM_Review_Page SHALL prompt for rejection reason before triggering the rejection workflow
11. WHEN the Send Back button is clicked, THE ASM_Review_Page SHALL prompt for rejection reason before triggering the rejection workflow
12. WHILE a review action is processing, THE ASM_Review_Page SHALL disable all action buttons and show a loading indicator
13. IF the user has not provided a rejection reason, THEN THE ASM_Review_Page SHALL display an error message and prevent submission
14. THE ASM_Review_Page SHALL display the submission status badge in the header section showing the current state (Submitted, Approved, Rejected, etc.)
15. THE ASM_Review_Page SHALL display the REQ number derived from the submission ID (format: REQ-{first 8 characters of submission ID in uppercase})
16. THE ASM_Review_Page SHALL display the actual submission date from the API response (formatted as DD MMM YYYY, e.g., "01 Jan 1999")
17. THE ASM_Review_Page SHALL display the actual location/region information from the submission data (e.g., agency location, dealer location, or submission metadata)
18. IF location data is not available in the submission, THE ASM_Review_Page SHALL NOT display the location icon or location text (hide the entire location section)

**Note**: The "Put On Hold" button is not required and should not be implemented.

### Requirement 2: Invoice Summary Section

**User Story:** As an ASM, I want to see key invoice information at a glance, so that I can quickly understand the submission context.

#### Acceptance Criteria

1. THE ASM_Review_Page SHALL display an Invoice Summary section below the header
2. THE Invoice_Summary_Section SHALL display the Invoice Amount extracted from the invoice document
3. THE Invoice_Summary_Section SHALL display the Agency name (submitter information)
4. THE Invoice_Summary_Section SHALL display the Submitted on date
5. WHEN invoice data is not available, THE Invoice_Summary_Section SHALL display whitespace (empty string) for missing fields



### Requirement 3: Invoice and Additional Documents Table

**User Story:** As an ASM, I want to see invoice and additional documents in a structured table format, so that I can quickly review document validation status and download documents.

#### Acceptance Criteria

1. THE ASM_Review_Page SHALL display an Invoice and Additional Documents table
2. THE Invoice_Documents_Table SHALL have columns: S.No, Category of document, Document name, Status, Remarks
3. THE Invoice_Documents_Table SHALL display rows for Invoice, PO, and Cost Summary documents
4. THE Invoice_Documents_Table SHALL display validation status as "ok" or "failed" in the Status column
5. THE Invoice_Documents_Table SHALL display AI validation remarks in the Remarks column (e.g., "photos was clear (50-100)")
6. THE Document name in the Invoice_Documents_Table SHALL be displayed as a clickable link
7. WHEN a document name link is clicked, THE ASM_Review_Page SHALL download the document to the user's device
8. THE Document name link SHALL be styled with blue color and underline to indicate it is clickable
9. THE Invoice_Documents_Table SHALL use alternating row colors for readability

### Requirement 4: Campaign Details Table

**User Story:** As an ASM, I want to see campaign photos organized by dealer in a table format, so that I can efficiently review event documentation and download photos.

#### Acceptance Criteria

1. THE ASM_Review_Page SHALL display a Campaign Details table below the Invoice Documents table
2. THE Campaign_Details_Table SHALL have columns: S.No, Dealer Name, Campaign date, Document name, Status, Remarks
3. THE Campaign_Details_Table SHALL group photos by dealer (D1, D2, etc.)
4. THE Campaign_Details_Table SHALL display multiple photo rows per dealer (Pic1, Pic2, etc.)
5. THE Campaign_Details_Table SHALL display validation status as "ok" or "failed" for each photo
6. THE Campaign_Details_Table SHALL display AI validation remarks for each photo (e.g., "photo was not clear")
7. THE Document name in the Campaign_Details_Table SHALL be displayed as a clickable link
8. WHEN a document name link is clicked, THE ASM_Review_Page SHALL download the photo to the user's device
9. THE Document name link SHALL be styled with blue color and underline to indicate it is clickable
10. THE Campaign_Details_Table SHALL use alternating row colors for readability
11. THE Campaign_Details_Table SHALL visually group rows belonging to the same dealer

### Requirement 5: Responsive Layout

**User Story:** As an ASM, I want the review page to work well on different screen sizes, so that I can review submissions on various devices.

#### Acceptance Criteria

1. THE ASM_Review_Page SHALL be responsive and adapt to mobile, tablet, and desktop screen sizes
2. WHILE on mobile screens (width < 600px), THE ASM_Review_Page SHALL stack tables vertically with horizontal scroll for table content
3. WHILE on tablet screens (600px - 900px), THE ASM_Review_Page SHALL display tables with appropriate column widths
4. WHILE on desktop screens (width > 900px), THE ASM_Review_Page SHALL display the full table layout without horizontal scrolling
5. THE Action_Buttons SHALL remain accessible in the header on all screen sizes

### Requirement 6: Maintain Existing Workflow Functionality

**User Story:** As an ASM, I want all existing approval/rejection workflows to continue working, so that my review process is not disrupted.

#### Acceptance Criteria

1. THE ASM_Review_Page SHALL maintain the existing ASM approval API integration
2. THE ASM_Review_Page SHALL maintain the existing ASM rejection API integration
3. THE ASM_Review_Page SHALL maintain the existing HQ rejection resubmission workflow
4. WHEN a submission is in RejectedByHQ state, THE ASM_Review_Page SHALL display the HQ rejection section with resubmit option
5. THE ASM_Review_Page SHALL display success/error notifications for all workflow actions
6. THE ASM_Review_Page SHALL navigate back to the review list after successful approval or rejection

### Requirement 7: Remove Current Document Card Layout

**User Story:** As a developer, I want to replace the current document card sections with the new table layout, so that the UI matches the Excel-based design.

#### Acceptance Criteria

1. THE ASM_Review_Page SHALL NOT display the current document card sections (PO, Invoice, Cost Summary, Event Photos cards)
2. THE ASM_Review_Page SHALL NOT display the current AI Quick Summary section
3. THE ASM_Review_Page SHALL NOT display the current side panel for review decisions
4. THE ASM_Review_Page SHALL NOT display the current Field-Value tables within document cards
5. THE ASM_Review_Page SHALL NOT display the current AI Analysis tables within document cards

### Requirement 8: No Dummy or Placeholder Data

**User Story:** As a developer, I want to ensure all data displayed comes from the API response, so that users see accurate, real-time information without any hardcoded values.

#### Acceptance Criteria

1. THE ASM_Review_Page SHALL NOT contain any hardcoded dummy data in the implementation
2. THE ASM_Review_Page SHALL NOT contain any placeholder data that is not derived from the API response
3. THE ASM_Review_Page SHALL fetch fresh data from the API on every page load (no client-side caching)
4. THE ASM_Review_Page SHALL NOT cache API responses in browser storage
5. ALL document names SHALL be extracted from the API response (filename field)
6. ALL dealer names SHALL be extracted from photo metadata or extractedData fields from the API response
7. IF dealer name is not available in the API response, THE ASM_Review_Page SHALL display whitespace (empty string)
8. ALL dates SHALL be extracted from the API response (createdAt, updatedAt, or document-specific date fields)
9. ALL campaign dates SHALL be formatted as DD MMM YYYY (e.g., "01 Jan 1999") to match the header date format
10. ALL validation statuses SHALL be extracted from the API response (validationResult.allValidationsPassed and validationResult.failureReason fields)
11. IF validation status is not available in the API response, THE ASM_Review_Page SHALL display whitespace (empty cell with no icon or text)
12. ALL validation remarks SHALL be extracted from the API response (validationResult.failureReason field, parsed for document-specific errors)
13. IF validation remarks are not available in the API response, THE ASM_Review_Page SHALL display whitespace (empty string)
14. ALL invoice amounts SHALL be extracted from the invoice document's extractedData field
15. IF invoice amount is not available, THE ASM_Review_Page SHALL display whitespace (empty string)
16. ALL agency names SHALL be extracted from the submission's agencyName field (populated from SubmittedBy.FullName in the backend)
17. IF agency name is not available, THE ASM_Review_Page SHALL display whitespace (empty string)
18. ALL submission dates SHALL be extracted from the API response and formatted as DD MMM YYYY
19. IF submission date is not available, THE ASM_Review_Page SHALL display whitespace (empty string)
20. THE data transformation logic SHALL NOT generate fake or placeholder values (no "D1"/"D2" defaults, no "N/A" text, no "Document processed" text)
21. ALL displayed data MUST be traceable back to the API response structure
22. Fallback values for ALL fields SHALL be whitespace (empty strings), not descriptive placeholder text or generated values
23. THE ASM_Review_Page SHALL display the most recent data from the API without browser caching interference
24. THE backend API SHALL include the SubmittedBy user information (FullName as agencyName) in the submission response
25. THE backend API SHALL eager-load the SubmittedBy navigation property to populate agency information

**Note**: This requirement ensures data integrity and prevents confusion between test data and production data. Whitespace is preferred over "N/A" or placeholder text to clearly indicate missing data. The backend API has been updated to include agency information in the response.

### Requirement 9: Document Download Functionality

**User Story:** As an ASM, I want to download documents and photos by clicking on their names, so that I can review them offline or save them for records.

#### Acceptance Criteria

1. THE ASM_Review_Page SHALL make document names clickable links in both Invoice Documents and Campaign Details tables
2. WHEN a document name link is clicked, THE ASM_Review_Page SHALL trigger a download of the document to the user's device
3. THE download SHALL use the document's blobUrl from the API response
4. IF blobUrl is not available or empty, THE ASM_Review_Page SHALL display an error message "Document URL not available"
5. THE download SHALL use the actual filename from the API response
6. THE download SHALL open in a new browser tab with target="_blank" attribute
7. THE ASM_Review_Page SHALL display a success message "Downloading [filename]..." when download is triggered
8. IF download fails, THE ASM_Review_Page SHALL display an error message "Failed to download document: [error]"
9. THE document download SHALL work for all document types (Invoice, PO, Cost Summary, Photos)
10. THE download functionality SHALL be tested with actual API data to ensure blobUrl is correctly extracted and used

**Note**: This requirement ensures users can access and download all documents for offline review.
