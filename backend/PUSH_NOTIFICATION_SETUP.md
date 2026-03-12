# Push Notification Setup Guide

This guide explains how to configure Apple Push Notification service (APNs) and Firebase Cloud Messaging (FCM) for the Bajaj Document Processing System.

## Prerequisites

- Apple Developer Account (for iOS push notifications)
- Firebase/Google Cloud Project (for Android and Web push notifications)

## APNs Configuration (iOS)

### 1. Generate APNs Authentication Key

1. Go to [Apple Developer Portal](https://developer.apple.com/account/)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select **Keys** from the sidebar
4. Click the **+** button to create a new key
5. Enter a key name (e.g., "Bajaj Push Notifications")
6. Check **Apple Push Notifications service (APNs)**
7. Click **Continue** and then **Register**
8. Download the `.p8` file (you can only download it once!)
9. Note the **Key ID** (10-character string)

### 2. Get Your Team ID

1. In Apple Developer Portal, go to **Membership**
2. Copy your **Team ID** (10-character string)

### 3. Get Your Bundle ID

1. In Apple Developer Portal, go to **Identifiers**
2. Select your app identifier
3. Copy the **Bundle ID** (e.g., `com.bajaj.documentprocessing`)

### 4. Configure appsettings.json

Update the `Apns` section in `appsettings.json` or `appsettings.Production.json`:

```json
{
  "Apns": {
    "KeyId": "YOUR_10_CHAR_KEY_ID",
    "TeamId": "YOUR_10_CHAR_TEAM_ID",
    "BundleId": "com.bajaj.documentprocessing",
    "KeyFilePath": "certificates/AuthKey_XXXXXXXXXX.p8",
    "IsProduction": false
  }
}
```

- Set `IsProduction` to `false` for development/sandbox APNs
- Set `IsProduction` to `true` for production APNs

### 5. Place the .p8 Key File

1. Create a `certificates` folder in your API project root (or use an absolute path)
2. Copy the downloaded `.p8` file to this location
3. Ensure the file path matches `KeyFilePath` in your configuration

**Security Note**: Never commit the `.p8` file to version control. Add `certificates/` to `.gitignore`.

## FCM Configuration (Android & Web)

### 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **Add project** or select an existing project
3. Follow the setup wizard

### 2. Generate Service Account Key

1. In Firebase Console, click the gear icon → **Project settings**
2. Go to the **Service accounts** tab
3. Click **Generate new private key**
4. Confirm and download the JSON file
5. Note your **Project ID** (shown at the top of Project settings)

### 3. Configure appsettings.json

Update the `Fcm` section in `appsettings.json` or `appsettings.Production.json`:

```json
{
  "Fcm": {
    "ServiceAccountJsonPath": "certificates/firebase-service-account.json",
    "ProjectId": "your-firebase-project-id"
  }
}
```

### 4. Place the Service Account JSON File

1. Create a `certificates` folder in your API project root (or use an absolute path)
2. Copy the downloaded service account JSON file to this location
3. Ensure the file path matches `ServiceAccountJsonPath` in your configuration

**Security Note**: Never commit the service account JSON to version control. Add `certificates/` to `.gitignore`.

## Resilience Configuration

The `PushNotification` section controls retry logic, circuit breaker, and timeouts:

```json
{
  "PushNotification": {
    "Retry": {
      "MaxAttempts": 3,
      "BaseDelaySeconds": 1
    },
    "CircuitBreaker": {
      "FailureThreshold": 5,
      "BreakDurationSeconds": 60
    },
    "TimeoutSeconds": 30
  }
}
```

### Development vs Production Settings

**Development** (appsettings.Development.json):
- `BaseDelaySeconds`: 1 (faster retries for testing)
- `FailureThreshold`: 5 (more sensitive)
- `BreakDurationSeconds`: 60 (shorter break)
- `TimeoutSeconds`: 30

**Production** (appsettings.Production.json):
- `BaseDelaySeconds`: 2 (longer delays to avoid rate limits)
- `FailureThreshold`: 10 (more tolerant)
- `BreakDurationSeconds`: 120 (longer break to allow recovery)
- `TimeoutSeconds`: 45 (longer timeout for network variability)

## Health Checks

The API exposes health check endpoints to verify push notification configuration:

- **Liveness**: `GET /health` - Basic health check (no dependencies)
- **Readiness**: `GET /health/ready` - Includes APNs and FCM configuration checks

Example readiness response:

```json
{
  "status": "Healthy",
  "totalDuration": 12.5,
  "checks": [
    {
      "name": "apns",
      "status": "Healthy",
      "description": "APNs is configured",
      "duration": 5.2
    },
    {
      "name": "fcm",
      "status": "Healthy",
      "description": "FCM is configured",
      "duration": 7.3
    }
  ]
}
```

## Testing

### 1. Verify Configuration

Run the API and check the health endpoint:

```bash
curl https://localhost:7001/health/ready
```

Both `apns` and `fcm` checks should return `Healthy`.

### 2. Register a Device Token

Use the Flutter app or Postman to register a device token:

```http
POST /api/notifications/device-tokens
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: application/json

{
  "token": "your-device-token-from-fcm-or-apns",
  "platform": "iOS"
}
```

### 3. Trigger a Notification

Perform an action that triggers a notification (e.g., submit a document package). Check the logs for push notification delivery status.

## Troubleshooting

### APNs Issues

- **401 Unauthorized**: Check KeyId, TeamId, and .p8 file path
- **403 Forbidden**: Verify BundleId matches your app
- **410 Gone**: Device token is invalid (user uninstalled app)

### FCM Issues

- **401 Unauthorized**: Check service account JSON path and ProjectId
- **404 Not Found**: Verify ProjectId is correct
- **400 Bad Request**: Check token format

### Circuit Breaker Open

If you see "Circuit breaker is open" errors:
1. Check the health endpoint to see which service is failing
2. Verify credentials and network connectivity
3. Wait for the break duration to expire (60s dev, 120s prod)
4. Fix the underlying issue before the circuit closes

## Security Best Practices

1. **Never commit credentials**: Add `certificates/` to `.gitignore`
2. **Use environment variables**: For production, consider using Azure Key Vault or environment variables instead of appsettings.json
3. **Rotate keys regularly**: Regenerate APNs keys and FCM service accounts periodically
4. **Restrict permissions**: FCM service account should have minimal required permissions
5. **Monitor logs**: Watch for invalid tokens and remove them promptly

## Frontend Configuration

The Flutter app needs corresponding configuration:

### iOS (APNs)
- Add Push Notifications capability in Xcode
- Configure APNs in `ios/Runner/Runner.entitlements`
- Add `firebase_messaging` package to `pubspec.yaml`

### Android (FCM)
- Add `google-services.json` to `android/app/`
- Configure FCM in `android/app/build.gradle`
- Add `firebase_messaging` package to `pubspec.yaml`

### Web (FCM)
- Add Firebase config to `web/index.html`
- Generate VAPID key in Firebase Console
- Configure service worker for background notifications

Refer to the Flutter frontend documentation for detailed setup instructions.
