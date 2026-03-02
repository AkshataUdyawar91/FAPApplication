# Implementation Plan: Bajaj Document Processing System

## Overview

This implementation plan breaks down the Bajaj Document Processing System into discrete coding tasks. The system will be built incrementally, starting with core infrastructure, then implementing each agent/service, and finally integrating the Flutter frontend. Each task builds on previous work, with checkpoints to ensure stability before proceeding.

## Technology Stack

- **Backend**: .NET 8 Web API with C#
- **Frontend**: Flutter (Dart)
- **Database**: SQL Server
- **AI**: Semantic Kernel, Azure OpenAI, Azure Document Intelligence
- **Vector Database**: Azure AI Search
- **Testing**: xUnit + FsCheck for .NET, Flutter Test for Flutter

## Tasks

- [x] 1. Set up project structure and core infrastructure
  - Create .NET 8 Web API project with clean architecture (API, Application, Domain, Infrastructure layers)
  - Create Flutter project with feature-based folder structure
  - Set up SQL Server database and connection strings
  - Configure Azure services (OpenAI, Document Intelligence, Communication Services, Blob Storage, AI Search)
  - Set up dependency injection and configuration management
  - Create base entity classes and common interfaces
  - _Requirements: 13.1, 12.1_

- [x] 1.1 Write unit tests for project setup
  - Test configuration loading
  - Test dependency injection container
  - _Requirements: 13.1_

- [x] 2. Implement database schema and Entity Framework Core models
  - [x] 2.1 Create Entity Framework Core DbContext and entity models
    - Implement User, DocumentPackage, Document, ValidationResult, ConfidenceScore, Recommendation, Notification, AuditLog entities
    - Configure relationships and constraints
    - Add indexes for performance
    - _Requirements: 12.1, 12.3_
  
  - [x] 2.2 Create and apply database migrations
    - Generate initial migration with all tables
    - Apply migration to create database schema
    - Seed initial test data (users with different roles)
    - _Requirements: 12.1_
  
  - [x] 2.3 Write property test for referential integrity
    - **Property 58: Referential Integrity**
    - **Validates: Requirements 12.3**
  
  - [x] 2.4 Write property test for entity persistence
    - **Property 56: Entity Persistence**
    - **Validates: Requirements 12.1**

- [x] 3. Implement authentication and authorization
  - [x] 3.1 Create authentication service with JWT token generation
    - Implement password hashing with bcrypt (12 rounds minimum)
    - Implement login endpoint with credential validation
    - Generate JWT tokens with role claims
    - _Requirements: 10.1, 10.2, 16.3_
  
  - [x] 3.2 Implement authorization middleware and role-based access control
    - Create authorization policies for Agency, ASM, HQ roles
    - Implement middleware to validate JWT tokens
    - Add role-based endpoint protection
    - _Requirements: 10.3, 10.4, 10.5, 10.6_
  
  - [x] 3.3 Implement session management with expiration
    - Add session timeout logic (30 minutes inactivity)
    - Implement token refresh mechanism
    - _Requirements: 10.7_
  
  - [x] 3.4 Write property test for password hashing
    - **Property 77: Password Hashing**
    - **Validates: Requirements 16.3**
  
  - [x] 3.5 Write property test for role-based authorization
    - **Property 50: Role-Based Authorization**
    - **Validates: Requirements 10.3, 10.4, 10.5**
  
  - [x] 3.6 Write property test for session expiration
    - **Property 52: Session Expiration**
    - **Validates: Requirements 10.7**

- [x] 4. Checkpoint - Ensure authentication tests pass
  - Ensure all tests pass, ask the user if questions arise.


- [x] 5. Implement file upload and storage service
  - [x] 5.1 Create file upload API endpoints with multipart form data support
    - Implement POST /api/documents/upload endpoint
    - Add file validation (format, size limits per document type)
    - Upload files to Azure Blob Storage
    - Return file URLs and metadata
    - _Requirements: 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 13.7_
  
  - [x] 5.2 Implement malware scanning before storage
    - Integrate malware scanning service
    - Reject files that fail scanning
    - _Requirements: 16.4_
  
  - [x] 5.3 Write property test for document upload validation
    - **Property 1: Document Upload Validation**
    - **Validates: Requirements 1.2, 1.3, 1.4, 1.5, 1.6, 1.7**
  
  - [x] 5.4 Write property test for upload confirmation display
    - **Property 2: Upload Confirmation Display**
    - **Validates: Requirements 1.8**
  
  - [x] 5.5 Write property test for photo upload limit
    - **Property 3: Photo Upload Limit**
    - **Validates: Requirements 1.9**
  
  - [x] 5.6 Write property test for malware scanning
    - **Property 78: Malware Scanning**
    - **Validates: Requirements 16.4**

- [x] 6. Implement Document Agent with Azure Document Intelligence
  - [x] 6.1 Create DocumentAgent service with classification logic
    - Integrate Azure OpenAI GPT-4 Vision for document classification
    - Implement classification for PO, Invoice, Cost_Summary, Photo, Additional_Document
    - Return classification with confidence score
    - _Requirements: 2.1_
  
  - [x] 6.2 Implement field extraction for each document type
    - Create Azure Document Intelligence custom models for PO, Invoice, Cost Summary
    - Implement extraction methods for each document type
    - Extract EXIF metadata from photos
    - Calculate per-document confidence scores
    - Store extracted data as JSON in database
    - _Requirements: 2.2, 2.3, 2.4, 2.5, 2.7_
  
  - [x] 6.3 Implement low-confidence flagging
    - Flag documents with confidence below threshold for manual review
    - _Requirements: 2.6_
  
  - [x] 6.4 Write property test for document classification
    - **Property 5: Document Classification**
    - **Validates: Requirements 2.1**
  
  - [x] 6.5 Write property test for extraction completeness
    - **Property 6: Extraction Completeness**
    - **Validates: Requirements 2.2, 2.3, 2.4**
  
  - [x] 6.6 Write property test for extraction persistence round-trip
    - **Property 9: Extraction Persistence Round-Trip**
    - **Validates: Requirements 2.7**

- [x] 7. Implement Validation Agent with SAP integration
  - [x] 7.1 Create ValidationAgent service with SAP OData client
    - Implement SAP OData API client for PO verification
    - Add circuit breaker pattern for SAP failures
    - Implement retry logic with exponential backoff
    - _Requirements: 3.1, 3.7, 15.2_
  
  - [x] 7.2 Implement cross-document validation rules
    - Implement amount consistency validation (±2% tolerance)
    - Implement line item matching validation
    - Implement completeness check (11 required items)
    - Implement date validation
    - Implement vendor matching
    - _Requirements: 3.2, 3.3, 3.4_
  
  - [x] 7.3 Implement validation result recording
    - Store validation results with field-level details
    - Record specific validation failures with expected/actual values
    - Update package state on validation completion
    - _Requirements: 3.5, 3.6_
  
  - [x] 7.4 Write property test for amount consistency validation
    - **Property 11: Amount Consistency Validation**
    - **Validates: Requirements 3.2**
  
  - [x] 7.5 Write property test for line item matching
    - **Property 12: Line Item Matching**
    - **Validates: Requirements 3.3**
  
  - [x] 7.6 Write property test for completeness validation
    - **Property 13: Completeness Validation**
    - **Validates: Requirements 3.4**
  
  - [x] 7.7 Write property test for SAP connection failure handling
    - **Property 16: SAP Connection Failure Handling**
    - **Validates: Requirements 3.7**

- [x] 8. Checkpoint - Ensure validation tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Implement Confidence Score Service
  - [x] 9.1 Create ConfidenceScoreService with weighted calculation
    - Implement weighted confidence score calculation (PO: 0.30, Invoice: 0.30, Cost Summary: 0.20, Activity: 0.10, Photos: 0.10)
    - Calculate per-document confidence from field-level confidences
    - Ensure score is between 0 and 100
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_
  
  - [x] 9.2 Implement low-confidence flagging
    - Flag packages with confidence < 70 for mandatory review
    - _Requirements: 4.8_
  
  - [x] 9.3 Write property test for confidence score calculation
    - **Property 17: Confidence Score Calculation**
    - **Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.6**
  
  - [x] 9.4 Write property test for confidence score bounds
    - **Property 18: Confidence Score Bounds**
    - **Validates: Requirements 4.7**

- [x] 10. Implement Recommendation Agent with Semantic Kernel
  - [x] 10.1 Create RecommendationAgent service with decision logic
    - Implement recommendation logic (APPROVE if confidence >= 85 and validation passed, REVIEW if 70-85, REJECT if < 70 or validation failed)
    - _Requirements: 5.1, 5.3, 5.4, 5.5_
  
  - [x] 10.2 Implement evidence generation using Semantic Kernel
    - Set up Semantic Kernel with Azure OpenAI GPT-4
    - Create prompt template for evidence generation
    - Generate plain-English evidence with specific citations
    - Include validation results and confidence factors in evidence
    - _Requirements: 5.2, 5.6_
  
  - [x] 10.3 Implement recommendation persistence
    - Store recommendation with package
    - _Requirements: 5.7_
  
  - [x] 10.4 Write property test for recommendation logic
    - **Property 22: Recommendation Logic**
    - **Validates: Requirements 5.3, 5.4, 5.5**
  
  - [x] 10.5 Write property test for evidence citations
    - **Property 23: Evidence Citations**
    - **Validates: Requirements 5.6**

- [x] 11. Implement Email Agent with Azure Communication Services
  - [x] 11.1 Create EmailAgent service with ACS integration
    - Set up Azure Communication Services client
    - Implement retry logic with exponential backoff (3 attempts)
    - Log delivery confirmations
    - _Requirements: 6.5, 6.6, 6.7_
  
  - [x] 11.2 Implement scenario-based email generation using Semantic Kernel
    - Create Semantic Kernel prompt templates for each scenario (data failure, data pass, approved, rejected)
    - Generate personalized email content based on validation results
    - Include specific field issues in data failure emails
    - _Requirements: 6.1, 6.2, 6.3, 6.4_
  
  - [x] 11.3 Write property test for email recipient routing
    - **Property 28: Email Recipient Routing**
    - **Validates: Requirements 6.5**
  
  - [x] 11.4 Write property test for email delivery retry
    - **Property 29: Email Delivery Retry**
    - **Validates: Requirements 6.6**

- [x] 12. Implement Notification Agent
  - [x] 12.1 Create NotificationAgent service
    - Implement in-app notification creation
    - Implement email notification via ACS
    - Support all notification types (submission received, flagged, approved, rejected, re-upload requested)
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_
  
  - [x] 12.2 Implement notification inbox and read status management
    - Create API endpoints for getting notifications
    - Implement unread-first ordering
    - Implement mark-as-read functionality with unread count update
    - _Requirements: 8.6, 8.7_
  
  - [x] 12.3 Write property test for submission notification creation
    - **Property 36: Submission Notification Creation**
    - **Validates: Requirements 8.1, 8.2**
  
  - [x] 12.4 Write property test for notification read state update
    - **Property 41: Notification Read State Update**
    - **Validates: Requirements 8.7**

- [x] 13. Checkpoint - Ensure agent tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 14. Implement Vector Database and embedding pipeline
  - [x] 14.1 Set up Azure AI Search index for analytics embeddings
    - Create Azure AI Search index with vector field (1536 dimensions)
    - Define metadata fields (state, timeRange, submissionCount, approvalRate, etc.)
    - Configure hybrid search (vector + keyword)
    - _Requirements: 9.2_
  
  - [x] 14.2 Implement embedding pipeline for analytics data
    - Create nightly job to aggregate analytics data from SQL database
    - Generate natural language descriptions of data points
    - Create embeddings using Azure OpenAI text-embedding-ada-002
    - Upsert embeddings to Azure AI Search
    - _Requirements: 9.6_
  
  - [x] 14.3 Write unit test for embedding pipeline
    - Test aggregation logic
    - Test embedding generation
    - Test index upsert
    - _Requirements: 9.6_

- [x] 15. Implement Guardrails services
  - [x] 15.1 Create InputGuardrailService
    - Implement query length validation (max 500 characters)
    - Integrate Azure Content Safety API for prompt injection detection
    - Implement SQL injection pattern detection
    - Implement rate limiting (10 queries per minute per user)
    - _Requirements: 9.3_
  
  - [x] 15.2 Create AuthorizationGuardrailService
    - Implement role verification (HQ only)
    - Implement data scope filtering based on user permissions
    - _Requirements: 9.3, 9.4_
  
  - [x] 15.3 Create OutputGuardrailService
    - Implement citation verification against source data
    - Integrate Azure Content Safety API for PII detection and redaction
    - Implement harmful content detection
    - Implement numeric verification against database
    - _Requirements: 9.3_
  
  - [x] 15.4 Write property test for unauthorized data access prevention
    - **Property 44: Unauthorized Data Access Prevention**
    - **Validates: Requirements 9.3, 9.4**

- [x] 16. Implement Chat Service with Semantic Kernel
  - [x] 16.1 Create Semantic Kernel plugins for analytics
    - Create AnalyticsPlugin with KernelFunctions for KPIs, state ROI, campaign data
    - Implement semantic search function
    - _Requirements: 9.1_
  
  - [x] 16.2 Implement ChatService with full guardrails integration
    - Build secure Semantic Kernel with function calling restrictions
    - Implement query processing flow (input guardrails → authorization → vector search → SK processing → output guardrails)
    - Implement conversation context management (last 10 messages)
    - Store conversations in database for audit
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.7_
  
  - [x] 16.3 Write property test for chat message processing
    - **Property 42: Chat Message Processing**
    - **Validates: Requirements 9.1**
  
  - [x] 16.4 Write property test for response citations
    - **Property 45: Response Citations**
    - **Validates: Requirements 9.5**
  
  - [x] 16.5 Write property test for conversation context maintenance
    - **Property 47: Conversation Context Maintenance**
    - **Validates: Requirements 9.7**

- [x] 17. Implement Analytics Agent
  - [x] 17.1 Create AnalyticsAgent service with KPI calculations
    - Implement KPI calculations (total submissions, approval rate, avg processing time, auto-approval rate, confidence distribution)
    - Implement state-level ROI calculations
    - Implement campaign breakdown analytics
    - Add Redis caching layer (5-minute TTL)
    - _Requirements: 7.1, 7.2, 7.3, 7.6_
  
  - [x] 17.2 Implement AI narrative generation using Semantic Kernel
    - Create Semantic Kernel prompt for narrative generation
    - Generate insights from KPI data
    - _Requirements: 7.5_
  
  - [x] 17.3 Implement Excel export functionality
    - Use EPPlus library to generate Excel files
    - Include all KPIs, state ROI, campaign data
    - Apply Bajaj branding (colors, logo)
    - _Requirements: 7.4_
  
  - [x] 17.4 Write property test for state-level ROI calculation
    - **Property 31: State-Level ROI Calculation**
    - **Validates: Requirements 7.2**
  
  - [x] 17.5 Write property test for analytics export completeness
    - **Property 33: Analytics Export Completeness**
    - **Validates: Requirements 7.4**

- [x] 18. Implement Workflow Orchestrator
  - [x] 18.1 Create WorkflowOrchestrator service with saga pattern
    - Implement ProcessSubmissionAsync method coordinating all agents
    - Implement state transitions (UPLOADED → EXTRACTING → VALIDATING → SCORING → RECOMMENDING → PENDING_APPROVAL)
    - Implement error handling with compensation actions
    - Implement idempotency checks
    - _Requirements: 3.6, 15.1_
  
  - [x] 18.2 Implement asynchronous processing with background jobs
    - Set up background job processing (Hangfire or similar)
    - Queue long-running operations
    - _Requirements: 14.7_
  
  - [x] 18.3 Write integration test for full workflow
    - Test end-to-end submission processing
    - Test error handling and compensation
    - _Requirements: 3.6_

- [x] 19. Checkpoint - Ensure orchestrator tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 20. Implement API endpoints for document submission and approval
  - [x] 20.1 Create submission API endpoints
    - POST /api/submissions (create new submission)
    - GET /api/submissions/{id} (get submission details)
    - GET /api/submissions (list submissions with filtering)
    - _Requirements: 13.1_
  
  - [x] 20.2 Create approval workflow API endpoints
    - PATCH /api/submissions/{id}/approve (ASM approves package)
    - PATCH /api/submissions/{id}/reject (ASM rejects package)
    - PATCH /api/submissions/{id}/request-reupload (ASM requests corrections)
    - _Requirements: 13.1_
  
  - [x] 20.3 Implement API request validation and error handling
    - Add FluentValidation for all DTOs
    - Implement global exception middleware
    - Return appropriate HTTP status codes
    - Include correlation IDs in responses
    - Log all requests and responses
    - _Requirements: 13.2, 13.3, 13.5, 13.6_
  
  - [x] 20.4 Write property test for API request validation
    - **Property 62: API Request Validation**
    - **Validates: Requirements 13.2**
  
  - [x] 20.5 Write property test for API error status codes
    - **Property 63: API Error Status Codes**
    - **Validates: Requirements 13.3**

- [x] 21. Implement API endpoints for analytics and chat
  - [x] 21.1 Create analytics API endpoints
    - GET /api/analytics/kpis (get KPI dashboard)
    - GET /api/analytics/state-roi (get state-level ROI)
    - GET /api/analytics/campaign-breakdown (get campaign analytics)
    - POST /api/analytics/export (export to Excel)
    - _Requirements: 13.1, 7.1, 7.2, 7.3, 7.4_
  
  - [x] 21.2 Create chat API endpoints
    - POST /api/chat/message (send chat message)
    - GET /api/chat/history (get conversation history)
    - _Requirements: 13.1, 9.1_
  
  - [x] 21.3 Write unit tests for analytics endpoints
    - Test KPI calculations
    - Test export generation
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [x] 22. Implement audit logging and security features
  - [x] 22.1 Create audit logging service
    - Log all user actions with timestamps and IP addresses
    - Log personal data access for compliance
    - _Requirements: 16.5, 16.6_
  
  - [x] 22.2 Implement data encryption at rest
    - Configure AES-256 encryption for sensitive database fields
    - _Requirements: 16.1_
  
  - [x] 22.3 Implement secure secret storage
    - Integrate Azure Key Vault for API keys and secrets
    - _Requirements: 16.7_
  
  - [x] 22.4 Write property test for audit event logging
    - **Property 79: Audit Event Logging**
    - **Validates: Requirements 16.5**
  
  - [x] 22.5 Write property test for data encryption at rest
    - **Property 76: Data Encryption at Rest**
    - **Validates: Requirements 16.1**

- [x] 23. Implement error handling and resilience patterns
  - [x] 23.1 Implement retry logic for database operations
    - Add retry policy for transient database failures (3 attempts)
    - _Requirements: 12.2, 15.6_
  
  - [x] 23.2 Implement circuit breaker for external services
    - Add circuit breaker for SAP, ACS, Azure AI services
    - Configure thresholds (5 failures, 60s open, 2 successes to close)
    - _Requirements: 15.2_
  
  - [x] 23.3 Implement request queuing for SAP unavailability
    - Queue validation requests when SAP is down
    - Process queue when SAP becomes available
    - _Requirements: 15.3_
  
  - [x] 23.4 Implement critical error alerting
    - Send alerts to administrators for critical errors
    - _Requirements: 15.7_
  
  - [x] 23.5 Write property test for external service retry
    - **Property 70: External Service Retry**
    - **Validates: Requirements 15.2**

- [x] 24. Checkpoint - Ensure backend is complete
  - Ensure all tests pass, ask the user if questions arise.

- [x] 25. Implement Flutter frontend - Authentication screens with Clean Architecture
  - [x] 25.1 Set up Flutter project structure with Clean Architecture
    - Create feature-based folder structure (core/, features/auth/, features/submission/, etc.)
    - Set up Riverpod for dependency injection and state management
    - Configure Dio HTTP client with interceptors (auth, logging, error handling)
    - Set up FlutterSecureStorage for token storage
    - Configure GoRouter for navigation
    - Create theme with Bajaj brand colors (White #FFFFFF, Light Blue #00A3E0, Dark Blue #003087)
    - _Requirements: 10.1, 11.1_
  
  - [x] 25.2 Implement authentication domain layer
    - Create User entity (pure Dart, no Flutter dependencies)
    - Create AuthRepository interface
    - Create LoginUseCase and LogoutUseCase
    - _Requirements: 10.1, 10.2_
  
  - [x] 25.3 Implement authentication data layer
    - Create UserModel with JSON serialization
    - Create AuthRemoteDataSource with Dio
    - Create AuthLocalDataSource with FlutterSecureStorage
    - Implement AuthRepositoryImpl with Either for error handling
    - _Requirements: 10.1, 16.2_
  
  - [x] 25.4 Implement authentication presentation layer
    - Create AuthNotifier with Riverpod StateNotifier
    - Create login screen with responsive layout (mobile/tablet/desktop breakpoints)
    - Implement form validation with proper error messages
    - Use const constructors for performance optimization
    - Add semantic labels for accessibility
    - Ensure 48x48 minimum touch targets
    - Store JWT token in FlutterSecureStorage
    - _Requirements: 10.1, 11.1, 11.5_
  
  - [x] 25.5 Implement session management and token refresh
    - Handle token expiration (30 minutes inactivity)
    - Implement automatic token refresh
    - Add session timeout detection
    - Implement logout functionality
    - _Requirements: 10.7_
  
  - [x] 25.6 Write comprehensive tests for authentication
    - Write unit tests for LoginUseCase and LogoutUseCase
    - Write widget tests for login screen (form validation, button states)
    - Write integration test for complete login flow
    - Mock AuthRepository for testing
    - _Requirements: 10.1_

- [x] 26. Implement Flutter frontend - Document submission screens (Agency role) with Clean Architecture
  - [x] 26.1 Implement submission domain layer
    - Create DocumentPackage, Document entities
    - Create DocumentRepository interface
    - Create SubmitDocumentsUseCase, GetSubmissionsUseCase
    - _Requirements: 1.1_
  
  - [x] 26.2 Implement submission data layer
    - Create DocumentPackageModel with JSON serialization
    - Create DocumentRemoteDataSource with Dio multipart upload
    - Implement DocumentRepositoryImpl with error handling
    - Implement file validation (format, size limits)
    - _Requirements: 1.2, 1.3, 1.4, 1.5, 1.6, 1.7_
  
  - [x] 26.3 Create reusable document upload widgets
    - Create DocumentUploadCard widget with const constructor
    - Create BajajPrimaryButton widget with loading state
    - Create FileValidationHelper utility
    - Use ValueKey for list items to preserve state
    - Ensure all widgets have semantic labels
    - _Requirements: 1.1, 11.1_
  
  - [x] 26.4 Create document upload screen with responsive design
    - Implement SubmissionNotifier with Riverpod
    - Create responsive layout (mobile: single column, tablet/desktop: grid)
    - Implement separate upload controls for PO, Invoice, Cost Summary, Photos, Additional Documents
    - Add file picker with format and size validation
    - Display upload confirmations with filename and size
    - Implement photo limit validation (20 photos max)
    - Enable submit button only when all required documents uploaded
    - Use ListView.builder for photo list (lazy loading)
    - Optimize images with CachedNetworkImage
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.8, 1.9, 1.10, 11.5_
  
  - [x] 26.5 Create submission status screen
    - Display submission details with proper spacing
    - Show processing state with loading indicators
    - Display validation results and confidence score
    - Show recommendation with evidence
    - Implement pull-to-refresh
    - Handle error states gracefully
    - _Requirements: 10.3_
  
  - [x] 26.6 Write comprehensive tests for submission feature
    - Write unit tests for SubmitDocumentsUseCase
    - Write widget tests for upload screen (file validation, button enablement, photo limit)
    - Write widget tests for DocumentUploadCard
    - Write integration test for complete submission flow
    - Test responsive layouts at different breakpoints
    - _Requirements: 1.10_

- [x] 27. Implement Flutter frontend - Approval workflow screens (ASM role) with Clean Architecture
  - [x] 27.1 Implement approval domain layer
    - Create ValidationResult, ConfidenceScore, Recommendation entities
    - Create ApprovalRepository interface
    - Create ApprovePackageUseCase, RejectPackageUseCase, RequestReuploadUseCase
    - _Requirements: 10.4_
  
  - [x] 27.2 Implement approval data layer
    - Create ValidationResultModel, ConfidenceScoreModel, RecommendationModel
    - Create ApprovalRemoteDataSource with Dio
    - Implement ApprovalRepositoryImpl
    - _Requirements: 10.4_
  
  - [x] 27.3 Create reusable approval widgets
    - Create ValidationResultCard widget
    - Create ConfidenceScoreWidget with visual indicators
    - Create RecommendationCard with evidence display
    - Create ApprovalActionButtons widget
    - Use const constructors for all static widgets
    - _Requirements: 10.4, 11.1_
  
  - [x] 27.4 Create submission review screen with responsive design
    - Implement ApprovalNotifier with Riverpod
    - Create responsive layout (mobile: scrollable, tablet/desktop: side-by-side)
    - Display document package details
    - Show extracted data from all documents in expandable cards
    - Display validation results with field-level details
    - Show confidence score breakdown with progress indicators
    - Display AI recommendation with evidence
    - Implement proper error handling and loading states
    - Add semantic labels for screen readers
    - _Requirements: 10.4, 11.5_
  
  - [x] 27.5 Create approval action dialogs
    - Implement approve confirmation dialog
    - Implement reject dialog with reason input and validation
    - Implement request re-upload dialog with field selection checkboxes
    - Add proper keyboard navigation
    - Ensure minimum 4.5:1 color contrast
    - _Requirements: 10.4_
  
  - [x] 27.6 Write comprehensive tests for approval feature
    - Write unit tests for approval use cases
    - Write widget tests for review screen (data display, action buttons)
    - Write widget tests for approval dialogs
    - Write integration test for complete approval flow
    - Test responsive layouts at different breakpoints
    - _Requirements: 10.4_

- [x] 28. Implement Flutter frontend - Analytics dashboard (HQ role) with Clean Architecture
  - [x] 28.1 Implement analytics domain layer
    - Create KPIDashboard, StateROI, CampaignBreakdown entities
    - Create AnalyticsRepository interface
    - Create GetKPIsUseCase, GetStateROIUseCase, GetCampaignBreakdownUseCase, ExportAnalyticsUseCase
    - _Requirements: 7.1, 7.2, 7.3_
  
  - [x] 28.2 Implement analytics data layer
    - Create analytics models with JSON serialization
    - Create AnalyticsRemoteDataSource with Dio
    - Implement AnalyticsRepositoryImpl
    - Implement caching with Hive (5-minute TTL)
    - _Requirements: 7.1, 7.6_
  
  - [x] 28.3 Create reusable analytics widgets
    - Create KPICard widget with const constructor
    - Create ChartWidget using fl_chart package
    - Create AIInsightCard for narrative display
    - Create ExportButton widget
    - Apply Bajaj branding to all charts
    - Use const constructors for performance
    - _Requirements: 11.1_
  
  - [x] 28.4 Create KPI dashboard screen with responsive design
    - Implement AnalyticsNotifier with Riverpod
    - Create responsive grid layout (mobile: 1 column, tablet: 2 columns, desktop: 3 columns)
    - Display KPI metrics (total submissions, approval rate, avg processing time, etc.)
    - Show state-level ROI visualizations with interactive charts
    - Display campaign breakdown charts
    - Show AI narrative in prominent card
    - Implement export to Excel button
    - Add pull-to-refresh functionality
    - Implement proper loading states with shimmer effect
    - Handle error states gracefully
    - Optimize chart rendering with keys
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 10.5, 11.5_
  
  - [x] 28.5 Implement data visualization with fl_chart
    - Create bar charts for submission counts
    - Create line charts for trends over time
    - Create pie charts for approval rate distribution
    - Ensure charts are accessible (provide data tables as alternative)
    - Add proper labels and legends
    - Implement touch interactions
    - _Requirements: 11.1_
  
  - [x] 28.6 Write comprehensive tests for analytics feature
    - Write unit tests for analytics use cases
    - Write widget tests for dashboard (KPI display, chart rendering)
    - Write widget tests for KPICard and ChartWidget
    - Write integration test for complete analytics flow
    - Test responsive layouts at different breakpoints
    - Test caching behavior
    - _Requirements: 7.1_

- [x] 29. Implement Flutter frontend - Chat interface (HQ role) with Clean Architecture
  - [x] 29.1 Implement chat domain layer
    - Create ChatMessage, ChatResponse, DataCitation entities
    - Create ChatRepository interface
    - Create SendMessageUseCase, GetConversationHistoryUseCase
    - _Requirements: 9.1_
  
  - [x] 29.2 Implement chat data layer
    - Create chat models with JSON serialization
    - Create ChatRemoteDataSource with Dio
    - Implement ChatRepositoryImpl
    - Implement conversation caching with Hive
    - _Requirements: 9.1, 9.7_
  
  - [x] 29.3 Create reusable chat widgets
    - Create ChatMessageBubble widget (user vs AI styling)
    - Create CitationCard widget for data sources
    - Create ChatInputField widget with send button
    - Create TypingIndicator widget
    - Use const constructors where possible
    - Add semantic labels for accessibility
    - _Requirements: 9.5, 11.1_
  
  - [x] 29.4 Create chat screen with responsive design
    - Implement ChatNotifier with Riverpod
    - Create responsive layout (mobile: full screen, tablet/desktop: side panel)
    - Implement chat message list with ListView.builder (lazy loading)
    - Display conversation history with proper scrolling
    - Add message input field at bottom
    - Display AI responses with citations
    - Show loading indicator during processing
    - Implement auto-scroll to latest message
    - Handle error messages for unauthorized queries
    - Maintain conversation context across messages
    - Optimize message list with keys for performance
    - _Requirements: 9.1, 9.5, 9.7, 10.5, 11.5_
  
  - [x] 29.5 Implement chat state management
    - Maintain conversation context in state
    - Handle message sending and receiving
    - Display error messages for unauthorized queries
    - Implement retry mechanism for failed messages
    - Clear conversation on user request
    - _Requirements: 9.7_
  
  - [x] 29.6 Write comprehensive tests for chat feature
    - Write unit tests for chat use cases
    - Write widget tests for chat screen (message display, input handling)
    - Write widget tests for ChatMessageBubble and CitationCard
    - Write integration test for complete chat flow
    - Test conversation context maintenance
    - Test responsive layouts at different breakpoints
    - _Requirements: 9.1_

- [x] 30. Implement Flutter frontend - Notification inbox with Clean Architecture
  - [x] 30.1 Implement notification domain layer
    - Create Notification entity
    - Create NotificationRepository interface
    - Create GetNotificationsUseCase, MarkAsReadUseCase
    - _Requirements: 8.6_
  
  - [x] 30.2 Implement notification data layer
    - Create NotificationModel with JSON serialization
    - Create NotificationRemoteDataSource with Dio
    - Implement NotificationRepositoryImpl
    - Implement local caching for offline access
    - _Requirements: 8.6_
  
  - [x] 30.3 Create reusable notification widgets
    - Create NotificationCard widget with read/unread styling
    - Create NotificationBadge widget for unread count
    - Create EmptyNotificationState widget
    - Use const constructors for static widgets
    - Add semantic labels for screen readers
    - _Requirements: 11.1_
  
  - [x] 30.4 Create notification inbox screen with responsive design
    - Implement NotificationNotifier with Riverpod
    - Create responsive layout (mobile: list, tablet/desktop: grid)
    - Display notifications with unread-first ordering using ListView.builder
    - Show notification type, title, message, timestamp
    - Implement mark-as-read on tap
    - Update unread count badge in real-time
    - Implement pull-to-refresh
    - Handle empty state with illustration
    - Add swipe-to-delete gesture (mobile only)
    - Optimize list with ValueKey for each notification
    - _Requirements: 8.6, 8.7, 11.5_
  
  - [x] 30.5 Implement notification state management
    - Fetch notifications from API
    - Handle real-time updates with polling (30-second interval)
    - Update unread count in app bar badge
    - Implement mark-as-read functionality
    - Handle notification navigation to related entities
    - _Requirements: 8.6_
  
  - [x] 30.6 Write comprehensive tests for notification feature
    - Write unit tests for notification use cases
    - Write widget tests for notification inbox (unread-first ordering, mark-as-read)
    - Write widget tests for NotificationCard
    - Write integration test for complete notification flow
    - Test responsive layouts at different breakpoints
    - _Requirements: 8.6, 8.7_

- [x] 31. Implement Flutter frontend - Responsive design, branding, and performance optimization
  - [x] 31.1 Create comprehensive theme system
    - Define BajajColors class with brand colors (White #FFFFFF, Light Blue #00A3E0, Dark Blue #003087)
    - Create BajajTextStyles with consistent typography
    - Define ThemeData with Bajaj branding
    - Create dark mode theme (optional)
    - Ensure minimum 4.5:1 color contrast for accessibility
    - _Requirements: 11.1, 11.2_
  
  - [x] 31.2 Apply Bajaj branding throughout the app
    - Add Bajaj logo to app bar (multiple resolutions: @1x, @2x, @3x)
    - Apply consistent typography and spacing using theme
    - Style error messages with brand colors
    - Create branded loading indicators
    - Add branded splash screen
    - Configure app icon for all platforms
    - _Requirements: 11.1, 11.2, 11.3, 11.7_
  
  - [x] 31.3 Implement responsive layouts for all screens
    - Create ResponsiveLayout widget with breakpoints (mobile: <600, tablet: 600-900, desktop: >900)
    - Create ResponsiveSpacing utility for adaptive padding
    - Refactor all screens to use responsive layouts
    - Test on multiple screen sizes (phone, tablet, desktop, web)
    - Ensure proper orientation handling (portrait/landscape)
    - _Requirements: 11.5_
  
  - [x] 31.4 Implement performance optimizations
    - Add const constructors to all stateless widgets
    - Add ValueKey to all list items
    - Implement lazy loading with ListView.builder for all lists
    - Optimize images with CachedNetworkImage
    - Implement image caching strategy
    - Add build method optimizations (extract complex widgets)
    - Profile app performance with Flutter DevTools
    - Optimize bundle size by removing unused dependencies
    - _Requirements: 14.1, 14.2_
  
  - [x] 31.5 Implement localization infrastructure
    - Set up l10n.yaml configuration
    - Create app_en.arb with all English strings
    - Externalize all hardcoded strings to ARB files
    - Configure MaterialApp with localization delegates
    - Prepare structure for Hindi localization (future)
    - _Requirements: 11.1_
  
  - [x] 31.6 Implement accessibility features
    - Add semantic labels to all interactive widgets
    - Ensure minimum 48x48 touch targets
    - Implement focus management for keyboard navigation
    - Add visible focus indicators
    - Test with TalkBack (Android) and VoiceOver (iOS)
    - Ensure color contrast meets WCAG AA standards
    - Provide alternative text for images
    - Announce dynamic content changes to screen readers
    - _Requirements: 11.1_
  
  - [x] 31.7 Write comprehensive tests for responsive layouts and theming
    - Write widget tests for ResponsiveLayout at different breakpoints
    - Write widget tests for theme application
    - Write visual regression tests for branding consistency
    - Test accessibility features with semantic labels
    - Test keyboard navigation
    - _Requirements: 11.5_

- [x] 32. Final checkpoint - Integration testing and deployment preparation
  - [x] 32.1 Run full integration test suite
    - Test end-to-end workflows across frontend and backend
    - Test all user roles and permissions
    - Test error scenarios and edge cases
    - _Requirements: All_
  
  - [x] 32.2 Performance testing
    - Test with 100 concurrent users
    - Verify document processing times
    - Verify API response times
    - _Requirements: 14.1, 14.2, 14.3, 14.4_
  
  - [x] 32.3 Security testing
    - Run OWASP ZAP vulnerability scan
    - Verify authentication and authorization
    - Test encryption and secure storage
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5, 16.6, 16.7_
  
  - [x] 32.4 Prepare deployment configuration
    - Create production configuration files
    - Set up Azure resources
    - Configure CI/CD pipeline
    - Create deployment documentation
    - _Requirements: All_

- [x] 33. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties (minimum 100 iterations each)
- Unit tests validate specific examples and edge cases
- Integration tests verify end-to-end workflows
- The implementation follows clean architecture principles with clear separation of concerns
- All AI operations use Semantic Kernel for consistency
- Multi-layer guardrails ensure safe AI operation
- Vector database enables natural language analytics queries

### Flutter Implementation Notes

- **Architecture**: Clean Architecture with feature-based folder structure (domain, data, presentation layers)
- **State Management**: Riverpod for type-safe, compile-time safe state management and dependency injection
- **Navigation**: GoRouter for declarative, type-safe routing with deep linking support
- **HTTP Client**: Dio with interceptors for authentication, logging, and error handling
- **Storage**: FlutterSecureStorage for sensitive data (tokens), Hive for non-sensitive caching
- **Performance**: Const constructors, ValueKey for lists, ListView.builder for lazy loading, CachedNetworkImage for images
- **Responsive Design**: LayoutBuilder with breakpoints (mobile <600, tablet 600-900, desktop >900)
- **Error Handling**: Either type for functional error handling, comprehensive validation, global error handler
- **Testing**: Widget tests for UI, unit tests for business logic, integration tests for flows
- **Accessibility**: Semantic labels, 48x48 touch targets, 4.5:1 color contrast, screen reader support
- **Localization**: ARB files with externalized strings, ready for multi-language support
- **Code Quality**: Feature-based organization, single responsibility principle, composition over inheritance

### Required Flutter Packages

```yaml
dependencies:
  flutter_riverpod: ^2.4.0      # State management
  go_router: ^12.0.0            # Navigation
  dio: ^5.4.0                   # HTTP client
  flutter_secure_storage: ^9.0.0  # Secure token storage
  hive: ^2.2.3                  # Local caching
  dartz: ^0.10.1                # Functional programming (Either)
  cached_network_image: ^3.3.0  # Image caching
  image_picker: ^1.0.4          # Image selection
  file_picker: ^6.1.1           # File selection
  fl_chart: ^0.65.0             # Charts for analytics
  intl: ^0.18.1                 # Internationalization
  equatable: ^2.0.5             # Value equality

dev_dependencies:
  build_runner: ^2.4.6          # Code generation
  riverpod_generator: ^2.3.0    # Riverpod code generation
  mockito: ^5.4.3               # Mocking for tests
  flutter_lints: ^3.0.0         # Linting rules
```


