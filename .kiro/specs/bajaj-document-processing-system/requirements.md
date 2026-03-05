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
9. WHEN a user uploads multiple photos, THE System SHALL allow up to 20 photos per submission
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
