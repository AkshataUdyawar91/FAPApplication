/// Types of validation errors for captured photos.
enum ValidationType {
  /// File format is not supported (not JPEG or PNG).
  invalidFormat,

  /// File size exceeds the maximum limit (10MB).
  fileTooLarge,

  /// Image dimensions are below the minimum (640×480).
  imageTooSmall,

  /// Image dimensions exceed the maximum (4096×4096).
  imageTooLarge,

  /// Malware or malicious content detected.
  malwareDetected,
}
