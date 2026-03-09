# Tasks Document: Codebase Quality Improvement

## Overview

This document breaks down the quality improvement work into small, reviewable, testable tasks. Each task is independent and can be completed in 1-4 hours. Tasks are organized by priority (P0, P1, P2) and phase.

## Task Execution Rules

1. **One task at a time** - Complete and test before moving to next
2. **Tests must pass** - Run `dotnet test` before and after each task
3. **No behavior changes** - Existing functionality must work identically
4. **Small commits** - Each task is one commit with clear message
5. **Review checklist** - Verify against steering guidelines after each task

## Phase 1: P0 Critical Issues (Week 1)

### Milestone 1.1: Create DTO Infrastructure

- [x] 1.1.1 Create common DTO base classes
  - Create `Application/DTOs/Common/ErrorResponse.cs`
  - Create `Application/DTOs/Common/ValidationErrorResponse.cs`
  - Create `Application/DTOs/Common/PagedResponse.cs`
  - Add XML doc comments to all classes
  - Add JSON property name attributes
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 1.1.2 Create Auth DTOs
  - Create `Application/DTOs/Auth/LoginResponse.cs`
  - Add XML doc comments
  - Add JSON property name attributes
  - _Requirements: 1.1, 1.2_

- [x] 1.1.3 Create Submission DTOs
  - Create `Application/DTOs/Submissions/SubmissionListItemDto.cs`
  - Create `Application/DTOs/Submissions/SubmissionListResponse.cs`
  - Create `Application/DTOs/Submissions/SubmissionDetailResponse.cs`
  - Create `Application/DTOs/Submissions/DocumentDto.cs`
  - Add XML doc comments to all classes
  - _Requirements: 1.1, 1.2_

- [x] 1.1.4 Create Analytics DTOs
  - Create `Application/DTOs/Analytics/DashboardDataResponse.cs`
  - Create `Application/DTOs/Analytics/KpiMetricDto.cs`
  - Create `Application/DTOs/Analytics/CampaignBreakdownDto.cs`
  - Create `Application/DTOs/Analytics/StateRoiDto.cs`
  - Add XML doc comments to all classes
  - _Requirements: 1.1, 1.2_

- [x] 1.1.5 Create Chat DTOs
  - Create `Application/DTOs/Chat/ChatMessageResponse.cs`
  - Create `Application/DTOs/Chat/DataCitationDto.cs`
  - Create `Application/DTOs/Chat/SendMessageRequest.cs`
  - Add XML doc comments to all classes
  - _Requirements: 1.1, 1.2_


### Milestone 1.2: Replace Anonymous Objects in Controllers

- [x] 1.2.1 Refactor AuthController
  - Replace anonymous object in Login action with `LoginResponse`
  - Test login endpoint manually
  - Verify JWT token generation still works
  - Run `dotnet test`
  - _Requirements: 1.1, 1.2_

- [x] 1.2.2 Refactor SubmissionsController - List endpoint
  - Replace anonymous objects in GetSubmissions action
  - Use `PagedResponse<SubmissionListItemDto>`
  - Test list endpoint with pagination
  - Verify filtering and sorting still work
  - Run `dotnet test`
  - _Requirements: 1.1, 1.2_

- [x] 1.2.3 Refactor SubmissionsController - Detail endpoint
  - Replace anonymous object in GetSubmission action
  - Use `SubmissionDetailResponse`
  - Test detail endpoint
  - Verify all nested data loads correctly
  - Run `dotnet test`
  - _Requirements: 1.1, 1.2_

- [x] 1.2.4 Refactor SubmissionsController - Status endpoints
  - Replace anonymous objects in status update actions
  - Create `SubmissionStatusResponse` DTO if needed
  - Test approve/reject/reupload endpoints
  - Run `dotnet test`
  - _Requirements: 1.1, 1.2_

- [x] 1.2.5 Refactor AnalyticsController - Dashboard endpoint
  - Replace anonymous object in GetDashboard action
  - Use `DashboardDataResponse`
  - Test dashboard endpoint
  - Verify all KPIs display correctly
  - Run `dotnet test`
  - _Requirements: 1.1, 1.2_

- [x] 1.2.6 Refactor AnalyticsController - Export endpoint
  - Replace anonymous object in Export action
  - Create `AnalyticsExportResponse` DTO
  - Test export functionality
  - Run `dotnet test`
  - _Requirements: 1.1, 1.2_

- [x] 1.2.7 Refactor ChatController
  - Replace anonymous objects in SendMessage action
  - Use `ChatMessageResponse`
  - Test chat endpoint
  - Verify citations display correctly
  - Run `dotnet test`
  - _Requirements: 1.1, 1.2_

### Milestone 1.3: Remove TODO Comments

- [x] 1.3.1 Audit codebase for TODO comments
  - Search entire solution for "TODO"
  - Create list of all TODOs with file locations
  - Categorize: trivial, complex, obsolete, architectural
  - _Requirements: 3.1, 3.2_

- [x] 1.3.2 Resolve AnalyticsEmbeddingPipeline TODO
  - Review TODO in `AnalyticsEmbeddingPipeline.cs`
  - Either implement basic embedding logic or create GitHub issue
  - Remove TODO comment
  - Add implementation or issue reference
  - Run `dotnet test`
  - _Requirements: 3.2, 3.3_

- [x] 1.3.3 Resolve EmailAgent TODO
  - Review TODO in `EmailAgent.cs`
  - Implement email template selection logic
  - Remove TODO comment
  - Test email generation
  - Run `dotnet test`
  - _Requirements: 3.2, 3.3_

- [x] 1.3.4 Resolve remaining TODOs
  - Address all other TODOs found in audit
  - Implement, create issues, or remove as appropriate
  - Verify zero TODOs remain in production code
  - Run `dotnet test`
  - _Requirements: 3.1, 3.2, 3.3_

### Milestone 1.4: Fix Security Issues

- [x] 1.4.1 Add input validation to all DTOs
  - Review all request DTOs
  - Add DataAnnotations attributes (Required, StringLength, Range, etc.)
  - Test validation with invalid inputs
  - Verify 400 responses with validation errors
  - Run `dotnet test`
  - _Requirements: 9.2, 9.3_

- [x] 1.4.2 Implement file upload validation by magic bytes
  - Create `FileUploadValidator` utility class
  - Implement magic byte validation for PDF, JPG, PNG, TIFF
  - Update DocumentsController to use validator
  - Test with valid and invalid files
  - Run `dotnet test`
  - _Requirements: 9.3, 9.4_

- [x] 1.4.3 Sanitize error messages
  - Review all catch blocks in controllers
  - Ensure no internal details exposed (SQL, paths, stack traces)
  - Use generic error messages for clients
  - Log full details server-side only
  - Test error scenarios
  - Run `dotnet test`
  - _Requirements: 9.5, 9.6_

- [x] 1.4.4 Add resource ownership verification
  - Review all GET/PUT/DELETE endpoints
  - Add ownership checks for Agency users
  - Verify ASM/HQ users have appropriate access
  - Test with different user roles
  - Run `dotnet test`
  - _Requirements: 9.8_

## Phase 2: P1 High Priority (Week 2)

### Milestone 2.1: Add XML Documentation

- [x] 2.1.1 Enable XML documentation generation
  - Update API .csproj to generate XML file
  - Configure Swagger to include XML comments
  - Suppress warning 1591 (missing XML comments)
  - Build and verify XML file generated
  - _Requirements: 2.7_

- [x] 2.1.2 Document Domain entities
  - Add XML doc comments to all classes in Domain/Entities/
  - Document all public properties
  - Build and verify no warnings
  - _Requirements: 2.1, 2.3_

- [x] 2.1.3 Document Application interfaces
  - Add XML doc comments to all interfaces in Application/Common/Interfaces/
  - Document all methods with summary, params, returns, exceptions
  - Build and verify no warnings
  - _Requirements: 2.2, 2.4, 2.5_

- [x] 2.1.4 Document Infrastructure services (Part 1)
  - Add XML doc comments to ValidationAgent
  - Add XML doc comments to DocumentAgent
  - Add XML doc comments to ConfidenceScoreService
  - Build and verify no warnings
  - _Requirements: 2.2, 2.4, 2.5_

- [x] 2.1.5 Document Infrastructure services (Part 2)
  - Add XML doc comments to RecommendationAgent
  - Add XML doc comments to EmailAgent
  - Add XML doc comments to AnalyticsAgent
  - Build and verify no warnings
  - _Requirements: 2.2, 2.4, 2.5_

- [x] 2.1.6 Document Infrastructure services (Part 3)
  - Add XML doc comments to NotificationAgent
  - Add XML doc comments to ChatService
  - Add XML doc comments to WorkflowOrchestrator
  - Build and verify no warnings
  - _Requirements: 2.2, 2.4, 2.5_

- [x] 2.1.7 Document API controllers
  - Add XML doc comments to all controller classes
  - Add XML doc comments to all action methods
  - Build and verify no warnings
  - Check Swagger UI for documentation
  - _Requirements: 2.2, 2.4, 2.7_

- [x] 2.1.8 Document DTOs
  - Add XML doc comments to all DTO classes
  - Document all properties
  - Build and verify no warnings
  - _Requirements: 2.1, 2.3, 2.6_

### Milestone 2.2: Implement Global Exception Handling

- [x] 2.2.1 Create custom exception types
  - Create Domain/Exceptions/ folder
  - Create NotFoundException
  - Create ValidationException with Errors property
  - Create ForbiddenException
  - Create ConflictException
  - Add XML doc comments
  - _Requirements: 5.1, 5.2_

- [x] 2.2.2 Create GlobalExceptionMiddleware
  - Create API/Middleware/GlobalExceptionMiddleware.cs
  - Implement exception handling for each custom exception type
  - Map exceptions to HTTP status codes
  - Return typed ErrorResponse DTOs
  - Add structured logging
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8_

- [x] 2.2.3 Register middleware in Program.cs
  - Add GlobalExceptionMiddleware to pipeline
  - Ensure it's registered early (before routing)
  - Test with various exception scenarios
  - Verify error responses are consistent
  - _Requirements: 5.1_

- [x] 2.2.4 Remove try-catch from controllers
  - Review all controller actions
  - Remove try-catch blocks (let middleware handle)
  - Keep only specific catches where needed
  - Test all endpoints
  - Run `dotnet test`
  - _Requirements: 5.1_

- [x] 2.2.5 Update services to throw custom exceptions
  - Replace generic exceptions with custom types
  - Use NotFoundException when entities not found
  - Use ValidationException for business rule violations
  - Use ForbiddenException for authorization failures
  - Test exception handling
  - Run `dotnet test`
  - _Requirements: 5.1, 5.2_

### Milestone 2.3: Implement Correlation ID and Structured Logging

- [x] 2.3.1 Create CorrelationIdMiddleware
  - Create API/Middleware/CorrelationIdMiddleware.cs
  - Generate or extract correlation ID from header
  - Store in HttpContext.Items
  - Add to response header
  - Test with and without incoming correlation ID
  - _Requirements: 8.3, 8.7_

- [x] 2.3.2 Create ICorrelationIdService
  - Create Application/Common/Interfaces/ICorrelationIdService.cs
  - Define GetCorrelationId() method
  - Add XML doc comments
  - _Requirements: 8.3_

- [x] 2.3.3 Implement CorrelationIdService
  - Create Infrastructure/Services/CorrelationIdService.cs
  - Implement using IHttpContextAccessor
  - Register as Scoped in DI
  - Test correlation ID retrieval
  - _Requirements: 8.3_

- [x] 2.3.4 Register middleware and service
  - Add CorrelationIdMiddleware to Program.cs
  - Register ICorrelationIdService in DI
  - Ensure middleware runs before exception middleware
  - Test correlation ID flow
  - _Requirements: 8.3, 8.7_

- [x] 2.3.5 Add structured logging to ValidationAgent
  - Inject ICorrelationIdService
  - Add log entry at method entry
  - Add log exit at method exit
  - Include correlation ID in all log messages
  - Use structured logging (message templates)
  - Test and verify logs
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6_

- [ ] 2.3.6 Add structured logging to DocumentAgent
  - Inject ICorrelationIdService
  - Add entry/exit logging
  - Include correlation ID
  - Use appropriate log levels
  - Test and verify logs
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [ ] 2.3.7 Add structured logging to remaining services
  - Add logging to ConfidenceScoreService
  - Add logging to RecommendationAgent
  - Add logging to EmailAgent
  - Add logging to AnalyticsAgent
  - Add logging to NotificationAgent
  - Add logging to ChatService
  - Add logging to WorkflowOrchestrator
  - Test and verify logs
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [ ] 2.3.8 Update error responses to include correlation ID
  - Update ErrorResponse DTO to include CorrelationId
  - Update GlobalExceptionMiddleware to populate correlation ID
  - Test error responses
  - Verify correlation ID in response
  - _Requirements: 8.3_

## Phase 3: P2 Medium Priority (Week 3-4)

### Milestone 3.1: Refactor Large Files

- [ ] 3.1.1 Analyze file sizes
  - Run script to find files >500 lines
  - Create list of files to refactor
  - Prioritize by size and complexity
  - _Requirements: 4.1_

- [ ] 3.1.2 Refactor ValidationAgent (if >500 lines)
  - Analyze responsibilities
  - Extract SapValidationService
  - Extract CrossDocumentValidationService
  - Extract CompletenessValidationService
  - Update DI registrations
  - Test all validation scenarios
  - Run `dotnet test`
  - _Requirements: 4.1, 4.3, 4.4_

- [ ] 3.1.3 Refactor DocumentAgent (if >500 lines)
  - Analyze responsibilities
  - Extract classification logic to separate service
  - Extract extraction logic to separate service
  - Update DI registrations
  - Test document processing
  - Run `dotnet test`
  - _Requirements: 4.1, 4.3, 4.4_

- [ ] 3.1.4 Refactor WorkflowOrchestrator (if >500 lines)
  - Analyze responsibilities
  - Extract workflow steps to separate methods
  - Consider extracting state machine logic
  - Update DI registrations
  - Test workflow execution
  - Run `dotnet test`
  - _Requirements: 4.1, 4.3, 4.4_

- [ ] 3.1.5 Refactor other large files
  - Address remaining files >500 lines
  - Apply single responsibility principle
  - Test after each refactoring
  - Run `dotnet test`
  - _Requirements: 4.1, 4.3, 4.4, 4.6_

### Milestone 3.2: Refactor Large Methods

- [ ] 3.2.1 Analyze method sizes
  - Run script to find methods >40 lines
  - Create list of methods to refactor
  - Prioritize by size and complexity
  - _Requirements: 4.2_

- [ ] 3.2.2 Refactor large controller methods
  - Extract helper methods
  - Use descriptive method names
  - Maintain single responsibility
  - Test endpoints
  - Run `dotnet test`
  - _Requirements: 4.2, 4.4, 4.5_

- [ ] 3.2.3 Refactor large service methods
  - Extract helper methods
  - Use descriptive method names
  - Maintain single responsibility
  - Test service methods
  - Run `dotnet test`
  - _Requirements: 4.2, 4.4, 4.5_

- [ ] 3.2.4 Verify no methods >40 lines
  - Run analysis script again
  - Verify all methods under limit
  - _Requirements: 4.2_

### Milestone 3.3: Fix N+1 Query Patterns

- [ ] 3.3.1 Enable EF Core query logging
  - Update appsettings.Development.json
  - Set Microsoft.EntityFrameworkCore to Debug level
  - Enable sensitive data logging
  - _Requirements: 6.1_

- [ ] 3.3.2 Audit all DbContext queries
  - Review all files using DbContext
  - Identify queries without Include()
  - Identify queries loading related entities in loops
  - Create list of N+1 patterns
  - _Requirements: 6.1, 6.2_

- [ ] 3.3.3 Fix N+1 in SubmissionsController
  - Add Include() for Documents
  - Add Include() for ConfidenceScore
  - Add Include() for ValidationResults
  - Use AsSplitQuery() if needed
  - Test query performance
  - Run `dotnet test`
  - _Requirements: 6.1, 6.2, 6.3_

- [ ] 3.3.4 Fix N+1 in AnalyticsController
  - Add Include() for related entities
  - Use AsSplitQuery() if needed
  - Test query performance
  - Run `dotnet test`
  - _Requirements: 6.1, 6.2, 6.3_

- [ ] 3.3.5 Fix N+1 in service layer
  - Add Include() to all repository queries
  - Use AsNoTracking() for read-only queries
  - Test query performance
  - Run `dotnet test`
  - _Requirements: 6.1, 6.2, 6.4, 6.5_

- [ ] 3.3.6 Verify no N+1 patterns remain
  - Review query logs
  - Verify single queries for related entities
  - Profile query performance
  - _Requirements: 6.1, 6.2, 6.5_

### Milestone 3.4: Add Missing Unit Tests

- [ ] 3.4.1 Audit test coverage
  - Run code coverage analysis
  - Identify untested services
  - Identify untested methods
  - Create list of missing tests
  - _Requirements: 7.1, 7.2_

- [ ] 3.4.2 Add tests for ValidationAgent
  - Test happy path validation
  - Test SAP validation failure
  - Test cross-document validation failure
  - Test completeness validation failure
  - Test exception scenarios
  - Achieve >80% coverage
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

- [ ] 3.4.3 Add tests for DocumentAgent
  - Test document classification
  - Test data extraction
  - Test classification failure
  - Test extraction failure
  - Achieve >80% coverage
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [ ] 3.4.4 Add tests for ConfidenceScoreService
  - Test weighted score calculation
  - Test score boundaries (0-100)
  - Test missing document scores
  - Achieve >80% coverage
  - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [ ] 3.4.5 Add tests for RecommendationAgent
  - Test APPROVE recommendation
  - Test REVIEW recommendation
  - Test REJECT recommendation
  - Test evidence generation
  - Achieve >80% coverage
  - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [ ] 3.4.6 Add tests for EmailAgent
  - Test email generation
  - Test template selection
  - Test email sending
  - Test retry logic
  - Achieve >80% coverage
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [ ] 3.4.7 Add tests for remaining services
  - Add tests for AnalyticsAgent
  - Add tests for NotificationAgent
  - Add tests for ChatService
  - Add tests for WorkflowOrchestrator
  - Achieve >80% coverage overall
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.7_

- [ ] 3.4.8 Add controller tests
  - Add tests for AuthController
  - Add tests for SubmissionsController
  - Add tests for AnalyticsController
  - Add tests for ChatController
  - Test authorization scenarios
  - _Requirements: 7.1, 7.2, 7.3, 7.4_

### Milestone 3.5: Improve Code Readability

- [ ] 3.5.1 Replace magic numbers with named constants
  - Search for numeric literals in business logic
  - Create named constants
  - Replace literals with constants
  - Test functionality
  - Run `dotnet test`
  - _Requirements: 10.5_

- [ ] 3.5.2 Add guard clauses to service methods
  - Review all service methods
  - Replace nested ifs with guard clauses
  - Use early returns for validation
  - Test functionality
  - Run `dotnet test`
  - _Requirements: 10.4_

- [ ] 3.5.3 Extract complex conditions
  - Identify complex boolean expressions
  - Extract to named methods or variables
  - Use descriptive names
  - Test functionality
  - Run `dotnet test`
  - _Requirements: 10.3_

- [ ] 3.5.4 Improve variable and method names
  - Review all names for clarity
  - Rename ambiguous variables
  - Rename ambiguous methods
  - Use descriptive names
  - Test functionality
  - Run `dotnet test`
  - _Requirements: 10.1, 10.2_

- [ ] 3.5.5 Remove commented-out code
  - Search for commented code blocks
  - Remove all commented code
  - Commit changes
  - _Requirements: 10.6_

- [ ] 3.5.6 Verify consistent formatting
  - Run code formatter
  - Verify .editorconfig compliance
  - Fix any formatting issues
  - _Requirements: 10.7_

## Final Checkpoint

- [ ] 4.1 Run complete test suite
  - Run `dotnet test` on entire solution
  - Verify all tests pass
  - Verify no new warnings
  - _All requirements_

- [ ] 4.2 Manual testing
  - Test all API endpoints manually
  - Test with different user roles
  - Test error scenarios
  - Verify no regressions
  - _All requirements_

- [ ] 4.3 Code review checklist
  - Review against dotnet-guidelines-new.md
  - Review against guidelines.md
  - Verify all requirements met
  - _All requirements_

- [ ] 4.4 Performance verification
  - Profile API response times
  - Verify no performance degradation
  - Check database query performance
  - _Requirements: 14.1, 14.2_

- [ ] 4.5 Security verification
  - Verify input validation on all endpoints
  - Verify file upload validation
  - Verify error message sanitization
  - Verify resource ownership checks
  - _Requirements: 16.1-16.7_

- [ ] 4.6 Documentation review
  - Verify XML comments on all public APIs
  - Verify Swagger documentation complete
  - Verify no TODO comments remain
  - _Requirements: 2.1-2.7, 3.1-3.5_

- [ ] 4.7 Metrics verification
  - Zero anonymous objects in API responses
  - 100% XML documentation coverage
  - Zero TODO comments
  - Zero files >500 lines
  - Zero methods >40 lines
  - >80% unit test coverage
  - Zero N+1 query patterns
  - _All requirements_

## Notes

- Each task should take 1-4 hours
- Run tests after every task
- Commit after every task with clear message
- If a task fails, rollback and investigate
- Keep existing functionality unchanged
- Follow steering guidelines strictly
- Ask for clarification if requirements are unclear
