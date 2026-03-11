/// Error types that can occur during camera operations.
enum CameraErrorType {
  /// Browser or device does not support camera access.
  notSupported,

  /// User denied camera permission.
  permissionDenied,

  /// User denied camera permission permanently.
  permissionDeniedForever,

  /// Camera hardware error.
  hardwareError,

  /// Error accessing camera stream.
  streamError,

  /// Error capturing frame from camera.
  captureError,

  /// Error processing captured image.
  processingError,

  /// Captured photo failed validation.
  validationError,

  /// Unknown or unexpected error.
  unknown,
}
