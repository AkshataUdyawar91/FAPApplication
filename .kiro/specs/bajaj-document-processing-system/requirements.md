# Requirements Document

## Introduction

This document specifies the requirements for the Bajaj Document Processing System, a multi-agent application that automates the processing, validation, and approval workflow for purchase orders, invoices, cost summaries, and supporting documentation. The system serves three user roles (Agency, ASM, HQ) and provides intelligent document classification, cross-validation, confidence scoring, recommendation generation, email communication, analytics, notifications, and conversational AI assistance.

## Glossary

- **System**: The Bajaj Document Processing System
- **DocumentAgent**: AI service that classifies documents and extracts structured fields
- **ValidationAgent**: Service that performs cross-document validation and completeness checks
- **ConfidenceScoreService**: Service that calculates weighted confidence scores across document types
- **RecommendationAgent**: Service that generates approval recommendations with evidence
- **EmailAgent**: Service that generates and sends scenario-based emails
- **AnalyticsAgent**: Service that generates KPIs, dashboards, and AI narratives
- **NotificationAgent**: Service that manages in-app and email notifications
- **ChatService**: Conversational AI assistant for analytics queries
- **Agency**: User role representing the submitting organization
- **ASM**: Area Sales Manager user role responsible for approvals
- **HQ**: Headquarters user role with analytics access
- **PO**: Purchase Order document
- **SAP**: Enterprise resource planning system for PO verification
- **ACS**: Azure Communication Services for email delivery
- **Document_Package**: Collection of PO, Invoice, Cost Summary, Activity records, Photos, and Additional_Documents
- **Additional_Documents**: Supporting documents uploaded by Agency users (contracts, agreements, etc.)
- **Confidence_Score**: Weighted numerical score (0-100) indicating document package quality
- **Recommendation**: System output of APPROVE, REVIEW, or REJECT with evidence
- **Vector_Database**: Database storing embeddings for semantic search in ChatService

## Requirements

### Requirement 1: Document Upload

**User Story:** As an Agency user, I want to upload different types of documents for my submission, so that the system can process my complete document package.

#### Acceptance Criteria

1. WHEN an Agency user accesses the submission form, THE System SHALL provide separate upload controls for PO, Invoice, Cost_Summary, Photos, and Additional_Documents
2. WHEN a user uploads a PO document, THE System SHALL accept PDF, JPG, PNG, and TIFF formats up to 10MB
3. WHEN a user uploads an Invoice document, THE System SHALL accept PDF, JPG, PNG, and TIFF formats up to 10MB
4. WHEN a user uploads a Cost_Summary document, THE System SHALL accept PDF, XLS, XLSX, and CSV formats up to 10MB
5. WHEN a user uploads Photos, THE System SHALL accept JPG, PNG, and HEIC formats up to 5MB per photo
6. WHEN a user uploads Additional_Documents, THE System SHALL accept PDF, DOC, DOCX, XLS, and XLSX formats up to 10MB per file
7. WHEN a file upload exceeds size limits, THE System SHALL reject the upload and display an error message
8. WHEN a file upload completes, THE System SHALL display a confirmation with the filename and file size
9. WHEN a user uploads multiple photos, THE System SHALL allow up to 50 photos per campaign
10. WHEN all required documents are uploaded, THE System SHALL enable the submit button

### Requirement 2: Document Classification and Extraction

**User Story:** As an Agency user, I want the system to automatically classify and extract data from my uploaded documents, so that I don't have to manually enter structured information.

#### Acceptance Criteria

1. WHEN a document is uploaded, THE DocumentAgent SHALL classify it as one of: PO, Invoice, Cost_Summary, Photo, or Additional_Document
2. WHEN a PO document is classified, THE DocumentAgent SHALL extract all required PO fields into structured data
3. WHEN an Invoice document is classified, THE DocumentAgent SHALL extract all required Invoice fields into structured data
4. WHEN a Cost_Summary document is classified, THE DocumentAgent SHALL extract all required Cost_Summary fields into structured data
5. WHEN a Photo is classified, THE DocumentAgent SHALL extract metadata including timestamp and location if available
6. IF a document cannot be classified with sufficient confidence, THEN THE DocumentAgent SHALL flag it for manual review
7. WHEN field extraction completes, THE System SHALL persist the extracted data to the SQL database

### Requirement 3: Cross-Document Validation

**User Story:** As an ASM, I want the system to validate that submitted documents are consistent with each other and with SAP records, so that I can trust the data accuracy before approval.

#### Acceptance Criteria

1. WHEN a Document_Package is submitted, THE ValidationAgent SHALL verify that PO data matches the corresponding SAP PO record
2. WHEN validating a Document_Package, THE ValidationAgent SHALL check that Invoice amounts match Cost_Summary totals within acceptable tolerance
3. WHEN validating a Document_Package, THE ValidationAgent SHALL verify that all PO line items appear in the Invoice
4. WHEN performing completeness validation, THE ValidationAgent SHALL verify all 11 required items are present in the Document_Package
5. WHEN validation identifies discrepancies, THE ValidationAgent SHALL record specific validation failures with field-level details
6. WHEN all validations pass, THE ValidationAgent SHALL mark the Document_Package as validation_complete
7. IF SAP connection fails, THEN THE ValidationAgent SHALL log the error and mark SAP validation as pending

### Requirement 4: Confidence Score Calculation

**User Story:** As an ASM, I want to see a confidence score for each submission, so that I can prioritize my review efforts on lower-confidence packages.

#### Acceptance Criteria

1. WHEN a Document_Package completes extraction, THE ConfidenceScoreService SHALL calculate a weighted confidence score
2. THE ConfidenceScoreService SHALL apply weight 0.30 to PO confidence
3. THE ConfidenceScoreService SHALL apply weight 0.30 to Invoice confidence
4. THE ConfidenceScoreService SHALL apply weight 0.20 to Cost_Summary confidence
5. THE ConfidenceScoreService SHALL apply weight 0.10 to Activity confidence
6. THE ConfidenceScoreService SHALL apply weight 0.10 to Photos confidence
7. WHEN the weighted score is calculated, THE ConfidenceScoreService SHALL return a value between 0 and 100
8. WHEN the confidence score is below 70, THE System SHALL flag the Document_Package for mandatory review

### Requirement 5: Approval Recommendations

**User Story:** As an ASM, I want the system to provide a recommendation with clear evidence, so that I can make informed approval decisions quickly.

#### Acceptance Criteria

1. WHEN a Document_Package completes validation and scoring, THE RecommendationAgent SHALL generate one of: APPROVE, REVIEW, or REJECT
2. WHEN generating a recommendation, THE RecommendationAgent SHALL provide a plain-English evidence summary
3. WHEN the Confidence_Score is above 85 and validation passes, THE RecommendationAgent SHALL recommend APPROVE
4. WHEN the Confidence_Score is between 70 and 85, THE RecommendationAgent SHALL recommend REVIEW
5. WHEN the Confidence_Score is below 70 or validation fails, THE RecommendationAgent SHALL recommend REJECT
6. WHEN generating evidence, THE RecommendationAgent SHALL cite specific validation results and confidence factors
7. WHEN a recommendation is generated, THE System SHALL persist it with the Document_Package

### Requirement 6: Email Communication

**User Story:** As an Agency user, I want to receive clear email notifications about my submission status, so that I know what actions I need to take.

#### Acceptance Criteria

1. WHEN a Document_Package fails validation, THE EmailAgent SHALL generate a data failure email requesting re-upload
2. WHEN a data failure email is generated, THE EmailAgent SHALL include specific fields that need correction
3. WHEN a Document_Package passes validation, THE EmailAgent SHALL generate a data pass email for ASM approval
4. WHEN generating emails, THE EmailAgent SHALL use scenario-based templates appropriate to the failure type
5. WHEN an email is generated, THE EmailAgent SHALL send it via ACS to the appropriate recipient
6. WHEN email delivery fails, THE EmailAgent SHALL retry up to 3 times with exponential backoff
7. WHEN email delivery succeeds, THE System SHALL log the delivery confirmation

### Requirement 7: Analytics and Reporting

**User Story:** As an HQ user, I want to view KPI dashboards and export analytics data, so that I can monitor system performance and ROI across campaigns and states.

#### Acceptance Criteria

1. WHEN an HQ user accesses the analytics dashboard, THE AnalyticsAgent SHALL display current KPI metrics
2. THE AnalyticsAgent SHALL calculate and display state-level ROI metrics
3. THE AnalyticsAgent SHALL provide campaign breakdown analytics with submission counts and approval rates
4. WHEN an HQ user requests data export, THE AnalyticsAgent SHALL generate an Excel file with all analytics data
5. WHEN displaying analytics, THE AnalyticsAgent SHALL generate an AI narrative summarizing key insights
6. WHEN calculating KPIs, THE AnalyticsAgent SHALL use real-time data from the SQL database
7. WHEN the dashboard loads, THE System SHALL render all visualizations within 3 seconds

### Requirement 8: Notification Management

**User Story:** As a system user, I want to receive timely notifications about important events, so that I can respond promptly to submissions, flags, and approvals.

#### Acceptance Criteria

1. WHEN a Document_Package is submitted, THE NotificationAgent SHALL create an in-app notification for the ASM
2. WHEN a Document_Package is submitted, THE NotificationAgent SHALL send an ACS email notification to the ASM
3. WHEN a Document_Package is flagged for review, THE NotificationAgent SHALL notify the ASM via in-app and email
4. WHEN an ASM approves a Document_Package, THE NotificationAgent SHALL notify the Agency via in-app and email
5. WHEN an ASM requests re-upload, THE NotificationAgent SHALL notify the Agency with specific requirements
6. WHEN a user accesses the in-app inbox, THE System SHALL display all unread notifications first
7. WHEN a notification is read, THE System SHALL mark it as read and update the unread count

### Requirement 9: Conversational Analytics Assistant

**User Story:** As an HQ user, I want to ask natural language questions about analytics data, so that I can get insights without navigating complex dashboards.

#### Acceptance Criteria

1. WHEN an HQ user sends a chat message, THE ChatService SHALL process it using Semantic Kernel
2. WHEN processing a query, THE ChatService SHALL search the Vector_Database for relevant analytics data
3. WHEN generating a response, THE ChatService SHALL apply guardrails to prevent unauthorized data access
4. WHEN a query requests data outside the user's permissions, THE ChatService SHALL deny the request with an explanation
5. WHEN generating responses, THE ChatService SHALL cite specific data sources and time ranges
6. WHEN the Vector_Database is updated with new analytics, THE ChatService SHALL use the latest embeddings
7. WHEN a chat session exceeds 10 messages, THE System SHALL maintain conversation context across all messages

### Requirement 10: User Authentication and Authorization

**User Story:** As a system administrator, I want role-based access control, so that users can only access features appropriate to their role.

#### Acceptance Criteria

1. WHEN a user logs in, THE System SHALL authenticate credentials against the user database
2. WHEN authentication succeeds, THE System SHALL assign the user's role (Agency, ASM, or HQ)
3. WHERE the user role is Agency, THE System SHALL grant access to document submission and status viewing
4. WHERE the user role is ASM, THE System SHALL grant access to approval workflows and validation details
5. WHERE the user role is HQ, THE System SHALL grant access to analytics dashboards and ChatService
6. WHEN a user attempts to access unauthorized features, THE System SHALL deny access and log the attempt
7. WHEN a session expires after 30 minutes of inactivity, THE System SHALL require re-authentication

### Requirement 11: User Interface and Branding

**User Story:** As a user, I want a consistent, branded interface that follows Bajaj guidelines, so that the application feels professional and trustworthy.

#### Acceptance Criteria

1. THE System SHALL use Bajaj brand colors: White, Light Blue, and Dark Blue throughout the UI
2. WHEN rendering any screen, THE System SHALL follow Bajaj branding guidelines for typography and spacing
3. WHEN displaying the application logo, THE System SHALL use the official Bajaj logo
4. WHEN a user interacts with UI elements, THE System SHALL provide visual feedback within 100ms
5. WHEN the application loads on mobile devices, THE System SHALL render a responsive layout optimized for the screen size
6. WHEN displaying forms, THE System SHALL use consistent input styling across all screens
7. WHEN errors occur, THE System SHALL display user-friendly error messages in Bajaj brand styling
8. WHEN designing any screen, THE System SHALL optimize layout to minimize vertical scrolling and fit primary content within the viewport
9. WHEN displaying data tables or lists, THE System SHALL use pagination or compact layouts to reduce scroll requirements
10. WHEN showing multi-step forms, THE System SHALL display one step at a time to keep content within viewport bounds

### Requirement 12: Data Persistence and Integrity

**User Story:** As a system administrator, I want all data to be reliably stored and retrievable, so that no information is lost and audit trails are maintained.

#### Acceptance Criteria

1. WHEN any entity is created or modified, THE System SHALL persist changes to the SQL database immediately
2. WHEN database operations fail, THE System SHALL retry up to 3 times before reporting an error
3. WHEN storing Document_Package data, THE System SHALL maintain referential integrity between related entities
4. WHEN a user deletes a document, THE System SHALL perform a soft delete preserving audit history
5. WHEN database transactions are executed, THE System SHALL use ACID-compliant transactions
6. WHEN storing extracted document data, THE System SHALL include timestamps and user attribution
7. WHEN backing up data, THE System SHALL create daily backups retained for 30 days

### Requirement 13: API Design and Integration

**User Story:** As a developer, I want a well-designed .NET API, so that the Flutter frontend can reliably communicate with backend services.

#### Acceptance Criteria

1. THE System SHALL expose RESTful API endpoints for all frontend operations
2. WHEN API requests are received, THE System SHALL validate request payloads against defined schemas
3. WHEN API operations fail, THE System SHALL return appropriate HTTP status codes and error messages
4. WHEN API endpoints are called, THE System SHALL require valid authentication tokens
5. WHEN the API processes requests, THE System SHALL log all requests and responses for debugging
6. WHEN API responses are generated, THE System SHALL include correlation IDs for request tracing
7. WHEN the API handles file uploads, THE System SHALL support multipart form data up to 50MB per file

### Requirement 14: Performance and Scalability

**User Story:** As a system administrator, I want the system to handle concurrent users efficiently, so that performance remains acceptable under load.

#### Acceptance Criteria

1. WHEN 100 concurrent users access the system, THE System SHALL maintain response times under 2 seconds for all operations
2. WHEN processing document extraction, THE DocumentAgent SHALL complete processing within 30 seconds per document
3. WHEN calculating confidence scores, THE ConfidenceScoreService SHALL complete within 5 seconds
4. WHEN generating recommendations, THE RecommendationAgent SHALL complete within 10 seconds
5. WHEN the database contains 1 million Document_Packages, THE System SHALL maintain query performance under 1 second
6. WHEN the Vector_Database is queried, THE ChatService SHALL return results within 3 seconds
7. WHEN multiple agents process requests concurrently, THE System SHALL queue requests to prevent resource exhaustion

### Requirement 15: Error Handling and Resilience

**User Story:** As a user, I want the system to handle errors gracefully, so that temporary failures don't result in data loss or poor user experience.

#### Acceptance Criteria

1. WHEN any service encounters an error, THE System SHALL log the error with full context and stack trace
2. WHEN external service calls fail, THE System SHALL implement retry logic with exponential backoff
3. WHEN the SAP connection is unavailable, THE System SHALL queue validation requests for later processing
4. WHEN ACS email delivery fails, THE System SHALL store the email for retry and notify administrators
5. WHEN the DocumentAgent fails to process a document, THE System SHALL notify the user and preserve the uploaded file
6. WHEN database connections are lost, THE System SHALL attempt reconnection before failing requests
7. WHEN critical errors occur, THE System SHALL send alerts to system administrators via configured channels

### Requirement 16: Security and Compliance

**User Story:** As a security officer, I want the system to protect sensitive data and maintain audit trails, so that we comply with data protection regulations.

#### Acceptance Criteria

1. WHEN storing sensitive data, THE System SHALL encrypt data at rest using AES-256 encryption
2. WHEN transmitting data between frontend and backend, THE System SHALL use TLS 1.3 or higher
3. WHEN users authenticate, THE System SHALL hash passwords using bcrypt with minimum 12 rounds
4. WHEN storing document files, THE System SHALL scan for malware before persisting to storage
5. WHEN audit events occur, THE System SHALL log user actions with timestamps and IP addresses
6. WHEN personal data is accessed, THE System SHALL log the access for compliance auditing
7. WHEN API keys or secrets are stored, THE System SHALL use secure key management services

### Requirement 17: Enhanced Upload Page UI and Empty State

**User Story:** As an Agency user, I want an intuitive and visually appealing upload interface with clear empty states, so that I can easily submit my documents with a clear understanding of requirements and progress.

#### Acceptance Criteria

1. WHEN an Agency user accesses the "All Requests" page with no submissions, THE System SHALL display an empty state with a document icon, "No requests found" heading, and "Create your first request to get started" subtext
2. WHEN the empty state is displayed, THE System SHALL show a centered "Create New Request" button with a plus icon, blue background (#0066FF or similar), white text, and rounded corners
3. WHEN a user clicks the centered "Create New Request" button, THE System SHALL navigate to the upload page
4. WHEN the "All Requests" page has existing submissions, THE System SHALL display the list of requests without the empty state
5. WHEN the upload page loads, THE System SHALL display a step progress indicator showing "Step X of 4" with percentage completion and a blue progress bar
6. WHEN the upload page displays step indicators, THE System SHALL show circular icons for each step (Purchase Order, Invoice, Photos & Cost Summary, Additional Documents) with blue background for current/completed steps and gray for incomplete steps
7. WHEN the upload page loads, THE System SHALL display clear document type cards with blue icon backgrounds and blue accent colors for headings
8. WHEN a user views a document upload card, THE System SHALL show the document type name in blue text, accepted file formats, and maximum file size
9. WHEN a user has not uploaded a document, THE System SHALL display a dashed border upload area with blue cloud upload icon and "Click to upload" text in blue
10. WHEN a user successfully uploads a document, THE System SHALL display a green checkmark icon and the filename in a green-tinted success card
11. WHEN a user hovers over or taps an upload card, THE System SHALL provide visual feedback (highlight, shadow, or border change)
12. WHEN all required documents are uploaded, THE System SHALL enable the "Submit for Review" button with green background color
13. WHEN the "Submit for Review" button is disabled, THE System SHALL display it in a muted gray state
14. WHEN the upload page is displayed on mobile devices, THE System SHALL stack document cards vertically with appropriate spacing
15. WHEN the upload page is displayed on desktop, THE System SHALL arrange document cards in a responsive grid layout (2-3 columns)
16. WHEN a user uploads a file that exceeds size limits or has an invalid format, THE System SHALL display an inline error message on the specific card
17. WHEN the "All Requests" page header shows "Create New Request" button in the top right, THE System SHALL either remove it or ensure it navigates to the upload page (consistent with centered button)
18. WHEN the upload page displays the header, THE System SHALL use "Create New Request" as the title in dark text with a subtitle explaining the process

### Requirement 18: Enhanced Submissions Dashboard with PO Details and AI Confidence Score

**User Story:** As an Agency user, I want to view comprehensive submission details including PO information and AI confidence scores in the dashboard, so that I can quickly assess the status and quality of my reimbursement requests without opening individual submissions.

#### Acceptance Criteria

##### AC1: Display PO Number and Amount

1. WHEN an Agency user views the submissions dashboard, THE System SHALL display PO Number and PO Amount columns for each submission
2. WHEN a submission has been processed and PO data extracted, THE System SHALL display the PO Number in the "PO NO." column
3. WHEN a submission has been processed and PO data extracted, THE System SHALL display the PO Amount in the "PO AMT" column formatted as currency with ₹ symbol
4. WHEN a submission has not yet been processed or PO data is unavailable, THE System SHALL display "-" in both PO Number and PO Amount columns
5. WHEN displaying PO amounts, THE System SHALL right-align the values for better readability



##### AC2: Display AI Confidence Score

1. WHEN an Agency user views the submissions dashboard, THE System SHALL display an AI Confidence Score column showing the overall confidence percentage
2. WHEN a submission has been processed through the AI workflow, THE System SHALL display the overall confidence score as a percentage (e.g., "85%")
3. WHEN displaying the AI confidence score, THE System SHALL center-align the value in the "AI SCORE" column
4. WHEN a submission has not yet been scored by the AI system, THE System SHALL display "-" in the AI Score column

##### AC3: Proper Column Alignment and Layout

1. WHEN the submissions table is rendered, THE System SHALL display column headers in this order: FAP NUMBER, PO NO., PO AMT, INVOICE NO., INVOICE AMT, SUBMITTED DATE, AI SCORE, STATUS, View
2. WHEN displaying table data, THE System SHALL left-align text fields (FAP NUMBER, PO NO., INVOICE NO., SUBMITTED DATE)
3. WHEN displaying table data, THE System SHALL right-align monetary amounts (PO AMT, INVOICE AMT)
4. WHEN displaying table data, THE System SHALL center-align status indicators (AI SCORE, STATUS)
5. WHEN rendering the table, THE System SHALL use consistent flex values (flex: 2) for all data columns to ensure proper alignment
6. WHEN displaying currency values, THE System SHALL format amounts with two decimal places and ₹ symbol

##### AC4: Secure Authentication

1. WHEN a user attempts to access the submissions dashboard, THE System SHALL require valid JWT authentication
2. WHEN a user provides valid credentials (email and password), THE System SHALL generate a JWT token with user claims
3. WHEN a user successfully authenticates, THE System SHALL allow access to the submissions dashboard
4. WHEN an Agency user accesses the submissions list, THE System SHALL filter results to show only submissions created by that user
5. WHEN authentication fails, THE System SHALL return an "Invalid email or password" error message
6. WHEN making API requests, THE System SHALL include the JWT token in the Authorization header

##### AC5: Backend API Response Structure

1. WHEN the GET /api/submissions endpoint is called, THE System SHALL return a paginated response with total, page, pageSize, and items fields
2. WHEN returning submission items, THE System SHALL include these fields for each submission: id, state, createdAt, updatedAt, documentCount, invoiceNumber, invoiceAmount, poNumber, poAmount, overallConfidence
3. WHEN extracting PO data, THE System SHALL parse the ExtractedDataJson field from PO documents to retrieve PONumber and TotalAmount
4. WHEN extracting invoice data, THE System SHALL parse the ExtractedDataJson field from Invoice documents to retrieve InvoiceNumber and TotalAmount
5. WHEN including confidence scores, THE System SHALL load the ConfidenceScore relationship using .Include(p => p.ConfidenceScore)
6. WHEN a field is not available, THE System SHALL return null to allow the frontend to display appropriate placeholders

#### Technical Implementation Notes

**Backend Changes:**
- SubmissionsController.cs: Added `.Include(p => p.ConfidenceScore)` to load confidence scores, added `overallConfidence` field to API response, enabled `[Authorize]` attribute for authentication
- AuthService.cs: Fixed BCrypt password hashing and verification, added detailed logging for authentication debugging, proper JWT token generation with user claims
- Database: Updated user password hashes to use proper BCrypt format (nvarchar(512))

**Frontend Changes:**
- agency_dashboard_page.dart: Added PO NO., PO AMT, and AI SCORE columns to table header, updated table row rendering to display PO data and confidence scores, fixed column alignment (all data columns use flex: 2), proper formatting for currency values with ₹ symbol

**API Endpoints:**
- POST /api/auth/login - User authentication with JWT token generation
- GET /api/submissions - List submissions with PO and confidence data (paginated)
- GET /api/submissions/{id} - Get detailed submission information

**Authentication:**
- JWT-based authentication with BCrypt password hashing (BCrypt.Net-Next 4.0.3)
- Token expiration: 30 minutes (configurable in appsettings.json)
- Role-based access control (Agency, ASM, HQ)
- Password hash format: BCrypt with work factor 12

**Test Credentials:**
- Agency User: agency@bajaj.com / Password123!
- ASM User: asm@bajaj.com / Password123!
- HQ User: hq@bajaj.com / Password123!

### Requirement 19: ASM FAP Review Page with AI Quick Summary

**User Story:** As an ASM user, I want to review each FAP in a single stacked page layout with AI quick summary and document-level confidence scores, so that I can quickly evaluate submissions without navigating tabs and make faster approval decisions.

#### Acceptance Criteria

1. WHEN an ASM user views an Agency, THE System SHALL display all FAPs submitted by that Agency in a list view
2. WHEN an ASM selects a FAP, THE System SHALL display PO, Invoice, Photos, Cost Summary, and other documents in stacked vertical sections on a single page (no tab-based navigation) with each document having view/download feature
3. WHEN rendering the FAP review page, THE System SHALL optimize layout spacing to reduce oversized sections and minimize unnecessary scrolling
4. WHEN the FAP review page loads, THE System SHALL display an AI Quick Summary section at the top of the page
5. WHEN displaying the AI Quick Summary, THE System SHALL present a crisp bullet-point text summary of overall document quality and key validation insights
6. WHEN displaying the AI Quick Summary, THE System SHALL show the overall Confidence Score prominently near the summary (e.g., "94%" with visual indicator)
7. WHEN rendering each document section (PO, Invoice, Cost Summary, Photos), THE System SHALL display the individual AI Confidence Score beside the respective document title or within its section header
8. WHEN showing document confidence percentages, THE System SHALL visually align the percentage next to the document name for clarity (e.g., "Invoice 92%", "Cost Summary 90%")
9. WHEN displaying AI validation results for each document, THE System SHALL provide a concise bullet-point explanation summarizing why the score was assigned instead of displaying raw technical validation logs
10. WHEN validation issues exist, THE System SHALL highlight key discrepancies in brief bullet points within the respective document section
11. WHEN confidence scores are high (>85%), THE System SHALL display a visual indicator (e.g., green checkmark badge)
12. WHEN confidence scores are medium (70-85%), THE System SHALL display amber indicators
13. WHEN confidence scores are low (<70%), THE System SHALL display red indicators
14. WHEN multiple documents are displayed, THE System SHALL maintain consistent section layout and alignment for all document types
15. WHEN the page is viewed on desktop, THE System SHALL utilize horizontal space efficiently to display summary text and confidence metrics side-by-side where possible
16. WHEN the page is viewed on smaller screens, THE System SHALL stack summary and confidence sections responsively without breaking readability
17. WHEN the ASM reviews a FAP, THE System SHALL display a "Review Decision" panel on the right side with "Approve FAP" (green) and "Reject FAP" (red) buttons
18. WHEN the ASM clicks "Approve FAP", THE System SHALL update the FAP state to Approved and notify the Agency user
19. WHEN the ASM clicks "Reject FAP", THE System SHALL prompt for rejection comments and update the FAP state to Rejected
20. WHEN displaying the FAP header, THE System SHALL show the campaign name, FAP ID, submission date, and total amount prominently

### Requirement 20: PO Field Display and Auto-Population on Agency Submission Form

**User Story:** As an Agency user, I want to see extracted PO data displayed in dedicated input fields on the submission form after uploading my PO document, so that I can verify the extracted information is correct and make manual corrections if needed before submitting.

#### Acceptance Criteria

1. WHEN an Agency user accesses the submission form, THE System SHALL display four PO data input fields: PO Number, PO Amount (₹), PO Date, and Vendor Name
2. WHEN the submission form initially loads with no PO document uploaded, THE System SHALL display empty input fields with placeholder text: "Enter PO number", "Enter amount", "dd-mm-yyyy", "Enter vendor name"
3. WHEN an Agency user uploads a PO document, THE System SHALL automatically populate the four PO fields with extracted data from the DocumentAgent
4. WHEN displaying the PO Amount field, THE System SHALL format the value as currency with the ₹ symbol (e.g., "₹ 10,500.00")
5. WHEN displaying the PO Date field, THE System SHALL format the date in dd-mm-yyyy format (e.g., "15-03-2024")
6. WHEN the PO fields are auto-populated with extracted data, THE System SHALL allow the user to manually edit any field value
7. WHEN a user manually edits an auto-populated field, THE System SHALL preserve the edited value and not overwrite it if the PO document is re-uploaded
8. WHEN the extracted PO data is incomplete or unavailable, THE System SHALL leave the corresponding fields empty with placeholder text
9. WHEN displaying the PO fields, THE System SHALL arrange them in a 2x2 grid layout: PO Number (top-left), PO Amount (top-right), PO Date (bottom-left), Vendor Name (bottom-right)
10. WHEN the submission form is viewed on mobile devices, THE System SHALL stack the PO fields vertically in a single column
11. WHEN the user submits the form, THE System SHALL include the PO field values (whether auto-populated or manually entered) in the submission data

### Requirement 21: Invoice Field Display and Auto-Population on Agency Submission Form

**User Story:** As an Agency user, I want to see extracted Invoice data displayed in dedicated input fields on the submission form after uploading my Invoice document, so that I can verify the extracted information is correct and make manual corrections if needed before submitting.

#### Acceptance Criteria

1. WHEN an Agency user accesses the submission form, THE System SHALL display five Invoice data input fields: Invoice No, Invoice Date, Invoice Amount (₹), GSTIN, and Vendor Name
2. WHEN the submission form initially loads with no Invoice document uploaded, THE System SHALL display empty input fields with placeholder text: "Enter invoice number", "dd-mm-yyyy", "Enter amount", "Enter GSTIN", "Enter vendor name"
3. WHEN an Agency user uploads an Invoice document, THE System SHALL automatically populate the five Invoice fields with extracted data from the DocumentAgent
4. WHEN displaying the Invoice Amount field, THE System SHALL format the value as currency with the ₹ symbol (e.g., "₹ 10,500.00")
5. WHEN displaying the Invoice Date field, THE System SHALL format the date in dd-mm-yyyy format (e.g., "15-03-2024")
6. WHEN the Invoice fields are auto-populated with extracted data, THE System SHALL allow the user to manually edit any field value
7. WHEN a user manually edits an auto-populated field, THE System SHALL preserve the edited value and not overwrite it if the Invoice document is re-uploaded
8. WHEN the extracted Invoice data is incomplete or unavailable, THE System SHALL leave the corresponding fields empty with placeholder text
9. WHEN displaying the Invoice fields, THE System SHALL arrange them in a 2-column grid layout: Invoice No (row 1 left), Invoice Date (row 1 right), Invoice Amount (row 2 left), GSTIN (row 2 right), Vendor Name (row 3 full width)
10. WHEN the submission form is viewed on mobile devices, THE System SHALL stack the Invoice fields vertically in a single column
11. WHEN both PO and Invoice documents are uploaded, THE System SHALL display a "Cross-Validation with PO Document" section showing two read-only fields: "PO Number (from Invoice)" and "PO Number (from PO Document)"
12. WHEN displaying the cross-validation section, THE System SHALL auto-populate "PO Number (from Invoice)" with the PO reference extracted from the Invoice document
13. WHEN displaying the cross-validation section, THE System SHALL auto-populate "PO Number (from PO Document)" with the PO Number from the PO fields section
14. WHEN the two PO numbers in the cross-validation section match, THE System SHALL display a green checkmark indicator
15. WHEN the two PO numbers in the cross-validation section do not match, THE System SHALL display a red warning indicator and message: "PO numbers do not match. Please verify."
16. WHEN the user submits the form, THE System SHALL include the Invoice field values (whether auto-populated or manually entered) in the submission data


### Requirement 22: Hierarchical Document Structure (FAP → PO → Campaigns → Documents)

**User Story:** As an Agency user, I want to submit a FAP with one PO that can have multiple Campaigns, where each Campaign has multiple Invoices, multiple Photos, one Cost Summary, and one Activity Summary, so that I can accurately represent complex field activities organized by campaign/team.

#### Correct Hierarchy

```
DocumentPackage (FAP)
├── 1 PO Document (required)
├── Multiple Campaigns (at least 1 required)
│   └── Campaign 1
│       ├── Activity Duration (Start Date, End Date, Working Days)
│       ├── Multiple Invoices (at least 1 required per campaign)
│       ├── Multiple Photos (at least 1 required per campaign)
│       ├── 1 Cost Summary (required per campaign)
│       └── 1 Activity Summary (required per campaign)
│   └── Campaign 2
│       └── ... (same structure)
└── Additional Documents (at PO level)
    ├── 1 Enquiry Document (optional)
    └── Multiple Additional Documents (optional)
```

#### Acceptance Criteria

##### AC1: FAP to PO Relationship (1:1)

1. WHEN an Agency user creates a new FAP submission, THE System SHALL require exactly one PO document to be uploaded
2. WHEN a PO document is uploaded, THE System SHALL extract and store PO data (PO Number, Amount, Date, Vendor) linked to the FAP
3. WHEN displaying a FAP, THE System SHALL show the single PO document with its extracted data

##### AC2: PO to Campaign Relationship (1:Many)

1. WHEN an Agency user has uploaded a PO document, THE System SHALL allow adding multiple Campaigns linked to that PO
2. WHEN adding a campaign, THE System SHALL capture: Activity Duration (Start Date, End Date), Working Days (auto-calculated)
3. WHEN displaying campaigns, THE System SHALL show all campaigns associated with the PO in a list format
4. WHEN adding a new campaign, THE System SHALL provide an "Add Campaign" button
5. WHEN a campaign is created, THE System SHALL allow uploading documents specific to that campaign

##### AC3: Campaign to Invoice Relationship (1:Many)

1. WHEN an Agency user has added a Campaign, THE System SHALL allow uploading multiple Invoice documents linked to that campaign
2. WHEN an Invoice document is uploaded, THE System SHALL extract and store Invoice data (Invoice Number, Date, Amount, GST Number)
3. WHEN displaying invoices, THE System SHALL show all invoices associated with each campaign
4. WHEN adding a new invoice, THE System SHALL provide an "Add Invoice" button within each campaign section
5. WHEN an invoice is uploaded, THE System SHALL link it to the specific Campaign

##### AC4: Campaign to Photo Relationship (1:Many)

1. WHEN an Agency user has added a Campaign, THE System SHALL allow uploading multiple photos linked to that campaign
2. WHEN photos are uploaded, THE System SHALL extract EXIF metadata (timestamp, GPS coordinates, device model)
3. WHEN displaying photos, THE System SHALL show all photos associated with each campaign in a gallery format
4. WHEN adding photos, THE System SHALL allow up to 50 photos per campaign
5. WHEN displaying photo metadata, THE System SHALL show timestamp, location (if available), and device info

##### AC5: Campaign to Cost Summary Relationship (1:1)

1. WHEN an Agency user has added a Campaign, THE System SHALL allow uploading exactly one Cost Summary document for that campaign
2. WHEN a Cost Summary is uploaded, THE System SHALL link it to the specific Campaign
3. WHEN displaying the campaign, THE System SHALL show the Cost Summary document with its extracted data
4. WHEN a user attempts to upload a second Cost Summary for the same campaign, THE System SHALL replace the existing one

##### AC6: Campaign to Activity Summary Relationship (1:1)

1. WHEN an Agency user has added a Campaign, THE System SHALL allow uploading exactly one Activity Summary document for that campaign
2. WHEN an Activity Summary is uploaded, THE System SHALL link it to the specific Campaign
3. WHEN displaying the campaign, THE System SHALL show the Activity Summary document with its extracted data
4. WHEN a user attempts to upload a second Activity Summary for the same campaign, THE System SHALL replace the existing one

##### AC7: Additional Documents at PO Level

1. WHEN an Agency user has uploaded a PO, THE System SHALL allow uploading one Enquiry Document at the PO level
2. WHEN an Enquiry Document is uploaded, THE System SHALL link it to the PO/FAP (not to a specific campaign)
3. WHEN a user attempts to upload a second Enquiry Document, THE System SHALL replace the existing one
4. WHEN an Agency user needs additional supporting documents, THE System SHALL allow uploading multiple Additional Documents at the PO level
5. WHEN displaying Additional Documents, THE System SHALL show them in the Additional Documents section separate from campaign documents

##### AC8: Data Integrity and Navigation

1. WHEN deleting a Campaign, THE System SHALL cascade delete all associated Invoices, Photos, Cost Summary, and Activity Summary
2. WHEN viewing a FAP, THE System SHALL display the hierarchical structure: PO → Campaigns → (Invoices, Photos, Cost Summary, Activity Summary)
3. WHEN navigating the hierarchy, THE System SHALL allow expanding/collapsing each campaign for better readability
4. WHEN calculating confidence scores, THE System SHALL aggregate scores from all campaigns and their documents in the FAP

##### AC9: Validation Across Hierarchy

1. WHEN validating a FAP, THE System SHALL verify that the sum of all Invoice amounts (across all campaigns) matches the PO amount (within tolerance)
2. WHEN validating campaigns, THE System SHALL verify that campaign dates fall within the PO date range
3. WHEN validating photos, THE System SHALL verify that photo timestamps fall within the campaign date range
4. WHEN validation issues are found, THE System SHALL display them at the appropriate hierarchy level (Campaign, Invoice, or Photo)



### Requirement 23: Multi-Step Document Upload Process

**User Story:** As a user, I want to upload the Purchase Order and related campaign documents in a structured multi-step process, so that all campaign-related documents can be organized and submitted in one place.

#### Description

The document upload process will be divided into three steps:
1. **Step 1: Purchase Order** - Upload the PO document
2. **Step 2: Campaigns** - Add campaigns, and for each campaign add invoices, photos, cost summary, and activity summary
3. **Step 3: Additional Documents** - Upload enquiry document and other supporting documents

#### Step 1: Purchase Order

- The user should be able to upload the Purchase Order (PO) document
- PO document is required before proceeding to the next step
- After uploading the PO, the user can click "Next" to proceed to Step 2
- Validation: PO document must be uploaded before the Next button is enabled

#### Step 2: Campaigns

Within this step, the user can add multiple Campaigns. For each Campaign:

- **Activity Duration** - Start Date, End Date, Working Days (auto-calculated)
- **Multiple Invoices** - Upload invoice PDFs with fields (Invoice No, Invoice Date, Amount, GST Number)
- **Multiple Photos** - Campaign activity photos (at least 1 required)
- **One Cost Summary document** - Single cost summary document per campaign (required)
- **One Activity Summary document** - Single activity summary document per campaign (required)

After completing all campaigns, the user can click "Next" to move to Step 3.

#### Step 3: Additional Documents

The user should be able to upload additional supporting documents at the PO level:

- **One Enquiry Document** - Single enquiry document (optional)
- **Multiple Additional Documents** - Ability to upload multiple additional supporting documents if required (optional)

#### Acceptance Criteria

##### AC1: Step 1 - Purchase Order

1. WHEN an Agency user accesses the upload page, THE System SHALL display Step 1 (Purchase Order) as the first step
2. WHEN the user is on Step 1, THE System SHALL display a PO document upload control
3. WHEN the user has not uploaded a PO document, THE System SHALL disable the "Next" button
4. WHEN the user uploads a valid PO document, THE System SHALL enable the "Next" button
5. WHEN the user clicks "Next" after uploading PO, THE System SHALL navigate to Step 2 (Campaigns)
6. WHEN the user attempts to proceed without uploading PO, THE System SHALL display a validation error on the current page

##### AC2: Step 2 - Campaigns

1. WHEN the user navigates to Step 2, THE System SHALL display the Campaigns section
2. WHEN the user clicks "Add Campaign", THE System SHALL create a new campaign section with Activity Duration fields and document upload controls
3. WHEN the user adds a campaign, THE System SHALL display Activity Duration fields (Start Date, End Date, Working Days auto-calculated)
4. WHEN the user is on Step 2, THE System SHALL allow adding multiple invoices within each campaign via "Add Invoice" button
5. WHEN the user uploads an invoice document, THE System SHALL extract and populate the invoice fields (Invoice No, Date, Amount, GST)
6. WHEN the user is on Step 2, THE System SHALL allow uploading multiple photos per campaign
7. WHEN the user is on Step 2, THE System SHALL allow uploading exactly one cost summary document per campaign
8. WHEN the user is on Step 2, THE System SHALL allow uploading exactly one activity summary document per campaign
9. WHEN the user attempts to upload more than one cost summary for a campaign, THE System SHALL replace the existing cost summary
10. WHEN the user attempts to upload more than one activity summary for a campaign, THE System SHALL replace the existing activity summary
11. WHEN the user clicks "Next" on Step 2, THE System SHALL validate that:
    - At least 1 campaign exists
    - Each campaign has at least 1 invoice
    - Each campaign has at least 1 photo, 1 cost summary, and 1 activity summary
12. WHEN required documents are missing, THE System SHALL display validation errors on the current page and prevent navigation

##### AC3: Step 3 - Additional Documents

1. WHEN the user navigates to Step 3, THE System SHALL display the Additional Documents section
2. WHEN the user is on Step 3, THE System SHALL allow uploading exactly one enquiry document
3. WHEN the user is on Step 3, THE System SHALL allow uploading multiple additional supporting documents
4. WHEN the user attempts to upload more than one enquiry document, THE System SHALL replace the existing enquiry document
5. WHEN the user completes Step 3, THE System SHALL enable the "Submit" button
6. WHEN no documents are uploaded in Step 3, THE System SHALL still allow submission (all documents in Step 3 are optional)

##### AC4: Validation Rules

1. WHEN a required document is not uploaded, THE System SHALL display a validation error on the current step page
2. WHEN the user clicks "Next" without required documents, THE System SHALL prevent navigation and show validation errors
3. WHEN the user submits the package, THE System SHALL perform field-level validation in the backend
4. WHEN the user submits the package, THE System SHALL perform cross-document validation in the backend
5. WHEN backend validation fails, THE System SHALL return detailed validation errors to the frontend
6. WHEN frontend validation passes but backend validation fails, THE System SHALL display backend validation errors to the user

##### AC5: Navigation and Progress

1. WHEN the user is on any step, THE System SHALL display a step progress indicator showing current step (e.g., "Step 2 of 3") with percentage
2. WHEN the user completes a step, THE System SHALL visually mark that step as complete with a checkmark
3. WHEN the user is on Step 2 or Step 3, THE System SHALL allow navigating back to previous steps
4. WHEN the user navigates back to a previous step, THE System SHALL preserve all uploaded documents
5. WHEN the user returns to a step, THE System SHALL display previously uploaded documents

#### Data Structure

```
DocumentPackage (FAP)
├── Step 1: Purchase Order
│   └── 1 PO Document (required)
│
├── Step 2: Campaigns
│   └── Campaign 1
│       ├── Activity Duration (Start Date, End Date, Working Days)
│       ├── Multiple Invoices (at least 1 required)
│       │   └── Invoice Document + Fields (Invoice No, Date, Amount, GST)
│       ├── Multiple Photos (at least 1 required)
│       ├── 1 Cost Summary (required)
│       └── 1 Activity Summary (required)
│   └── Campaign 2
│       └── ... (same structure)
│
└── Step 3: Additional Documents (at PO level)
    ├── 1 Enquiry Document (optional)
    └── Multiple Additional Documents (optional)
```

#### API Endpoints

##### Step 1: Purchase Order
- `POST /api/documents/upload` - Upload PO document (creates package if new)

##### Step 2: Campaigns
- `POST /api/hierarchical/{packageId}/campaigns` - Add new campaign
- `POST /api/hierarchical/{packageId}/campaigns/{campaignId}/invoices` - Add invoice to campaign
- `POST /api/hierarchical/{packageId}/campaigns/{campaignId}/photos` - Add photos to campaign
- `POST /api/hierarchical/{packageId}/campaigns/{campaignId}/cost-summary` - Upload cost summary for campaign
- `POST /api/hierarchical/{packageId}/campaigns/{campaignId}/activity-summary` - Upload activity summary for campaign
- `DELETE /api/hierarchical/{packageId}/campaigns/{campaignId}` - Delete campaign and all its documents

##### Step 3: Additional Documents
- `POST /api/hierarchical/{packageId}/enquiry-doc` - Upload enquiry document
- `POST /api/hierarchical/{packageId}/additional-docs` - Upload additional documents

##### Submission
- `POST /api/submissions/{packageId}/process-async` - Submit for processing (triggers backend validation)

##### Query
- `GET /api/hierarchical/{packageId}/structure` - Get full package structure with all documents

#### Frontend Validation (Per Step)

| Step | Required Documents | Validation Message |
|------|-------------------|-------------------|
| Step 1 | PO Document | "Please upload a Purchase Order document to proceed" |
| Step 2 | At least 1 Campaign | "Please add at least one campaign" |
| Step 2 | At least 1 Invoice per Campaign | "Please upload at least one invoice for each campaign" |
| Step 2 | At least 1 Photo per Campaign | "Please upload at least one photo for each campaign" |
| Step 2 | Cost Summary per Campaign | "Please upload a cost summary for each campaign" |
| Step 2 | Activity Summary per Campaign | "Please upload an activity summary for each campaign" |
| Step 3 | None (all optional) | N/A |

#### Backend Validation (At Submission)

| Validation Type | Description |
|----------------|-------------|
| Field-level | Validate extracted fields from each document (PO number format, amounts, dates) |
| Cross-document | Validate PO amount matches sum of all invoice amounts across all campaigns |
| Cross-document | Validate invoice dates within PO date range |
| Cross-document | Validate photo timestamps within campaign dates |
| Cross-document | Validate cost summary totals match invoice amounts per campaign |
| SAP Verification | Verify PO number exists in SAP system |
| Completeness | Verify all required documents are present for each campaign |


### Requirement 24: Campaign Details Screen Improvements

**User Story:** As a user, I want improvements and corrections in the Campaign Details screen, so that the interface becomes simpler and functions work as expected.

#### Description

Enhancements are required in the Campaign Details section to improve usability and correct existing issues. These changes include adding a new field, removing unnecessary elements, fixing a calendar widget issue, and implementing a photo upload limit.

#### Requirements

##### 1. Add Campaign Name Field
- A new "Campaign Name" field should be added in the Campaign Details section
- The user must enter the campaign name while filling in campaign information
- Campaign Name is a required field

##### 2. Remove Campaign Grid Header
- The "Campaign 1" grid header should be removed from the UI to simplify the interface
- Campaigns should be displayed without numbered headers

##### 3. Remove Capture GPS Feature
- The Capture GPS field and button should be removed from the UI
- This functionality is no longer required

##### 4. Fix Calendar Widget
- The Calendar widget should function correctly
- When the user clicks the date field, the calendar picker should open properly and allow date selection
- Both Start Date and End Date fields should use the calendar picker

##### 5. Photo Upload Limit
- In Campaign Details → Photo Upload, users should be allowed to upload a maximum of 50 photos per campaign
- The system should restrict uploads beyond 50 photos and display an appropriate validation message

#### Acceptance Criteria

1. WHEN the user views Campaign Details, THE System SHALL display a "Campaign Name" text input field
2. WHEN the user adds a new campaign, THE System SHALL require the Campaign Name field to be filled
3. WHEN the user attempts to proceed without entering Campaign Name, THE System SHALL display a validation error
4. WHEN displaying campaigns, THE System SHALL NOT show "Campaign 1", "Campaign 2" grid headers
5. WHEN displaying Campaign Details, THE System SHALL NOT show the Capture GPS field or button
6. WHEN the user clicks on the Start Date field, THE System SHALL open a calendar picker widget
7. WHEN the user clicks on the End Date field, THE System SHALL open a calendar picker widget
8. WHEN the user selects a date from the calendar picker, THE System SHALL populate the date field with the selected date
9. WHEN the user uploads photos in Campaign Details, THE System SHALL allow a maximum of 50 photos per campaign
10. WHEN the user attempts to upload more than 50 photos, THE System SHALL display a validation message: "Maximum 50 photos allowed per campaign"
11. WHEN the user has already uploaded 50 photos, THE System SHALL disable the photo upload button or prevent additional uploads

#### UI Changes Summary

| Change | Before | After |
|--------|--------|-------|
| Campaign Name | Not present | New required text field |
| Campaign Header | "Campaign 1", "Campaign 2" | No numbered headers |
| Capture GPS | Field + Button visible | Removed |
| Calendar Widget | Not working properly | Opens on click, allows date selection |
| Photo Limit | 20 photos | 50 photos with validation |


### Requirement 25: Campaign Request Approval Workflow (Agency → ASM → RA)

**User Story:** As an Agency user, I want to submit campaign requests that go through ASM and RA approval stages, so that the request can be reviewed, approved, rejected, and corrected if necessary.

#### Description

A simplified workflow where a request submitted by the Agency moves through two approval stages (ASM → RA) with defined status transitions. The system supports rejection flows where requests can be sent back to the Agency for corrections.

#### Workflow Steps and Status Display

##### 1. Agency Submission
The Agency submits a request. Data extraction takes place (Extracting state). After extraction completes:

| Action          | Agency Status       | ASM Status | RA Status |
|-----------------|---------------------|------------|-----------|
| Submits request | Extracting → Pending with ASM | Pending    | —         |

##### 2. ASM Approval
If ASM approves the request:

| Action          | Agency Status       | ASM Status      | RA Status |
|-----------------|---------------------|-----------------|-----------|
| Approved By ASM | Pending with RA     | Pending with RA | Pending   |

##### 3. RA Approval
If RA approves the request:

| Action          | Agency Status | ASM Status | RA Status |
|-----------------|---------------|------------|-----------|
| Approved by RA  | Approved      | Approved   | Approved  |

##### 4. Rejected by ASM
If ASM rejects the request:

| Action          | Agency Status       | ASM Status | RA Status |
|-----------------|---------------------|------------|-----------|
| Rejected by ASM | Rejected by ASM     | Rejected   | —         |

The request returns to Agency. Agency can edit and resubmit to ASM.

##### 5. Rejected by RA
If RA rejects the request:

| Action          | Agency Status       | ASM Status      | RA Status      |
|-----------------|---------------------|-----------------|----------------|
| Rejected by RA  | Rejected by RA      | Rejected by RA  | Rejected       |

The request goes directly to Agency. Agency can view RA rejection comments, edit the submission, and resubmit. Resubmission follows the normal flow: Agency → ASM → RA.

#### Acceptance Criteria

1. WHEN an Agency submits a request, THE System SHALL perform extraction (Extracting state) and change status to Pending with ASM (PendingWithASM) after completion
2. WHEN ASM approves a request, THE System SHALL move the request to RA for approval (PendingWithRA) and display "Pending with RA" to Agency and ASM, "Pending" to RA
3. WHEN RA approves a request, THE System SHALL set status to Approved for all roles
4. WHEN ASM rejects a request, THE System SHALL set status to RejectedByASM and display "Rejected by ASM" to Agency, "Rejected" to ASM
5. WHEN Agency receives a rejected request (RejectedByASM), THE System SHALL allow the Agency to edit and resubmit the request to ASM
6. WHEN RA rejects a request, THE System SHALL set status to RejectedByRA and display "Rejected by RA" to Agency and ASM, "Rejected" to RA
7. WHEN Agency receives an RA-rejected request (RejectedByRA), THE System SHALL display the RA rejection comments and allow the Agency to edit and resubmit
8. WHEN Agency resubmits an RA-rejected request, THE System SHALL reset the workflow and follow the normal flow: Agency → ASM → RA
9. WHEN Agency resubmits a corrected request, THE System SHALL increment the resubmission count and re-trigger the workflow
10. WHEN displaying status to Agency, THE System SHALL show: "Extracting", "Pending with ASM", "Pending with RA", "Approved", "Rejected by ASM", "Rejected by RA"
11. WHEN displaying status to ASM, THE System SHALL show: "Pending", "Pending with RA", "Approved", "Rejected", "Rejected by RA"
12. WHEN displaying status to RA, THE System SHALL show: "Pending", "Approved", "Rejected"
13. WHEN displaying rejection comments, THE System SHALL show ASMReviewNotes for RejectedByASM status and HQReviewNotes for RejectedByRA status
14. WHEN the Agency detail page shows a rejected submission (RejectedByASM or RejectedByRA), THE System SHALL display the rejection comments and an "Edit & Resubmit" button
15. WHEN the ASM detail page shows a submission, THE System SHALL display consistent Reject and Approve buttons regardless of previous rejection history
16. THE System SHALL NOT display any other statuses beyond: Extracting, Pending with ASM, Pending with RA, Approved, Rejected by ASM, Rejected by RA
