# Push Notifications Feature - Design Document

## Overview

The push notifications feature extends the Bajaj Document Processing System with real-time, cross-platform push notification delivery for iOS, Android, and web users. This design integrates with the existing NotificationAgent to provide immediate alerts about document processing events while maintaining backward compatibility with the email notification system.

The feature introduces three new domain entities (DeviceToken, NotificationPreference, NotificationLog) and extends the notification workflow to support multiple delivery channels. Push notifications are delivered through platform-specific services: Apple Push Notification service (APNs) for iOS and Firebase Cloud Messaging (FCM) for Android and web.

## Architecture

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Frontend (Flutter)                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Device Token Registration (on login)                    │   │
│  │  Notification Preference Management                      │   │
│  │  Push Notification Handling & Display                    │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                    HTTP/REST API Calls
                              │
┌─────────────────────────────────────────────────────────────────┐
│                    Backend (.NET 8 API)                          │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  NotificationsController                                 │   │
│  │  - RegisterDeviceToken (POST)                            │   │
│  │  - DeregisterDeviceToken (DELETE)                        │   │
│  │  - GetNotificationPreferences (GET)                      │   │
│  │  - UpdateNotificationPreferences (PUT)                   │   │
│  │  - GetNotificationHistory (GET)                          │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                    │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Application Layer (Services & Use Cases)                │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │ NotificationAgent (Orchestrator)                   │  │   │
│  │  │ - Determines channels (email, push)                │  │   │
│  │  │ - Checks user preferences                          │  │   │
│  │  │ - Delegates to channel-specific services           │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │ PushNotificationService                            │  │   │
│  │  │ - Formats payloads per platform                    │  │   │
│  │  │ - Manages device tokens                            │  │   │
│  │  │ - Handles delivery & retries                       │  │   │
│  │  │ - Logs notification events                         │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │ DeviceTokenService                                 │  │   │
│  │  │ - Registers/deregisters tokens                     │  │   │
│  │  │ - Validates token uniqueness                       │  │   │
│  │  │ - Cleans up invalid tokens                         │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │ NotificationPreferenceService                      │  │   │
│  │  │ - Manages user preferences                         │  │   │
│  │  │ - Applies defaults                                 │  │   │
│  │  │ - Logs preference changes                          │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                    │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Infrastructure Layer (Platform Integrations)            │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │ ApnsService                                        │  │   │
│  │  │ - Connects to Apple Push Notification service      │  │   │
│  │  │ - Formats APNs-specific payloads                   │  │   │
│  │  │ - Handles APNs responses & errors                  │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │ FcmService                                         │  │   │
│  │  │ - Connects to Firebase Cloud Messaging             │  │   │
│  │  │ - Formats FCM-specific payloads                    │  │   │
│  │  │ - Handles FCM responses & errors                   │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │ Resilience Policies                                │  │   │
│  │  │ - Retry with exponential backoff                   │  │   │
│  │  │ - Circuit breaker pattern                          │  │   │
│  │  │ - Timeout policies                                 │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                    │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Persistence Layer (Database)                            │   │
│  │  - DeviceTokens table                                    │   │
│  │  - NotificationPreferences table                         │   │
│  │  - NotificationLogs table                                │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                    External Service Calls
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
    ┌───▼────┐           ┌───▼────┐           ┌───▼────┐
    │  APNs  │           │  FCM   │           │ Redis  │
    │ (iOS)  │           │(Android│           │(Cache) │
    │        │           │ & Web) │           │        │
    └────────┘           └────────┘           └────────┘
```

### Data Flow: Notification Sending

```
Document Event Triggered
        │
        ▼
NotificationAgent.SendNotificationAsync()
        │
        ├─ Check user preferences
        │
        ├─ If push enabled:
        │  │
        │  ▼
        │  PushNotificationService.SendAsync()
        │  │
        │  ├─ Get user's device tokens
        │  │
        │  ├─ For each device token:
        │  │  │
        │  │  ├─ Format payload (platform-specific)
        │  │  │
        │  │  ├─ Send via platform service (APNs/FCM)
        │  │  │
        │  │  ├─ Log attempt
        │  │  │
        │  │  └─ On failure: retry with backoff
        │  │
        │  └─ Log delivery results
        │
        └─ If email enabled:
           │
           ▼
           EmailAgent.SendAsync() [existing flow]
```

### Data Flow: Device Token Registration

```
User Logs In (Frontend)
        │
        ▼
Request device token from platform (APNs/FCM)
        │
        ▼
POST /api/notifications/device-tokens
        │
        ▼
NotificationsController.RegisterDeviceTokenAsync()
        │
        ▼
DeviceTokenService.RegisterAsync()
        │
        ├─ Validate token format
        │
        ├─ Check for existing token (user + platform)
        │
        ├─ If exists: update last_used timestamp
        │
        ├─ If new: create DeviceToken record
        │
        ├─ Log registration
        │
        └─ Return success
```

## Components and Interfaces

### Domain Layer

#### DeviceToken Entity
```csharp
public class DeviceToken : BaseEntity
{
    public Guid UserId { get; set; }
    public string Platform { get; set; }  // "iOS", "Android", "Web"
    public string Token { get; set; }
    public DateTime RegisteredAt { get; set; }
    public DateTime LastUsedAt { get; set; }
    public bool IsActive { get; set; }
    
    // Navigation
    public User User { get; set; }
}
```

#### NotificationPreference Entity
```csharp
public class NotificationPreference : BaseEntity
{
    public Guid UserId { get; set; }
    public string NotificationType { get; set; }  // "SubmissionStatusUpdate", "ApprovalDecision", etc.
    public bool IsPushEnabled { get; set; }
    public bool IsEmailEnabled { get; set; }
    public DateTime UpdatedAt { get; set; }
    
    // Navigation
    public User User { get; set; }
}
```

#### NotificationLog Entity
```csharp
public class NotificationLog : BaseEntity
{
    public Guid UserId { get; set; }
    public Guid? DeviceTokenId { get; set; }
    public string NotificationType { get; set; }
    public string Channel { get; set; }  // "Push", "Email"
    public string Platform { get; set; }  // "iOS", "Android", "Web", "Email"
    public string Status { get; set; }  // "Sent", "Failed", "Retrying"
    public string ErrorMessage { get; set; }
    public DateTime SentAt { get; set; }
    public string CorrelationId { get; set; }
    
    // Navigation
    public User User { get; set; }
    public DeviceToken DeviceToken { get; set; }
}
```

### Application Layer Interfaces

#### IDeviceTokenService
```csharp
public interface IDeviceTokenService
{
    Task<Result<DeviceTokenResponse>> RegisterAsync(
        Guid userId, 
        RegisterDeviceTokenRequest request, 
        CancellationToken cancellationToken);
    
    Task<Result> DeregisterAsync(
        Guid userId, 
        Guid deviceTokenId, 
        CancellationToken cancellationToken);
    
    Task<Result> DeregisterByTokenAsync(
        Guid userId, 
        string token, 
        CancellationToken cancellationToken);
    
    Task<IEnumerable<DeviceToken>> GetUserDeviceTokensAsync(
        Guid userId, 
        CancellationToken cancellationToken);
    
    Task<Result> RemoveInvalidTokenAsync(
        Guid deviceTokenId, 
        string reason, 
        CancellationToken cancellationToken);
}
```

#### INotificationPreferenceService
```csharp
public interface INotificationPreferenceService
{
    Task<NotificationPreferenceResponse> GetPreferencesAsync(
        Guid userId, 
        CancellationToken cancellationToken);
    
    Task<Result> UpdatePreferencesAsync(
        Guid userId, 
        UpdateNotificationPreferenceRequest request, 
        CancellationToken cancellationToken);
    
    Task<bool> IsNotificationEnabledAsync(
        Guid userId, 
        string notificationType, 
        string channel, 
        CancellationToken cancellationToken);
    
    Task<NotificationPreference> GetOrCreateDefaultAsync(
        Guid userId, 
        CancellationToken cancellationToken);
}
```

#### IPushNotificationService
```csharp
public interface IPushNotificationService
{
    Task<Result> SendAsync(
        Guid userId, 
        PushNotificationPayload payload, 
        CancellationToken cancellationToken);
    
    Task<Result> SendToDeviceAsync(
        DeviceToken deviceToken, 
        PushNotificationPayload payload, 
        CancellationToken cancellationToken);
    
    Task<Result> SendBatchAsync(
        IEnumerable<DeviceToken> deviceTokens, 
        PushNotificationPayload payload, 
        CancellationToken cancellationToken);
}
```

#### IApnsService (Infrastructure)
```csharp
public interface IApnsService
{
    Task<Result> SendAsync(
        string deviceToken, 
        ApnsPayload payload, 
        CancellationToken cancellationToken);
    
    Task<Result> ValidateCredentialsAsync(CancellationToken cancellationToken);
}
```

#### IFcmService (Infrastructure)
```csharp
public interface IFcmService
{
    Task<Result> SendAsync(
        string deviceToken, 
        FcmPayload payload, 
        CancellationToken cancellationToken);
    
    Task<Result> SendMulticastAsync(
        IEnumerable<string> deviceTokens, 
        FcmPayload payload, 
        CancellationToken cancellationToken);
    
    Task<Result> ValidateCredentialsAsync(CancellationToken cancellationToken);
}
```

## Data Models

### Request/Response DTOs

#### RegisterDeviceTokenRequest
```csharp
public record RegisterDeviceTokenRequest(
    [Required] string Token,
    [Required] string Platform  // "iOS", "Android", "Web"
);
```

#### DeviceTokenResponse
```csharp
public record DeviceTokenResponse(
    Guid Id,
    string Platform,
    DateTime RegisteredAt,
    DateTime LastUsedAt,
    bool IsActive
);
```

#### UpdateNotificationPreferenceRequest
```csharp
public record UpdateNotificationPreferenceRequest(
    [Required] string NotificationType,
    bool IsPushEnabled,
    bool IsEmailEnabled
);
```

#### NotificationPreferenceResponse
```csharp
public record NotificationPreferenceResponse(
    Guid UserId,
    IEnumerable<NotificationTypePreference> Preferences
);

public record NotificationTypePreference(
    string NotificationType,
    bool IsPushEnabled,
    bool IsEmailEnabled
);
```

#### PushNotificationPayload
```csharp
public record PushNotificationPayload(
    string Title,
    string Body,
    string NotificationType,
    Dictionary<string, string> Data,
    string DeepLink
);
```

#### ApnsPayload
```csharp
public record ApnsPayload(
    string Alert,
    string Sound,
    int Badge,
    Dictionary<string, string> CustomData
);
```

#### FcmPayload
```csharp
public record FcmPayload(
    string Title,
    string Body,
    Dictionary<string, string> Data,
    FcmAndroidConfig AndroidConfig,
    FcmWebpushConfig WebpushConfig
);

public record FcmAndroidConfig(
    string Priority,
    Dictionary<string, string> Data
);

public record FcmWebpushConfig(
    Dictionary<string, string> Headers,
    Dictionary<string, string> Data
);
```

### Database Schema

#### DeviceTokens Table
```sql
CREATE TABLE DeviceTokens (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    UserId UNIQUEIDENTIFIER NOT NULL,
    Platform NVARCHAR(50) NOT NULL,  -- iOS, Android, Web
    Token NVARCHAR(MAX) NOT NULL,
    RegisteredAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    LastUsedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    IsDeleted BIT NOT NULL DEFAULT 0,
    
    CONSTRAINT FK_DeviceTokens_Users FOREIGN KEY (UserId) REFERENCES Users(Id),
    CONSTRAINT UQ_DeviceTokens_UserPlatformToken UNIQUE (UserId, Platform, Token),
    CONSTRAINT IX_DeviceTokens_UserId_Platform NONCLUSTERED INDEX (UserId, Platform),
    CONSTRAINT IX_DeviceTokens_IsActive NONCLUSTERED INDEX (IsActive)
);
```

#### NotificationPreferences Table
```sql
CREATE TABLE NotificationPreferences (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    UserId UNIQUEIDENTIFIER NOT NULL,
    NotificationType NVARCHAR(100) NOT NULL,
    IsPushEnabled BIT NOT NULL DEFAULT 1,
    IsEmailEnabled BIT NOT NULL DEFAULT 1,
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    IsDeleted BIT NOT NULL DEFAULT 0,
    
    CONSTRAINT FK_NotificationPreferences_Users FOREIGN KEY (UserId) REFERENCES Users(Id),
    CONSTRAINT UQ_NotificationPreferences_UserType UNIQUE (UserId, NotificationType),
    CONSTRAINT IX_NotificationPreferences_UserId NONCLUSTERED INDEX (UserId)
);
```

#### NotificationLogs Table
```sql
CREATE TABLE NotificationLogs (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    UserId UNIQUEIDENTIFIER NOT NULL,
    DeviceTokenId UNIQUEIDENTIFIER NULL,
    NotificationType NVARCHAR(100) NOT NULL,
    Channel NVARCHAR(50) NOT NULL,  -- Push, Email
    Platform NVARCHAR(50) NOT NULL,  -- iOS, Android, Web, Email
    Status NVARCHAR(50) NOT NULL,  -- Sent, Failed, Retrying
    ErrorMessage NVARCHAR(MAX) NULL,
    SentAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CorrelationId NVARCHAR(100) NOT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    IsDeleted BIT NOT NULL DEFAULT 0,
    
    CONSTRAINT FK_NotificationLogs_Users FOREIGN KEY (UserId) REFERENCES Users(Id),
    CONSTRAINT FK_NotificationLogs_DeviceTokens FOREIGN KEY (DeviceTokenId) REFERENCES DeviceTokens(Id),
    CONSTRAINT IX_NotificationLogs_UserId_SentAt NONCLUSTERED INDEX (UserId, SentAt),
    CONSTRAINT IX_NotificationLogs_CorrelationId NONCLUSTERED INDEX (CorrelationId)
);
```

## Platform-Specific Implementation

### APNs Integration (iOS)

**Payload Format:**
```json
{
  "aps": {
    "alert": {
      "title": "Submission Status Update",
      "body": "Your document package has been validated"
    },
    "sound": "default",
    "badge": 1,
    "mutable-content": 1,
    "custom-key": "custom-value"
  },
  "deepLink": "app://submissions/package-id"
}
```

**Key Characteristics:**
- Uses certificate-based authentication (P8 key file)
- Supports rich notifications with custom actions
- Payload size limit: 4KB
- Supports background silent notifications
- Requires device token refresh handling

### FCM Integration (Android & Web)

**Payload Format:**
```json
{
  "token": "device-token",
  "notification": {
    "title": "Submission Status Update",
    "body": "Your document package has been validated"
  },
  "data": {
    "notificationType": "SubmissionStatusUpdate",
    "packageId": "package-id",
    "deepLink": "app://submissions/package-id"
  },
  "android": {
    "priority": "high",
    "notification": {
      "sound": "default",
      "channel_id": "document_updates"
    }
  },
  "webpush": {
    "headers": {
      "TTL": "3600"
    }
  }
}
```

**Key Characteristics:**
- Uses service account JSON authentication
- Supports multicast sending (up to 500 tokens per request)
- Payload size limit: 4KB
- Supports data-only messages for background processing
- Automatic token refresh handling

## Key Workflows

### Device Token Registration Flow

1. User logs in on mobile/web app
2. Frontend requests device token from platform (APNs/FCM)
3. Frontend calls `POST /api/notifications/device-tokens` with token and platform
4. Backend validates token format and platform
5. Backend checks for existing token (user + platform combination)
6. If exists: update `LastUsedAt` timestamp
7. If new: create DeviceToken record with `IsActive = true`
8. Log registration event with user ID, platform, timestamp
9. Return success response with device token ID

### Device Token Cleanup Flow

**On Logout:**
1. Frontend calls `DELETE /api/notifications/device-tokens/{deviceTokenId}`
2. Backend marks DeviceToken as `IsActive = false`
3. Log deregistration with reason "User logout"

**On Invalid Token (after failed delivery):**
1. Platform service returns error (e.g., "Invalid token")
2. Backend calls `DeviceTokenService.RemoveInvalidTokenAsync()`
3. Mark DeviceToken as `IsActive = false`
4. Log removal with reason "Invalid token" and error details

### Notification Sending Flow

1. Document event triggered (e.g., submission completed)
2. NotificationAgent.SendNotificationAsync() called
3. Check user's NotificationPreference for notification type
4. If push enabled:
   - Get user's active DeviceTokens
   - For each device token:
     - Format payload based on platform (APNs/FCM)
     - Send via platform service with retry policy
     - Log send attempt
     - On failure: retry with exponential backoff (max 3 attempts)
     - On invalid token error: mark token as inactive
5. If email enabled: delegate to EmailAgent (existing flow)
6. Return aggregated result

### User Preference Management Flow

1. User accesses notification settings in app
2. Frontend calls `GET /api/notifications/preferences`
3. Backend retrieves user's NotificationPreferences
4. If no preferences exist: create defaults (all enabled)
5. Return preferences grouped by notification type
6. User enables/disables notification types
7. Frontend calls `PUT /api/notifications/preferences` with updates
8. Backend validates request
9. Update NotificationPreference records
10. Log preference changes with old and new values
11. Return success response

## Resilience & Error Handling

### Retry Strategy

- **Exponential Backoff**: 1s, 2s, 4s (max 3 attempts)
- **Jitter**: Add random 0-100ms to prevent thundering herd
- **Retry Conditions**: Network timeouts, 5xx errors, rate limiting (429)
- **No Retry**: Invalid tokens (4xx errors except 429), malformed payloads

### Circuit Breaker Pattern

- **Failure Threshold**: 5 consecutive failures
- **Break Duration**: 60 seconds
- **Half-Open State**: Allow 1 test request after break duration
- **Monitoring**: Log circuit breaker state changes at WARNING level

### Invalid Token Detection

- APNs returns specific error codes for invalid tokens
- FCM returns error message "Invalid registration token"
- On detection: immediately mark token as inactive
- Log removal with error details and correlation ID
- Continue delivery to other devices

### Graceful Degradation

- If push service unavailable: log error, continue with other channels
- If user has no devices: skip push delivery, log condition
- If notification payload invalid: log error, skip delivery
- If preference lookup fails: use default preferences (all enabled)
- Never block document processing workflow on notification failures

## Error Handling

### Error Codes & Mapping

| Error | HTTP Status | Action |
|-------|-------------|--------|
| Invalid token format | 400 | Reject request |
| User not found | 404 | Return 404 |
| Duplicate device token | 409 | Update existing |
| Platform service unavailable | 503 | Retry with backoff |
| Invalid APNs credentials | 500 | Log critical, alert ops |
| FCM quota exceeded | 429 | Retry with backoff |
| Malformed notification payload | 400 | Log error, skip delivery |

### Logging Strategy

- **Entry/Exit**: Log method entry with key parameters, exit with result
- **Errors**: Log with exception details, correlation ID, user ID
- **Sensitive Data**: Never log tokens, credentials, or PII
- **Structured Logging**: Use ILogger with message templates
- **Correlation ID**: Propagate through all layers for tracing

## Testing Strategy

### Unit Testing

- **DeviceTokenService**: Registration, deregistration, validation, uniqueness
- **NotificationPreferenceService**: Get, update, defaults, preference checking
- **PushNotificationService**: Payload formatting, retry logic, error handling
- **ApnsService**: Payload formatting, credential validation, error mapping
- **FcmService**: Payload formatting, multicast, error mapping

### Property-Based Testing

- Device tokens are unique per user-platform combination
- Notifications respect user preferences (enabled/disabled)
- Failed deliveries are retried and logged
- No duplicate notifications sent to same device
- Notification delivery completes within 5 seconds
- Invalid tokens are removed after failed delivery
- Preference updates apply immediately to new notifications

### Integration Testing

- End-to-end device token registration and cleanup
- Notification sending with mock platform services
- Preference management workflow
- Notification history queries with pagination
- Error scenarios (invalid tokens, service unavailable)

### Test Coverage

- Minimum 80% code coverage for new services
- All error paths tested
- Edge cases: null inputs, empty collections, boundary values
- Concurrency: multiple devices per user, simultaneous registrations

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property Reflection & Redundancy Analysis

After analyzing all acceptance criteria, the following redundancies were identified and consolidated:

- **Device Token Uniqueness**: Requirements 1.2, 1.5, 1.6 all test uniqueness constraints. Consolidated into single property.
- **Preference Enforcement**: Requirements 4.2, 4.3, 4.4, 4.6 all test that preferences control notification delivery. Consolidated into single comprehensive property.
- **Notification Content**: Requirements 5.1-5.5 all test that notifications include required fields. Consolidated into single property.
- **Error Handling & Cleanup**: Requirements 6.2, 9.2 both test invalid token removal. Consolidated into single property.
- **Logging**: Requirements 8.1-8.5 all test that events are logged. Consolidated into single comprehensive logging property.
- **Graceful Degradation**: Requirements 9.1, 9.3, 9.6 all test that failures don't block processing. Consolidated into single property.
- **Multi-Channel Delivery**: Requirements 7.1-7.6 all test channel selection and delivery. Consolidated into single property.

### Property 1: Device Token Uniqueness and Persistence

*For any* user and platform combination, storing a device token should result in exactly one active record in the database. Registering the same token twice should update the existing record, not create a duplicate. Multiple devices for the same user should each have separate tokens.

**Validates: Requirements 1.2, 1.5, 1.6**

### Property 2: Device Token Lifecycle Management

*For any* device token, registering it should mark it as active, and logging out should mark it as inactive. Invalid tokens detected during delivery should be automatically removed. Querying active tokens for a user should only return tokens marked as active.

**Validates: Requirements 1.3, 1.4, 6.2, 9.2**

### Property 3: Notification Delivery to All User Devices

*For any* user with multiple registered devices and a triggered notification event, the notification should be sent to all active devices. If any device token is invalid, delivery should be attempted and the invalid token should be removed, but delivery to other devices should continue.

**Validates: Requirements 2.6, 2.7, 9.2**

### Property 4: Platform-Specific Routing and Payload Formatting

*For any* notification and device token with a specific platform (iOS, Android, Web), the notification should be routed to the correct platform service (APNs for iOS, FCM for Android/Web). The payload should be formatted according to platform-specific requirements (APNs JSON structure vs FCM JSON structure).

**Validates: Requirements 3.1, 3.2, 3.3, 3.6**

### Property 5: User Preference Enforcement

*For any* user and notification type, if the user has disabled that notification type for a channel, no notification should be sent through that channel. If a user has disabled push notifications entirely, no push notifications should be sent to any of their devices. If a user has not set preferences, default preferences (all enabled) should be applied.

**Validates: Requirements 4.2, 4.3, 4.4, 4.5, 4.6**

### Property 6: Notification Content Completeness

*For any* notification sent, the notification payload should include all required fields for its type: submission status notifications include package ID and status, approval decision notifications include decision and reason, validation failure notifications include error details, recommendation notifications include summary, and all notifications include a deep link to the relevant resource.

**Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5**

### Property 7: Retry Logic with Exponential Backoff

*For any* failed notification delivery, the system should retry with exponential backoff (1s, 2s, 4s) for a maximum of 3 attempts. Retries should only occur for transient failures (network timeouts, 5xx errors, rate limiting). Non-retryable errors (invalid tokens, malformed payloads) should not be retried.

**Validates: Requirements 6.1, 3.5**

### Property 8: Notification Persistence and Logging

*For any* notification event (registration, send attempt, delivery failure, preference change), the system should log the event with correlation ID, user ID, timestamp, and relevant details. Notifications should be persisted before delivery to ensure no loss on system restart. Delivery logs should record success/failure status.

**Validates: Requirements 6.3, 6.4, 6.5, 8.1, 8.2, 8.3, 8.4, 8.5**

### Property 9: Circuit Breaker Pattern for Platform Services

*For any* platform service (APNs, FCM), after 5 consecutive failures, the circuit breaker should open and return a graceful error without attempting further calls. After 60 seconds in the open state, the circuit should transition to half-open and allow a test request. Successful test request should close the circuit.

**Validates: Requirements 6.6, 3.5**

### Property 10: Multi-Channel Notification Delivery

*For any* notification event and user preferences, the system should determine which channels (email, push) are enabled. If both are enabled, notifications should be sent through both channels using the same event data. If only one is enabled, only that channel should be used. Existing email-only workflows should continue to work unchanged.

**Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5, 7.6**

### Property 11: Graceful Degradation and Non-Blocking Behavior

*For any* notification delivery failure (invalid token, service unavailable, invalid payload), the system should log the error, remove invalid tokens, and continue processing other notifications. Notification delivery failures should never block the document processing workflow. If a user has no registered devices, push delivery should be skipped and logged.

**Validates: Requirements 9.1, 9.3, 9.4, 9.5, 9.6**

### Property 12: Asynchronous Processing and Performance

*For any* notification event, the system should process notifications asynchronously without blocking the caller. Notification delivery should complete within 5 seconds for immediate delivery. When a user has multiple devices, notifications should be sent efficiently (using batch APIs where available). Notification history queries should support pagination with default page size 20, max 100.

**Validates: Requirements 10.1, 10.2, 10.3, 10.4, 10.5**

### Property 13: Credential Validation and Service Initialization

*For any* platform service (APNs, FCM), credentials should be validated during application startup. If credentials are invalid, the application should fail to start with a clear error message. If a platform service becomes unavailable during runtime, the system should log the failure and retry with exponential backoff.

**Validates: Requirements 3.4, 3.5**

### Property 14: Notification Content Truncation

*For any* notification with title or body exceeding platform limits (APNs: 65 chars for title, 240 chars for body; FCM: 200 chars for title, 4000 chars for body), the system should truncate the content to platform limits. Truncated body should end with ellipsis ("...").

**Validates: Requirements 5.6, 5.7**

