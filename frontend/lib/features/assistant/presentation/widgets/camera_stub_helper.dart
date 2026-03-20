import 'dart:async';
import 'dart:typed_data';

/// Stub for non-web platforms — should not be called directly on mobile
/// (mobile uses ImagePicker instead).
Future<Uint8List?> captureFromWebCamera() async => null;
