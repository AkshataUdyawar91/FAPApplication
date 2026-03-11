# Design Document: Camera Photo Upload for Agency Submissions

## Overview

The Camera Photo Upload feature enables Agency Users to capture photos directly from their device camera within the photo upload interface of the document submission workflow. This design provides a seamless, cross-platform camera capture experience integrated with the existing file picker upload mechanism.

### Key Design Goals

1. **Seamless Integration**: Captured photos behave identically to file-picker photos in the upload workflow
2. **Cross-Platform Compatibility**: Support mobile web views (iOS Safari, Android Chrome) and desktop browsers (Chrome, Firefox, Safari, Edge)
3. **Resource Efficiency**: Properly manage camera resources with cleanup on close or navigation
4. **Accessibility**: Full keyboard navigation and screen reader support
5. **Error Resilience**: Graceful degradation and clear error messaging for unsupported browsers or hardware failures
6. **Security**: Consistent validation and malware scanning with file-picker uploads

---

## Architecture

### High-Level Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Photo Upload Interface                        │
│  ┌──────────────────┐              ┌──────────────────┐         │
│  │  File Picker     │              │  Camera Button   │         │
│  │  Button          │              │  (NEW)           │         │
│  └──────────────────┘              └──────────────────┘         │
│                                            │                     │
│                                            ▼                     │
│                                   ┌─────────────────┐            │
│                                   │ Permission      │            │
│                                   │ Check           │            │
│                                   └─────────────────┘            │
│                                            │                     │
│                    ┌───────────────────────┼───────────────────┐ │
│                    ▼                       ▼                   ▼ │
│            ┌──────────────┐      ┌──────────────┐   ┌──────────┐│
│            │ Permission   │      │ Camera       │   │ Error    ││
│            │ Denied       │      │ Interface   │   │ Handler  ││
│            │ (Error)      │      │ (Capture)   │   │          ││
│            └──────────────┘      └──────────────┘   └──────────┘│
│                                            │                     │
│                                            ▼                     │
│                                   ┌─────────────────┐            │
│                                   │ Photo Preview   │            │
│                                   │ Interface       │            │
│                                   └─────────────────┘            │
│                                            │                     │
│                    ┌───────────────────────┼───────────────────┐ │
│                    ▼                       ▼                   ▼ │
│            ┌──────────────┐      ┌──────────────┐   ┌──────────┐│
│            │ Discard      │      │ Confirm      │   │ Retake   ││
│            │ (Return)     │      │ (Validate &  │   │ (Retry)  ││
│            │              │      │ Add to Queue)│   │          ││
│            └──────────────┘      └──────────────┘   └──────────┘│
│                                            │                     │
│                                            ▼                     │
│                                   ┌─────────────────┐            │
│                                   │ Photo Gallery   │            │
│                                   │ (Mixed Sources) │            │
│                                   └─────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

### Component Architecture

The feature is composed of four main components:

1. **CameraButton** - Entry point widget that triggers camera access
2. **CameraInterface** - Live camera preview and capture control
3. **PhotoPreview** - Confirmation interface for captured photo
4. **CameraService** - Business logic for permission handling, capture, and validation

### Integration Points

- **PhotoUploadInterface**: Existing component that displays file picker and new camera button
- **PhotoGallery**: Existing component that displays uploaded photos (both file-picker and captured)
- **ValidationService**: Existing service that validates file format, size, and dimensions
- **MalwareScanService**: Existing service that scans files for malicious content
- **UploadQueue**: Existing state management for photos pending upload

---

## Components and Interfaces

### 1. CameraButton Widget

**Responsibility**: Render camera button and handle initial click event

**Properties**:
- `onCameraClick`: Callback when button is clicked
- `isDisabled`: Boolean indicating if camera is unavailable
- `disabledReason`: String explaining why camera is disabled (if applicable)

**Behavior**:
- Displays camera icon with label "Take Photo" or similar
- Disabled state when device lacks camera capability or browser doesn't support getUserMedia
- Shows tooltip on hover explaining disabled reason
- Minimum 48×48 logical pixels for touch target
- ARIA label: "Take a photo with your device camera"

### 2. CameraInterface Widget

**Responsibility**: Display live camera preview and capture controls

**Properties**:
- `onCapture`: Callback with captured image data
- `onCancel`: Callback when user cancels
- `onError`: Callback with error details

**Behavior**:
- Displays live video stream from device camera
- Provides "Capture" button (primary action)
- Provides "Cancel" button (secondary action)
- Adapts to portrait/landscape orientation
- Maintains camera stream during orientation changes
- Shows loading indicator while initializing camera
- Disables capture button during initialization

**Resource Management**:
- Acquires camera stream on mount via `getUserMedia()`
- Releases camera stream on unmount or cancel
- Stops all tracks on the MediaStream
- Handles permission errors gracefully

### 3. PhotoPreview Widget

**Responsibility**: Display captured photo and allow user confirmation or retry

**Properties**:
- `imageData`: Blob or base64 string of captured photo
- `onConfirm`: Callback when user confirms
- `onRetake`: Callback to return to camera
- `onDiscard`: Callback to return to upload interface

**Behavior**:
- Displays full-size preview of captured photo
- Provides "Confirm" button (primary action)
- Provides "Retake" button (secondary action)
- Provides "Discard" button (tertiary action)
- Shows loading indicator while processing/validating
- Displays validation errors if photo fails checks

### 4. CameraService (Business Logic)

**Responsibility**: Orchestrate camera access, capture, and validation

**Methods**:

```dart
// Check if device supports camera
Future<bool> isCameraSupported()

// Request camera permission
Future<PermissionStatus> requestCameraPermission()

// Get current permission status
Future<PermissionStatus> getCameraPermissionStatus()

// Capture photo from stream
Future<CapturedPhoto> capturePhoto(MediaStream stream)

// Validate captured photo
Future<ValidationResult> validatePhoto(CapturedPhoto photo)

// Process photo (convert format, resize if needed)
Future<ProcessedPhoto> processPhoto(CapturedPhoto photo)

// Release camera resources
Future<void> releaseCameraResources()
```

**State Management** (Riverpod):

```dart
// Provider for camera permission status
final cameraPermissionProvider = StateNotifierProvider<
  CameraPermissionNotifier,
  AsyncValue<PermissionStatus>
>((ref) => CameraPermissionNotifier());

// Provider for camera interface visibility
final cameraInterfaceVisibleProvider = StateProvider<bool>((ref) => false);

// Provider for captured photo
final capturedPhotoProvider = StateProvider<CapturedPhoto?>((ref) => null);

// Provider for camera initialization state
final cameraInitializingProvider = StateProvider<bool>((ref) => false);

// Provider for camera errors
final cameraErrorProvider = StateProvider<CameraError?>((ref) => null);
```

---

## Data Models

### CapturedPhoto

```dart
class CapturedPhoto {
  final Uint8List imageData;        // Raw image bytes
  final String mimeType;             // e.g., "image/jpeg"
  final DateTime capturedAt;         // Timestamp
  final int width;                   // Image width in pixels
  final int height;                  // Image height in pixels
  final int fileSizeBytes;           // File size in bytes
  
  CapturedPhoto({
    required this.imageData,
    required this.mimeType,
    required this.capturedAt,
    required this.width,
    required this.height,
    required this.fileSizeBytes,
  });
}
```

### PermissionStatus

```dart
enum PermissionStatus {
  granted,           // User granted permission
  denied,            // User denied permission
  deniedForever,     // User denied and won't ask again
  notDetermined,     // Not yet requested
  restricted,        // Restricted by system (e.g., parental controls)
  provisional,       // iOS provisional permission
}
```

### CameraError

```dart
class CameraError {
  final CameraErrorType type;
  final String message;
  final String? details;
  final StackTrace? stackTrace;
  
  CameraError({
    required this.type,
    required this.message,
    this.details,
    this.stackTrace,
  });
}

enum CameraErrorType {
  notSupported,           // Browser/device doesn't support camera
  permissionDenied,       // User denied permission
  permissionDeniedForever,// User denied and won't ask again
  hardwareError,          // Camera hardware error
  streamError,            // Error accessing camera stream
  captureError,           // Error capturing frame
  processingError,        // Error processing captured image
  validationError,        // Validation failed
  unknown,                // Unknown error
}
```

### ValidationResult

```dart
class ValidationResult {
  final bool isValid;
  final List<ValidationError> errors;
  
  ValidationResult({
    required this.isValid,
    this.errors = const [],
  });
}

class ValidationError {
  final ValidationType type;
  final String message;
  
  ValidationError({
    required this.type,
    required this.message,
  });
}

enum ValidationType {
  invalidFormat,      // File format not supported
  fileTooLarge,       // File exceeds size limit
  imageTooSmall,      // Image dimensions too small
  imageTooLarge,      // Image dimensions too large
  malwareDetected,    // Malware scan failed
}
```

### ProcessedPhoto

```dart
class ProcessedPhoto {
  final Uint8List imageData;        // Processed image bytes
  final String mimeType;             // Final format (JPEG or PNG)
  final int width;                   // Final width
  final int height;                  // Final height
  final int fileSizeBytes;           // Final file size
  final DateTime processedAt;        // Processing timestamp
  
  ProcessedPhoto({
    required this.imageData,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.fileSizeBytes,
    required this.processedAt,
  });
}
```

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Camera Button Disabled When Unsupported

*For any* device configuration, if the device lacks camera capability or the browser does not support `getUserMedia`, the Camera Button SHALL be disabled and not clickable.

**Validates: Requirements 1.5, 8.5**

### Property 2: Permission Caching

*For any* user session, if camera permission has been granted once, subsequent camera button clicks SHALL open the camera interface immediately without requesting permission again.

**Validates: Requirements 2.5**

### Property 3: Captured Photo Format Consistency

*For any* captured photo, the resulting image SHALL be in JPEG or PNG format, matching the same format requirements as photos selected via the file picker.

**Validates: Requirements 4.2, 6.2**

### Property 4: Validation Consistency

*For any* photo (captured or file-picked), the validation rules applied (file size, format, dimensions) SHALL be identical regardless of source.

**Validates: Requirements 6.2, 11.1, 11.2, 11.3**

### Property 5: Camera Stream Cleanup

*For any* camera session, when the camera interface is closed or the user navigates away, all camera resources (MediaStream tracks) SHALL be properly released and the camera stream SHALL stop.

**Validates: Requirements 9.1, 9.2**

### Property 6: Cross-Platform Compatibility

*For any* supported browser (Chrome, Firefox, Safari, Edge on desktop; iOS Safari, Android Chrome on mobile), the camera capture feature SHALL function correctly and capture valid images.

**Validates: Requirements 8.1, 8.2**

### Property 7: Orientation Adaptation

*For any* device orientation change (portrait to landscape or vice versa), the camera interface SHALL adapt appropriately and the camera stream SHALL continue without interruption.

**Validates: Requirements 8.3, 8.4**

### Property 8: Photo Gallery Integration

*For any* captured photo added to the upload queue, it SHALL appear in the photo gallery alongside file-picker photos and be removable using the same mechanism.

**Validates: Requirements 6.3, 6.4, 6.5**

### Property 9: Captured Photo Immutability

*For any* captured photo, once confirmed and added to the upload queue, the image data SHALL not be modified or corrupted during storage or transmission.

**Validates: Requirements 4.5, 6.1**

### Property 10: Error Recovery

*For any* error condition (permission denied, hardware failure, capture failure, validation failure), the system SHALL display a user-friendly error message and provide a path to retry or use the file picker alternative.

**Validates: Requirements 7.1, 7.2, 7.3, 7.4**

### Property 11: Accessibility Compliance

*For any* interactive element in the camera feature (buttons, preview), it SHALL have appropriate ARIA labels, be keyboard accessible, and be navigable using keyboard controls.

**Validates: Requirements 10.1, 10.2, 10.3, 10.4, 10.5**

### Property 12: Loading State Feedback

*For any* async operation (camera initialization, photo processing, upload), the system SHALL display a loading indicator and disable relevant buttons to prevent multiple concurrent operations.

**Validates: Requirements 12.1, 12.2, 12.3, 12.4**

---

## Error Handling

### Error Scenarios and Responses

| Scenario | Error Type | User Message | Recovery Path |
|----------|-----------|--------------|----------------|
| Device lacks camera | `notSupported` | "Your device doesn't have a camera. Use the file picker to upload photos." | Disable camera button, show file picker |
| Permission denied | `permissionDenied` | "Camera access was denied. Please enable camera permissions in your browser settings to use this feature." | Retry button, file picker fallback |
| Permission denied forever | `permissionDeniedForever` | "Camera access is permanently denied. Please reset permissions in your browser settings or use the file picker." | File picker fallback |
| Hardware error | `hardwareError` | "Camera hardware error. Please check your device and try again." | Retry button, file picker fallback |
| Stream error | `streamError` | "Failed to access camera. Please try again." | Retry button, file picker fallback |
| Capture error | `captureError` | "Failed to capture photo. Please try again." | Retry button |
| Processing error | `processingError` | "Failed to process photo. Please try again." | Retry button |
| Validation error | `validationError` | "Photo doesn't meet requirements: [specific error]. Please retake." | Retake button |
| File too large | `fileTooLarge` | "Photo is too large (max 10MB). Please retake." | Retake button |
| Image too small | `imageTooSmall` | "Photo resolution is too low (min 640×480). Please retake." | Retake button |
| Image too large | `imageTooLarge` | "Photo resolution is too high (max 4096×4096). Please retake." | Retake button |
| Malware detected | `malwareDetected` | "Photo failed security scan. Please use a different photo." | Retake button |

### Error Logging

All errors SHALL be logged with:
- Error type and message
- User ID and session ID
- Device/browser information
- Timestamp
- Stack trace (if applicable)
- User action that triggered the error

Example log entry:
```
{
  "timestamp": "2026-03-15T10:30:45Z",
  "level": "ERROR",
  "feature": "camera-photo-upload",
  "errorType": "permissionDenied",
  "message": "User denied camera permission",
  "userId": "user-123",
  "sessionId": "session-456",
  "browser": "Chrome 120.0",
  "device": "iPhone 14",
  "userAction": "clicked camera button"
}
```

---

## Testing Strategy

### Dual Testing Approach

This feature requires both unit tests and property-based tests for comprehensive coverage:

- **Unit Tests**: Verify specific examples, edge cases, error conditions, and UI interactions
- **Property Tests**: Verify universal properties that hold across all inputs and scenarios

### Unit Testing

**Test Categories**:

1. **Permission Handling**
   - Permission granted → camera opens
   - Permission denied → error message shown
   - Permission denied forever → file picker fallback
   - Permission already granted → no re-request

2. **Camera Capture**
   - Capture button click → image captured
   - Cancel button click → camera closes without capture
   - Orientation change → camera stream continues
   - Navigation away → resources released

3. **Photo Validation**
   - Valid JPEG → passes validation
   - Valid PNG → passes validation
   - Invalid format → validation error
   - File too large → validation error
   - Image too small → validation error
   - Image too large → validation error

4. **Photo Preview**
   - Confirm → photo added to queue
   - Retake → returns to camera
   - Discard → returns to upload interface

5. **Integration**
   - Captured photo appears in gallery
   - Captured and file-picker photos coexist
   - Captured photo removable like file-picker photo

6. **Accessibility**
   - Camera button has ARIA label
   - Buttons keyboard accessible
   - Error messages announced to screen readers

7. **Error Handling**
   - Hardware error → retry option shown
   - Stream error → retry option shown
   - Processing error → retry option shown

### Property-Based Testing

**Property Test Configuration**:
- Minimum 100 iterations per property test
- Each test references its design document property
- Tag format: `Feature: camera-photo-upload, Property {number}: {property_text}`

**Properties to Test**:

1. **Property 1: Camera Button Disabled When Unsupported**
   - Generate random device configurations
   - Verify button disabled when camera unsupported
   - Tag: `Feature: camera-photo-upload, Property 1: Camera Button Disabled When Unsupported`

2. **Property 2: Permission Caching**
   - Grant permission, click button multiple times
   - Verify permission only requested once
   - Tag: `Feature: camera-photo-upload, Property 2: Permission Caching`

3. **Property 3: Captured Photo Format Consistency**
   - Capture random photos
   - Verify all are JPEG or PNG
   - Tag: `Feature: camera-photo-upload, Property 3: Captured Photo Format Consistency`

4. **Property 4: Validation Consistency**
   - Generate random photos (captured and file-picked)
   - Apply validation to both
   - Verify identical validation rules applied
   - Tag: `Feature: camera-photo-upload, Property 4: Validation Consistency`

5. **Property 5: Camera Stream Cleanup**
   - Open camera, close interface
   - Verify all MediaStream tracks stopped
   - Tag: `Feature: camera-photo-upload, Property 5: Camera Stream Cleanup`

6. **Property 6: Cross-Platform Compatibility**
   - Test on multiple browser environments
   - Verify camera works on all supported platforms
   - Tag: `Feature: camera-photo-upload, Property 6: Cross-Platform Compatibility`

7. **Property 7: Orientation Adaptation**
   - Simulate orientation changes
   - Verify interface adapts and stream continues
   - Tag: `Feature: camera-photo-upload, Property 7: Orientation Adaptation`

8. **Property 8: Photo Gallery Integration**
   - Add captured photos to queue
   - Verify they appear in gallery with file-picker photos
   - Tag: `Feature: camera-photo-upload, Property 8: Photo Gallery Integration`

9. **Property 9: Captured Photo Immutability**
   - Capture photo, add to queue
   - Verify image data unchanged during storage
   - Tag: `Feature: camera-photo-upload, Property 9: Captured Photo Immutability`

10. **Property 10: Error Recovery**
    - Simulate various error conditions
    - Verify error message shown and recovery path available
    - Tag: `Feature: camera-photo-upload, Property 10: Error Recovery`

11. **Property 11: Accessibility Compliance**
    - Verify ARIA labels on all buttons
    - Test keyboard navigation
    - Verify screen reader announcements
    - Tag: `Feature: camera-photo-upload, Property 11: Accessibility Compliance`

12. **Property 12: Loading State Feedback**
    - Trigger async operations
    - Verify loading indicators shown
    - Verify buttons disabled during operations
    - Tag: `Feature: camera-photo-upload, Property 12: Loading State Feedback`

### Test Organization

```
frontend/test/
├── features/
│   └── submission/
│       └── camera_photo_upload/
│           ├── camera_button_test.dart
│           ├── camera_interface_test.dart
│           ├── photo_preview_test.dart
│           ├── camera_service_test.dart
│           └── properties/
│               ├── camera_button_properties.dart
│               ├── validation_consistency_properties.dart
│               ├── resource_cleanup_properties.dart
│               └── accessibility_properties.dart
```

### Test Execution

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/features/submission/camera_photo_upload/camera_button_test.dart

# Run property-based tests
flutter test test/features/submission/camera_photo_upload/properties/

# Run with coverage
flutter test --coverage
```

---

## Technology Stack Alignment

### Frontend (Flutter)

**State Management**: Riverpod with code generation
- Use `StateNotifierProvider` for camera permission state
- Use `StateProvider` for UI state (camera visible, loading, errors)
- Use `FutureProvider` for async operations (camera initialization, photo processing)

**Browser APIs**:
- `getUserMedia()` for camera access
- `Canvas API` for photo capture from video stream
- `Blob API` for image data handling
- `MediaStream API` for stream management

**Packages**:
- `image` (5.0.0+) - Image processing and format conversion
- `permission_handler` (11.4.0+) - Cross-platform permission handling
- `flutter_web_plugins` - Web-specific functionality

**Platform-Specific Considerations**:

*Web (Flutter Web)*:
- Use `dart:html` for DOM access
- Use `dart:js_interop` for JavaScript interop if needed
- Handle browser compatibility gracefully

*Mobile Web View*:
- iOS Safari: Full support for getUserMedia
- Android Chrome: Full support for getUserMedia
- Fallback to file picker for unsupported browsers

### Backend Integration

**No backend changes required** for camera capture itself. The captured photo is processed entirely on the client and integrated into the existing upload workflow:

1. Photo captured and validated on client
2. Photo added to upload queue (existing mechanism)
3. Photo uploaded via existing upload endpoint
4. Photo processed by existing validation and malware scanning services

---

## Implementation Notes

### Browser Compatibility

| Browser | Desktop | Mobile | Notes |
|---------|---------|--------|-------|
| Chrome | ✅ | ✅ | Full support |
| Firefox | ✅ | ✅ | Full support |
| Safari | ✅ | ✅ | Full support (iOS 14.5+) |
| Edge | ✅ | N/A | Full support |
| IE 11 | ❌ | N/A | Not supported |
| Opera | ✅ | ✅ | Full support |

### Performance Considerations

1. **Camera Initialization**: Typically 500-1500ms on mobile, 200-500ms on desktop
2. **Photo Capture**: <100ms (frame grab from canvas)
3. **Image Processing**: <500ms for typical 2-4MP images
4. **Memory Usage**: ~10-50MB for camera stream + captured image

### Security Considerations

1. **HTTPS Only**: Camera access requires secure context (HTTPS)
2. **User Consent**: Explicit permission required before camera access
3. **Validation**: All captured photos validated for format, size, dimensions
4. **Malware Scanning**: Captured photos scanned using existing service
5. **No Storage**: Captured photos not stored on device; only in memory until upload

### Accessibility Considerations

1. **Keyboard Navigation**: All buttons accessible via Tab key
2. **Screen Readers**: ARIA labels on all interactive elements
3. **Focus Management**: Focus moved to error messages when they appear
4. **Color Contrast**: All UI elements meet WCAG AA standards
5. **Touch Targets**: All buttons minimum 48×48 logical pixels

---

## Future Enhancements

1. **Photo Editing**: Allow crop/rotate before confirmation
2. **Multiple Captures**: Capture multiple photos in one session
3. **Flash Control**: Toggle flash on/off for devices that support it
4. **Camera Selection**: Choose front/back camera on devices with multiple cameras
5. **Photo Filters**: Apply basic filters (brightness, contrast, saturation)
6. **Batch Upload**: Upload multiple captured photos at once
7. **Offline Support**: Queue captured photos for upload when connection restored

