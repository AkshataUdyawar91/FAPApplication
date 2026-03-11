# Implementation Plan: Camera Photo Upload for Agency Submissions

## Overview

This implementation plan breaks down the camera photo upload feature into discrete, manageable tasks that build incrementally. The feature is implemented in Dart/Flutter following clean architecture principles with Riverpod for state management. Tasks are organized to enable parallel work where possible while maintaining clear dependencies.

## Tasks

- [x] 1. Set up project structure and core data models
  - Create feature directory structure under `lib/features/submission/camera_photo_upload/`
  - Define data models: `CapturedPhoto`, `PermissionStatus`, `CameraError`, `ValidationResult`, `ProcessedPhoto`
  - Create enums: `CameraErrorType`, `ValidationType`
  - Set up Riverpod providers file structure
  - _Requirements: 1.1, 4.1, 4.2_

- [ ] 2. Implement CameraService business logic
  - [x] 2.1 Create CameraService class with core methods
    - Implement `isCameraSupported()` - check browser/device camera capability
    - Implement `requestCameraPermission()` - request camera access
    - Implement `getCameraPermissionStatus()` - check current permission state
    - Implement `capturePhoto()` - capture frame from MediaStream
    - Implement `validatePhoto()` - validate format, size, dimensions
    - Implement `processPhoto()` - convert format, resize if needed
    - Implement `releaseCameraResources()` - cleanup MediaStream tracks
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 4.1, 4.2, 4.3, 4.4, 4.5, 9.1, 9.2, 9.3, 9.4, 9.5_

  - [ ]* 2.2 Write property test for camera support detection
    - **Property 1: Camera Button Disabled When Unsupported**
    - **Validates: Requirements 1.5, 8.5**

  - [ ]* 2.3 Write property test for permission caching
    - **Property 2: Permission Caching**
    - **Validates: Requirements 2.5**

  - [ ]* 2.4 Write property test for photo format consistency
    - **Property 3: Captured Photo Format Consistency**
    - **Validates: Requirements 4.2, 6.2**

  - [ ]* 2.5 Write property test for validation consistency
    - **Property 4: Validation Consistency**
    - **Validates: Requirements 6.2, 11.1, 11.2, 11.3**

  - [ ]* 2.6 Write property test for camera stream cleanup
    - **Property 5: Camera Stream Cleanup**
    - **Validates: Requirements 9.1, 9.2**

- [ ] 3. Implement Riverpod state management providers
  - [x] 3.1 Create camera permission state notifier
    - Implement `CameraPermissionNotifier` extending `StateNotifier<AsyncValue<PermissionStatus>>`
    - Handle permission request and caching logic
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [x] 3.2 Create camera UI state providers
    - Implement `cameraInterfaceVisibleProvider` - StateProvider for camera interface visibility
    - Implement `cameraInitializingProvider` - StateProvider for initialization loading state
    - Implement `cameraErrorProvider` - StateProvider for error state
    - Implement `capturedPhotoProvider` - StateProvider for captured photo data
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 12.1, 12.2, 12.3, 12.4_

  - [ ]* 3.3 Write unit tests for state notifiers
    - Test permission state transitions
    - Test error state handling
    - Test photo state management
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

- [ ] 4. Implement CameraButton widget
  - [x] 4.1 Create CameraButton widget
    - Display camera icon with "Take Photo" label
    - Implement disabled state when camera unsupported
    - Show tooltip explaining disabled reason
    - Ensure minimum 48×48 logical pixel touch target
    - Add ARIA label: "Take a photo with your device camera"
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 10.1_

  - [x] 4.2 Integrate CameraButton with permission flow
    - Connect button click to permission request
    - Handle permission granted → open camera interface
    - Handle permission denied → show error message
    - Handle permission denied forever → show file picker fallback
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 7.1, 7.2, 7.3, 7.4_

  - [ ]* 4.3 Write unit tests for CameraButton
    - Test button renders correctly
    - Test disabled state when camera unsupported
    - Test click handler triggers permission request
    - Test ARIA labels present
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 10.1_

- [ ] 5. Implement CameraInterface widget
  - [x] 5.1 Create CameraInterface widget with live preview
    - Implement `getUserMedia()` call to access camera stream
    - Display live video stream in `<video>` element
    - Implement loading indicator during initialization
    - Disable capture button during initialization
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 12.1, 12.2_

  - [x] 5.2 Implement capture and cancel controls
    - Add "Capture" button (primary action)
    - Add "Cancel" button (secondary action)
    - Implement capture button click → call `capturePhoto()`
    - Implement cancel button click → release resources and close interface
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 9.1, 9.2_

  - [x] 5.3 Implement orientation adaptation
    - Handle portrait/landscape orientation changes
    - Maintain camera stream during orientation changes
    - Adapt UI layout to orientation
    - _Requirements: 8.3, 8.4_

  - [x] 5.4 Implement resource cleanup
    - Stop all MediaStream tracks on unmount
    - Stop all MediaStream tracks on cancel
    - Handle navigation away gracefully
    - _Requirements: 9.1, 9.2_

  - [ ]* 5.5 Write unit tests for CameraInterface
    - Test camera stream initialization
    - Test capture button functionality
    - Test cancel button functionality
    - Test orientation change handling
    - Test resource cleanup on unmount
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 8.3, 8.4, 9.1, 9.2_

  - [ ]* 5.6 Write property test for cross-platform compatibility
    - **Property 6: Cross-Platform Compatibility**
    - **Validates: Requirements 8.1, 8.2**

  - [ ]* 5.7 Write property test for orientation adaptation
    - **Property 7: Orientation Adaptation**
    - **Validates: Requirements 8.3, 8.4**

- [ ] 6. Implement PhotoPreview widget
  - [x] 6.1 Create PhotoPreview widget
    - Display full-size preview of captured photo
    - Add "Confirm" button (primary action)
    - Add "Retake" button (secondary action)
    - Add "Discard" button (tertiary action)
    - Show loading indicator while processing/validating
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

  - [x] 6.2 Implement preview actions
    - Confirm button → validate photo and add to upload queue
    - Retake button → return to camera interface
    - Discard button → return to upload interface
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 6.1, 6.2, 6.3, 6.4, 6.5_

  - [x] 6.3 Implement validation error display
    - Display validation errors if photo fails checks
    - Show specific error message (format, size, dimensions)
    - Provide retry/retake option
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 11.1, 11.2, 11.3_

  - [ ]* 6.4 Write unit tests for PhotoPreview
    - Test preview renders correctly
    - Test confirm button adds photo to queue
    - Test retake button returns to camera
    - Test discard button returns to upload interface
    - Test validation error display
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 6.1, 6.2, 6.3, 6.4, 6.5_

- [ ] 7. Implement photo validation and processing
  - [x] 7.1 Create validation logic
    - Validate file format (JPEG, PNG)
    - Validate file size (max 10MB)
    - Validate image dimensions (min 640×480, max 4096×4096)
    - Return structured validation errors
    - _Requirements: 11.1, 11.2, 11.3_

  - [x] 7.2 Implement photo processing
    - Convert captured photo to JPEG or PNG format
    - Resize if dimensions exceed limits
    - Compress to meet file size requirements
    - Preserve image quality
    - _Requirements: 4.2, 4.3, 4.4, 4.5_

  - [x] 7.3 Integrate with existing malware scanning
    - Call existing `MalwareScanService` for captured photos
    - Handle scan results (pass/fail)
    - Display malware detection error if scan fails
    - _Requirements: 11.1, 11.5_

  - [ ]* 7.4 Write unit tests for validation and processing
    - Test valid JPEG passes validation
    - Test valid PNG passes validation
    - Test invalid format fails validation
    - Test file too large fails validation
    - Test image too small fails validation
    - Test image too large fails validation
    - Test photo processing converts format correctly
    - Test photo processing resizes correctly
    - _Requirements: 11.1, 11.2, 11.3, 4.2, 4.3, 4.4, 4.5_

- [ ] 8. Implement error handling and logging
  - [x] 8.1 Create error handling strategy
    - Map error types to user-friendly messages
    - Implement error recovery paths (retry, fallback to file picker)
    - Log errors with context (user ID, session ID, device info)
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

  - [x] 8.2 Implement error display UI
    - Show error messages in modal or inline
    - Provide retry button for transient errors
    - Provide file picker fallback for unsupported devices
    - Ensure error messages are accessible (announced to screen readers)
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 10.5_

  - [ ]* 8.3 Write unit tests for error handling
    - Test permission denied error handling
    - Test hardware error handling
    - Test stream error handling
    - Test capture error handling
    - Test processing error handling
    - Test validation error handling
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

  - [ ]* 8.4 Write property test for error recovery
    - **Property 10: Error Recovery**
    - **Validates: Requirements 7.1, 7.2, 7.3, 7.4**

- [ ] 9. Implement accessibility features
  - [x] 9.1 Add ARIA labels and semantic HTML
    - Add ARIA labels to all buttons (camera, capture, cancel, retake, discard, confirm)
    - Use semantic HTML elements (button, not div)
    - Add role attributes where needed
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

  - [x] 9.2 Implement keyboard navigation
    - All buttons accessible via Tab key
    - Enter/Space to activate buttons
    - Escape to close camera interface
    - Focus management for error messages
    - _Requirements: 10.2, 10.3_

  - [x] 9.3 Implement screen reader support
    - Announce error messages to screen readers
    - Provide descriptive labels for all interactive elements
    - Announce loading states
    - Announce photo capture success
    - _Requirements: 10.4, 10.5_

  - [ ]* 9.4 Write unit tests for accessibility
    - Test ARIA labels present on all buttons
    - Test keyboard navigation works
    - Test error messages announced to screen readers
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

  - [ ]* 9.5 Write property test for accessibility compliance
    - **Property 11: Accessibility Compliance**
    - **Validates: Requirements 10.1, 10.2, 10.3, 10.4, 10.5**

- [ ] 10. Implement integration with existing upload workflow
  - [x] 10.1 Integrate captured photo with upload queue
    - Add captured photo to existing `uploadQueueProvider`
    - Ensure captured photo appears in photo gallery
    - Ensure captured photo removable like file-picker photos
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

  - [x] 10.2 Ensure validation consistency
    - Apply same validation rules to captured and file-picker photos
    - Use same validation service for both sources
    - Display consistent error messages
    - _Requirements: 6.2, 11.1, 11.2, 11.3_

  - [x] 10.3 Ensure malware scanning consistency
    - Scan captured photos with same service as file-picker photos
    - Handle scan results consistently
    - Display consistent error messages
    - _Requirements: 11.1, 11.5_

  - [ ]* 10.4 Write integration tests
    - Test captured photo appears in gallery
    - Test captured and file-picker photos coexist
    - Test captured photo removable
    - Test validation applied consistently
    - Test malware scanning applied consistently
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 11.1, 11.2, 11.3, 11.5_

  - [ ]* 10.5 Write property test for photo gallery integration
    - **Property 8: Photo Gallery Integration**
    - **Validates: Requirements 6.3, 6.4, 6.5**

- [ ] 11. Implement loading state feedback
  - [x] 11.1 Add loading indicators
    - Show loading indicator while initializing camera
    - Show loading indicator while processing photo
    - Show loading indicator while validating photo
    - Show loading indicator while uploading photo
    - _Requirements: 12.1, 12.2, 12.3, 12.4_

  - [x] 11.2 Implement button state management
    - Disable camera button during initialization
    - Disable capture button during initialization
    - Disable confirm button during processing/validation
    - Disable confirm button during upload
    - _Requirements: 12.1, 12.2, 12.3, 12.4_

  - [x] 11.3 Implement success feedback
    - Show success message after photo added to queue
    - Show success message after upload completes
    - Provide visual confirmation of state changes
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_

  - [ ]* 11.4 Write unit tests for loading states
    - Test loading indicator shown during initialization
    - Test loading indicator shown during processing
    - Test buttons disabled during operations
    - Test success feedback shown
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_

  - [ ]* 11.5 Write property test for loading state feedback
    - **Property 12: Loading State Feedback**
    - **Validates: Requirements 12.1, 12.2, 12.3, 12.4**

- [ ] 12. Implement photo immutability and security
  - [x] 12.1 Ensure photo immutability
    - Verify image data not modified after capture
    - Verify image data not corrupted during storage
    - Verify image data not corrupted during transmission
    - _Requirements: 4.5, 6.1_

  - [x] 12.2 Implement security validation
    - Validate file format by magic bytes (not just extension)
    - Enforce file size limits at service layer
    - Validate image dimensions
    - Scan for malicious content
    - _Requirements: 11.1, 11.2, 11.3, 11.5_

  - [ ]* 12.3 Write unit tests for security
    - Test file format validation by magic bytes
    - Test file size enforcement
    - Test image dimension validation
    - Test malware scanning integration
    - _Requirements: 11.1, 11.2, 11.3, 11.5_

  - [ ]* 12.4 Write property test for photo immutability
    - **Property 9: Captured Photo Immutability**
    - **Validates: Requirements 4.5, 6.1**

- [ ] 13. Checkpoint - Ensure all unit and property tests pass
  - Run all unit tests: `flutter test test/features/submission/camera_photo_upload/`
  - Run all property tests: `flutter test test/features/submission/camera_photo_upload/properties/`
  - Verify code coverage >80%
  - Fix any failing tests
  - Ensure all tests pass before proceeding
  - _Requirements: All_

- [ ] 14. Cross-browser and platform testing
  - [ ] 14.1 Test on desktop browsers
    - Test on Chrome (latest)
    - Test on Firefox (latest)
    - Test on Safari (latest)
    - Test on Edge (latest)
    - Verify camera capture works on all browsers
    - _Requirements: 8.1, 8.2_

  - [ ] 14.2 Test on mobile web views
    - Test on iOS Safari (iPhone)
    - Test on Android Chrome (Android phone)
    - Verify camera capture works on mobile
    - Verify orientation changes handled correctly
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

  - [ ] 14.3 Test on devices without camera
    - Verify camera button disabled
    - Verify file picker fallback available
    - Verify error message shown
    - _Requirements: 1.5, 8.5, 7.1_

  - [ ]* 14.4 Write integration tests for cross-platform scenarios
    - Test camera works on multiple browsers
    - Test orientation changes on mobile
    - Test fallback on unsupported devices
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [ ] 15. Accessibility compliance testing
  - [ ] 15.1 Test keyboard navigation
    - Tab through all interactive elements
    - Verify focus order is logical
    - Verify Escape closes camera interface
    - _Requirements: 10.2, 10.3_

  - [ ] 15.2 Test screen reader support
    - Test with NVDA (Windows)
    - Test with JAWS (Windows)
    - Test with VoiceOver (macOS/iOS)
    - Verify all elements announced correctly
    - _Requirements: 10.4, 10.5_

  - [ ] 15.3 Test color contrast and touch targets
    - Verify all UI elements meet WCAG AA contrast ratios
    - Verify all buttons minimum 48×48 logical pixels
    - _Requirements: 1.4, 10.1_

  - [ ]* 15.4 Write accessibility compliance tests
    - Test ARIA labels on all buttons
    - Test keyboard navigation
    - Test screen reader announcements
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

- [ ] 16. Performance optimization and testing
  - [ ] 16.1 Optimize camera initialization
    - Profile camera initialization time
    - Target <1500ms on mobile, <500ms on desktop
    - Optimize permission request flow
    - _Requirements: 9.3, 9.4_

  - [ ] 16.2 Optimize photo capture and processing
    - Profile photo capture time
    - Target <100ms for frame capture
    - Target <500ms for image processing
    - _Requirements: 9.3, 9.4_

  - [ ] 16.3 Optimize memory usage
    - Profile memory usage during camera session
    - Target <50MB for camera stream + captured image
    - Ensure proper cleanup to prevent memory leaks
    - _Requirements: 9.3, 9.4, 9.5_

  - [ ]* 16.4 Write performance tests
    - Test camera initialization time
    - Test photo capture time
    - Test memory usage
    - _Requirements: 9.3, 9.4, 9.5_

- [ ] 17. Final checkpoint - Ensure all tests pass and feature complete
  - Run all tests: `flutter test`
  - Verify code coverage >80%
  - Verify no analyzer warnings: `flutter analyze`
  - Verify code formatted: `dart format .`
  - Verify all requirements met
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- Integration tests verify cross-component functionality
- Checkpoints ensure incremental validation
- All code must follow Flutter best practices from `flutter-guidelines-new.md`
- All state management must use Riverpod with code generation
- All UI components must be accessible (WCAG AA)
- All async operations must use proper error handling and loading states
