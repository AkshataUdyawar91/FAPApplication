/// Permission states for camera access.
enum CameraPermissionStatus {
  /// User has granted camera permission.
  granted,

  /// User has denied camera permission.
  denied,

  /// User has permanently denied camera permission.
  deniedForever,

  /// Permission has not been requested yet.
  notDetermined,

  /// Permission is restricted by the system (e.g., parental controls).
  restricted,
}
