# Implementation Plan: Push Notifications Feature

## Overview

This implementation plan breaks down the push notifications feature into discrete, independently verifiable tasks. The feature extends the Bajaj Document Processing System with cross-platform push notification delivery for iOS, Android, and web users through APNs and FCM services.

The implementation follows a layered approach: database setup → domain/infrastructure services → application services → API layer → frontend integration → testing. Each task builds on previous steps with no orphaned code.

## Tasks

- [x] 1. Database Setup and Migrations
  - [x] 1.1 Create DeviceToken, NotificationPreference, and NotificationLog entities
    - Define domain entities with all required properties and navigation relationships
    - Add BaseEntity inheritance for Id, CreatedAt, UpdatedAt, IsDeleted
    - _Requirements: 1.2, 4.2, 8.1_
  
  - [x] 1.2 Create EF Core entity configurations with indexes and constraints
    - Configure DeviceToken with unique constraint (UserId, Platform, Token)
    - Configure NotificationPreference with unique constraint (UserId, NotificationType)
    - Add indexes for efficient lookups (UserId, Platform, IsActive, SentAt)
    - Configure foreign keys and cascade delete behavior
    - _Requirements: 1.2, 1.5, 8.1_
  
  - [x] 1.3 Create database migration for new tables
    - Generate EF Core migration with all three tables
    - Verify migration includes all constraints and indexes
    - Test migration on development database
    - _Requirements: 1.2, 4.2, 8.1_

- [x] 2. Infrastructure Layer - Platform Services Setup
  - [x] 2.1 Implement ApnsService for iOS push notifications
    - Create IApnsService interface with SendAsync and ValidateCredentialsAsync methods
    - Implement ApnsService with certificate-based authentication (P8 key)
    - Format APNs-specific JSON payloads with aps structure
    - Handle APNs response codes and error mapping
    - Implement credential validation during service initialization
    - _Requirements: 3.1, 3.4, 3.6_
  
  - [x] 2.2 Implement FcmService for Android/Web push notifications
    - Create IFcmService interface with SendAsync, SendMulticastAsync, and ValidateCredentialsAsync methods
    - Implement FcmService with service account JSON authentication
    - Format FCM-specific JSON payloads with notification and data structures
    - Support multicast sending (up to 500 tokens per request)
    - Handle FCM response codes and error mapping
    - Implement credential validation during service initialization
    - _Requirements: 3.2, 3.3, 3.4, 3.6_
  
  - [x] 2.3 Configure resilience policies (retry, circuit breaker, timeout)
    - Create ResiliencePolicies class with Polly policies
    - Implement exponential backoff retry policy (1s, 2s, 4s, max 3 attempts)
    - Implement circuit breaker (5 failures, 60s break duration)
    - Implement timeout policy (30s default)
    - Apply policies to ApnsService and FcmService HTTP clients
    - Log circuit breaker state changes at WARNING level
    - _Requirements: 3.5, 6.1, 6.6_
  
  - [x] 2.4 Configure HTTP clients for platform services
    - Register IHttpClientFactory for ApnsService and FcmService
    - Set appropriate timeouts and headers
    - Apply resilience policies via AddPolicyHandler
    - Configure base URLs and authentication headers
    - _Requirements: 3.1, 3.2, 3.3_

- [x] 3. Application Layer - Core Services
  - [x] 3.1 Implement DeviceTokenService
    - Create IDeviceTokenService interface with all required methods
    - Implement RegisterAsync: validate token format, check uniqueness, create or update record
    - Implement DeregisterAsync: mark token as inactive on logout
    - Implement DeregisterByTokenAsync: find and deregister by token value
    - Implement GetUserDeviceTokensAsync: retrieve active tokens for user
    - Implement RemoveInvalidTokenAsync: mark token as inactive after failed delivery
    - Add logging for all operations with user ID and platform
    - _Requirements: 1.2, 1.3, 1.4, 1.5, 1.6, 6.2, 8.1_
  
  - [x] 3.2 Implement NotificationPreferenceService
    - Create INotificationPreferenceService interface with all required methods
    - Implement GetPreferencesAsync: retrieve user preferences, create defaults if missing
    - Implement UpdatePreferencesAsync: validate and update preference records
    - Implement IsNotificationEnabledAsync: check if notification type is enabled for channel
    - Implement GetOrCreateDefaultAsync: ensure defaults exist for new users
    - Add logging for preference changes with old and new values
    - _Requirements: 4.2, 4.3, 4.4, 4.5, 4.6, 8.5_
  
  - [x] 3.3 Implement PushNotificationService
    - Create IPushNotificationService interface with SendAsync, SendToDeviceAsync, SendBatchAsync
    - Implement SendAsync: get user devices, check preferences, send to all devices
    - Implement SendToDeviceAsync: format payload per platform, send via ApnsService or FcmService
    - Implement SendBatchAsync: send to multiple devices efficiently
    - Implement payload formatting for each platform (APNs vs FCM)
    - Implement retry logic with exponential backoff for transient failures
    - Implement invalid token detection and removal
    - Add comprehensive logging with correlation ID
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 3.1, 3.2, 3.3, 3.6, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 6.1, 6.2, 6.3, 6.5, 8.2, 8.3_
  
  - [x] 3.4 Extend NotificationAgent to support push channel
    - Modify existing NotificationAgent to check user preferences
    - Add logic to determine which channels (email, push) are enabled
    - Call PushNotificationService when push is enabled
    - Maintain backward compatibility with email-only workflows
    - Handle graceful degradation if push service fails
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 9.1, 9.6_

- [x] 4. API Layer - Endpoints and DTOs
  - [x] 4.1 Create request/response DTOs for notifications
    - Create RegisterDeviceTokenRequest with Token and Platform properties
    - Create DeviceTokenResponse with Id, Platform, RegisteredAt, LastUsedAt, IsActive
    - Create UpdateNotificationPreferenceRequest with NotificationType, IsPushEnabled, IsEmailEnabled
    - Create NotificationPreferenceResponse with list of preferences
    - Create NotificationHistoryResponse with pagination support
    - Add DataAnnotations validation to all DTOs
    - _Requirements: 1.2, 4.2, 4.3_
  
  - [x] 4.2 Implement NotificationsController with device token endpoints
    - Create NotificationsController with [Authorize] attribute
    - Implement POST /api/notifications/device-tokens (RegisterDeviceTokenAsync)
    - Implement DELETE /api/notifications/device-tokens/{id} (DeregisterDeviceTokenAsync)
    - Add input validation and error handling
    - Return appropriate HTTP status codes (200, 201, 204, 400, 404, 409)
    - Log all operations with correlation ID
    - _Requirements: 1.2, 1.3, 1.4, 1.6_
  
  - [x] 4.3 Implement NotificationsController with preference endpoints
    - Implement GET /api/notifications/preferences (GetPreferencesAsync)
    - Implement PUT /api/notifications/preferences (UpdatePreferencesAsync)
    - Add input validation and error handling
    - Return appropriate HTTP status codes
    - Log preference changes
    - _Requirements: 4.2, 4.3, 4.4, 4.5, 4.6_
  
  - [x] 4.4 Implement NotificationsController with history endpoint
    - Implement GET /api/notifications/history (GetNotificationHistoryAsync)
    - Support filtering by notification type, date range, status
    - Implement pagination (default 20, max 100)
    - Return NotificationLog records with correlation ID
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 10.5_
  
  - [x] 4.5 Add error handling and validation
    - Add DataAnnotations validation to all request DTOs
    - Implement custom validation for token format and platform
    - Map domain exceptions to appropriate HTTP status codes
    - Return structured error responses with correlation ID
    - _Requirements: 9.4, 9.5_

- [-] 5. Backend Testing - Unit Tests
  - [x] 5.1 Write unit tests for DeviceTokenService
    - Test RegisterAsync: valid token, duplicate token, invalid format
    - Test DeregisterAsync: existing token, non-existent token
    - Test GetUserDeviceTokensAsync: multiple devices, no devices
    - Test RemoveInvalidTokenAsync: mark as inactive
    - Mock database context
    - _Requirements: 1.2, 1.3, 1.4, 1.5, 1.6_
  
  - [x] 5.2 Write unit tests for NotificationPreferenceService
    - Test GetPreferencesAsync: existing preferences, missing preferences (defaults)
    - Test UpdatePreferencesAsync: valid update, invalid notification type
    - Test IsNotificationEnabledAsync: enabled, disabled, default
    - Mock database context
    - _Requirements: 4.2, 4.3, 4.4, 4.5, 4.6_
  
  - [x] 5.3 Write unit tests for PushNotificationService
    - Test SendAsync: single device, multiple devices, no devices
    - Test SendToDeviceAsync: iOS (APNs), Android (FCM), Web (FCM)
    - Test payload formatting for each platform
    - Test retry logic: transient failures, non-retryable errors
    - Test invalid token detection and removal
    - Mock ApnsService and FcmService
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 3.1, 3.2, 3.3, 3.6, 6.1, 6.2_
  
  - [x] 5.4 Write unit tests for ApnsService
    - Test SendAsync: valid payload, invalid token, service error
    - Test ValidateCredentialsAsync: valid credentials, invalid credentials
    - Test payload formatting: title, body, custom data
    - Mock HTTP client
    - _Requirements: 3.1, 3.4, 3.6_
  
  - [x] 5.5 Write unit tests for FcmService
    - Test SendAsync: valid payload, invalid token, service error
    - Test SendMulticastAsync: multiple tokens, partial failures
    - Test ValidateCredentialsAsync: valid credentials, invalid credentials
    - Test payload formatting: notification, data, platform-specific configs
    - Mock HTTP client
    - _Requirements: 3.2, 3.3, 3.4, 3.6_
  
  - [x] 5.6 Write unit tests for NotificationsController
    - Test RegisterDeviceTokenAsync: valid request, invalid platform, duplicate token
    - Test DeregisterDeviceTokenAsync: existing token, non-existent token
    - Test GetPreferencesAsync: existing preferences, defaults
    - Test UpdatePreferencesAsync: valid update, invalid notification type
    - Test GetNotificationHistoryAsync: pagination, filtering
    - Mock services
    - _Requirements: 1.2, 1.3, 1.4, 1.6, 4.2, 4.3, 4.4, 4.5, 4.6, 8.6_

- [ ] 6. Backend Testing - Property-Based Tests
  - [ ] 6.1 Write property test for device token uniqueness
    - **Property 1: Device Token Uniqueness and Persistence**
    - **Validates: Requirements 1.2, 1.5, 1.6**
    - Generate random user IDs, platforms, tokens
    - Verify only one active record per user-platform combination
    - Verify duplicate registration updates existing record
    - Verify multiple devices have separate tokens
  
  - [ ] 6.2 Write property test for device token lifecycle
    - **Property 2: Device Token Lifecycle Management**
    - **Validates: Requirements 1.3, 1.4, 6.2, 9.2**
    - Verify registration marks token as active
    - Verify logout marks token as inactive
    - Verify invalid tokens are removed
    - Verify only active tokens returned in queries
  
  - [ ] 6.3 Write property test for multi-device notification delivery
    - **Property 3: Notification Delivery to All User Devices**
    - **Validates: Requirements 2.6, 2.7, 9.2**
    - Generate multiple device tokens per user
    - Verify notification sent to all active devices
    - Verify invalid token removal doesn't block other devices
  
  - [ ] 6.4 Write property test for platform-specific routing
    - **Property 4: Platform-Specific Routing and Payload Formatting**
    - **Validates: Requirements 3.1, 3.2, 3.3, 3.6**
    - Generate notifications for each platform (iOS, Android, Web)
    - Verify correct service called (ApnsService for iOS, FcmService for Android/Web)
    - Verify payload formatted correctly per platform
  
  - [ ] 6.5 Write property test for preference enforcement
    - **Property 5: User Preference Enforcement**
    - **Validates: Requirements 4.2, 4.3, 4.4, 4.5, 4.6**
    - Generate random preference combinations
    - Verify disabled notifications not sent
    - Verify enabled notifications sent
    - Verify defaults applied when preferences missing
  
  - [ ] 6.6 Write property test for notification content completeness
    - **Property 6: Notification Content Completeness**
    - **Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5**
    - Generate notifications of each type
    - Verify all required fields present
    - Verify deep links included
  
  - [ ] 6.7 Write property test for retry logic
    - **Property 7: Retry Logic with Exponential Backoff**
    - **Validates: Requirements 6.1, 3.5**
    - Simulate transient failures
    - Verify exponential backoff (1s, 2s, 4s)
    - Verify max 3 attempts
    - Verify non-retryable errors not retried
  
  - [ ] 6.8 Write property test for notification persistence and logging
    - **Property 8: Notification Persistence and Logging**
    - **Validates: Requirements 6.3, 6.4, 6.5, 8.1, 8.2, 8.3, 8.4, 8.5**
    - Verify all events logged with correlation ID
    - Verify notifications persisted before delivery
    - Verify delivery status recorded
  
  - [ ] 6.9 Write property test for circuit breaker pattern
    - **Property 9: Circuit Breaker Pattern for Platform Services**
    - **Validates: Requirements 6.6, 3.5**
    - Simulate 5 consecutive failures
    - Verify circuit opens and returns graceful error
    - Verify circuit transitions to half-open after 60s
    - Verify successful test request closes circuit
  
  - [ ] 6.10 Write property test for multi-channel delivery
    - **Property 10: Multi-Channel Notification Delivery**
    - **Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5, 7.6**
    - Generate notifications with various preference combinations
    - Verify correct channels used (email, push, both)
    - Verify same event data used for both channels
    - Verify backward compatibility with email-only workflows
  
  - [ ] 6.11 Write property test for graceful degradation
    - **Property 11: Graceful Degradation and Non-Blocking Behavior**
    - **Validates: Requirements 9.1, 9.3, 9.4, 9.5, 9.6**
    - Simulate various failures (invalid token, service unavailable, invalid payload)
    - Verify errors logged and invalid tokens removed
    - Verify document processing not blocked
    - Verify other notifications continue
  
  - [ ] 6.12 Write property test for async processing and performance
    - **Property 12: Asynchronous Processing and Performance**
    - **Validates: Requirements 10.1, 10.2, 10.3, 10.4, 10.5**
    - Verify notifications processed asynchronously
    - Verify delivery completes within 5 seconds
    - Verify batch APIs used for multiple devices
    - Verify pagination works correctly
  
  - [ ] 6.13 Write property test for credential validation
    - **Property 13: Credential Validation and Service Initialization**
    - **Validates: Requirements 3.4, 3.5**
    - Verify credentials validated at startup
    - Verify invalid credentials cause startup failure
    - Verify runtime failures logged and retried
  
  - [ ] 6.14 Write property test for content truncation
    - **Property 14: Notification Content Truncation**
    - **Validates: Requirements 5.6, 5.7**
    - Generate notifications with long titles and bodies
    - Verify truncation to platform limits
    - Verify ellipsis added to truncated content

- [ ] 7. Checkpoint - Backend Tests Pass
  - Ensure all unit tests pass: `dotnet test`
  - Ensure all property-based tests pass
  - Verify code coverage >80% for new services
  - Ask the user if questions arise.

- [x] 8. Frontend Integration - Device Token Management (Flutter)
  - [x] 8.1 Implement device token registration on login
    - Request device token from platform (APNs/FCM) after successful login
    - Call POST /api/notifications/device-tokens with token and platform
    - Handle registration errors gracefully
    - Store device token ID locally for logout
    - Log registration with user ID
    - _Requirements: 1.1, 1.2_
  
  - [x] 8.2 Implement device token cleanup on logout
    - Call DELETE /api/notifications/device-tokens/{id} on logout
    - Clear locally stored device token ID
    - Handle cleanup errors gracefully
    - Log deregistration
    - _Requirements: 1.3_
  
  - [x] 8.3 Implement notification preference UI
    - Create NotificationPreferencesPage with list of notification types
    - Fetch preferences on page load via GET /api/notifications/preferences
    - Display toggle switches for push and email per notification type
    - Call PUT /api/notifications/preferences on preference change
    - Show loading and error states
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_
  
  - [x] 8.4 Implement push notification handling and display
    - Configure Firebase Cloud Messaging (FCM) for Android/Web
    - Configure Apple Push Notification service (APNs) for iOS
    - Handle foreground notifications (show in-app alert)
    - Handle background notifications (update app state)
    - Display notification in notification center
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_
  
  - [x] 8.5 Implement deep linking for notifications
    - Parse deep link from notification payload
    - Navigate to relevant document/submission on notification tap
    - Handle invalid deep links gracefully
    - Maintain navigation state
    - _Requirements: 5.5_

- [ ] 9. Frontend Testing - Unit and Widget Tests (Flutter)
  - [ ] 9.1 Write unit tests for device token registration
    - Test successful registration with valid token
    - Test registration error handling
    - Test local storage of device token ID
    - Mock API client
    - _Requirements: 1.1, 1.2_
  
  - [ ] 9.2 Write unit tests for device token cleanup
    - Test successful deregistration
    - Test deregistration error handling
    - Test local storage cleanup
    - Mock API client
    - _Requirements: 1.3_
  
  - [ ] 9.3 Write widget tests for notification preferences UI
    - Test preference page loads and displays preferences
    - Test toggle switches update preferences
    - Test loading and error states
    - Test pagination for large preference lists
    - Mock API client
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_
  
  - [ ] 9.4 Write unit tests for push notification handling
    - Test foreground notification handling
    - Test background notification handling
    - Test notification display
    - Mock FCM/APNs
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_
  
  - [ ] 9.5 Write unit tests for deep linking
    - Test deep link parsing
    - Test navigation to correct screen
    - Test invalid deep link handling
    - Mock navigation
    - _Requirements: 5.5_

- [ ] 10. Checkpoint - Frontend Tests Pass
  - Ensure all Flutter tests pass: `flutter test`
  - Verify code coverage >80% for new features
  - Test on iOS simulator/device
  - Test on Android emulator/device
  - Ask the user if questions arise.

- [x] 11. Configuration and Deployment
  - [x] 11.1 Add APNs certificate configuration
    - Add APNs certificate path to appsettings.json
    - Add APNs key ID and team ID configuration
    - Implement certificate loading in ApnsService
    - Add validation during startup
    - _Requirements: 3.1, 3.4_
  
  - [x] 11.2 Add FCM service account configuration
    - Add FCM service account JSON path to appsettings.json
    - Implement service account loading in FcmService
    - Add validation during startup
    - _Requirements: 3.2, 3.3, 3.4_
  
  - [x] 11.3 Add environment-specific settings
    - Create appsettings.Development.json with test credentials
    - Create appsettings.Production.json with production credentials
    - Add configuration for retry policies and timeouts
    - Add configuration for circuit breaker thresholds
    - _Requirements: 3.4, 3.5, 6.1, 6.6_
  
  - [x] 11.4 Add health checks for platform services
    - Implement health check endpoint for APNs
    - Implement health check endpoint for FCM
    - Add health checks to /health/ready endpoint
    - Log health check results
    - _Requirements: 3.4, 3.5_

- [ ] 12. Integration Testing
  - [ ] 12.1 Write integration test for device token registration workflow
    - Test end-to-end registration from frontend to backend
    - Verify token stored in database
    - Verify token returned in preferences
    - Use test database
    - _Requirements: 1.1, 1.2, 1.5, 1.6_
  
  - [ ] 12.2 Write integration test for notification sending workflow
    - Test end-to-end notification sending
    - Mock APNs and FCM services
    - Verify notification logged
    - Verify device tokens updated
    - Use test database
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_
  
  - [ ] 12.3 Write integration test for preference management workflow
    - Test end-to-end preference update
    - Verify preferences applied to new notifications
    - Verify preferences logged
    - Use test database
    - _Requirements: 4.2, 4.3, 4.4, 4.5, 4.6_
  
  - [ ] 12.4 Write integration test for error scenarios
    - Test invalid token handling
    - Test service unavailability
    - Test invalid payload
    - Verify graceful degradation
    - Use test database
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6_

- [ ] 13. Final Checkpoint - All Tests Pass
  - Ensure all unit tests pass: `dotnet test`
  - Ensure all property-based tests pass
  - Ensure all integration tests pass
  - Ensure all Flutter tests pass: `flutter test`
  - Verify code coverage >80% for all new code
  - Verify no compiler warnings
  - Ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Property-based tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- Integration tests validate end-to-end workflows
- All tasks follow the technology stack: .NET 8 backend, Flutter frontend
- Resilience policies (retry, circuit breaker) are critical for reliability
- Logging with correlation IDs is essential for debugging and auditing
- Device token management is critical for notification delivery
- User preferences must be enforced to prevent notification spam
