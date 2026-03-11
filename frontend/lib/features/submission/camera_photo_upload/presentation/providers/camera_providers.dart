import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/camera_service.dart';
import '../../domain/enums/camera_permission_status.dart';
import '../../domain/models/camera_error.dart';
import '../../domain/models/captured_photo.dart';

/// Provider for the [CameraService] singleton instance.
///
/// Provides a single [CameraService] for the entire app session,
/// ensuring consistent permission caching and resource management.
final cameraServiceProvider = Provider<CameraService>(
  (ref) => CameraService(),
);

/// Manages camera permission state with caching.
///
/// Wraps [CameraService.requestCameraPermission] and caches the
/// granted result so subsequent calls skip the browser prompt.
/// State is [AsyncValue<CameraPermissionStatus>] to represent
/// loading, success, and error states.
class CameraPermissionNotifier
    extends StateNotifier<AsyncValue<CameraPermissionStatus>> {
  final CameraService _cameraService;

  /// Whether permission has already been granted this session.
  bool _hasGrantedPermission = false;

  /// Creates a [CameraPermissionNotifier] backed by [cameraService].
  CameraPermissionNotifier(this._cameraService)
      : super(
          const AsyncValue.data(CameraPermissionStatus.notDetermined),
        );

  /// Requests camera permission from the user.
  ///
  /// If permission was already granted in this session, returns
  /// [CameraPermissionStatus.granted] immediately without re-prompting.
  /// Otherwise delegates to [CameraService.requestCameraPermission]
  /// and caches a successful grant.
  Future<CameraPermissionStatus> requestPermission() async {
    // Return cached grant to avoid re-prompting (Property 2).
    if (_hasGrantedPermission) {
      state = const AsyncValue.data(CameraPermissionStatus.granted);
      return CameraPermissionStatus.granted;
    }

    state = const AsyncValue.loading();

    try {
      final status = await _cameraService.requestCameraPermission();

      if (status == CameraPermissionStatus.granted) {
        _hasGrantedPermission = true;
      }

      state = AsyncValue.data(status);
      return status;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return CameraPermissionStatus.denied;
    }
  }
}

/// Provider for [CameraPermissionNotifier].
///
/// Exposes the permission state as [AsyncValue<CameraPermissionStatus>]
/// and provides [requestPermission] for triggering the permission flow.
final cameraPermissionProvider = StateNotifierProvider<
    CameraPermissionNotifier, AsyncValue<CameraPermissionStatus>>(
  (ref) {
    final cameraService = ref.watch(cameraServiceProvider);
    return CameraPermissionNotifier(cameraService);
  },
);

/// Provider for camera interface visibility.
///
/// `true` when the camera capture interface is shown to the user.
final cameraInterfaceVisibleProvider = StateProvider<bool>(
  (ref) => false,
);

/// Provider for camera initialization loading state.
///
/// `true` while the camera stream is being set up.
final cameraInitializingProvider = StateProvider<bool>(
  (ref) => false,
);

/// Provider for the currently captured photo awaiting confirmation.
///
/// `null` when no photo has been captured yet or after discard.
final capturedPhotoProvider = StateProvider<CapturedPhoto?>(
  (ref) => null,
);

/// Provider for the current camera error, if any.
///
/// `null` when there is no active error.
final cameraErrorProvider = StateProvider<CameraError?>(
  (ref) => null,
);
