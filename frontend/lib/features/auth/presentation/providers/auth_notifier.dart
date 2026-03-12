import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../../notifications/domain/repositories/notification_repository.dart';
import '../../../notifications/domain/usecases/deregister_device_token_usecase.dart';
import '../../../notifications/domain/usecases/register_device_token_usecase.dart';
import '../../../notifications/presentation/services/push_notification_service.dart';

/// Authentication state
class AuthState extends Equatable {
  final User? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }

  @override
  List<Object?> get props => [user, isLoading, error, isAuthenticated];
}

/// Authentication state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final LoginUseCase loginUseCase;
  final LogoutUseCase logoutUseCase;
  final AuthRepository authRepository;
  final RegisterDeviceTokenUseCase registerDeviceTokenUseCase;
  final DeregisterDeviceTokenUseCase deregisterDeviceTokenUseCase;
  final PushNotificationService pushNotificationService;
  final NotificationRepository notificationRepository;

  AuthNotifier({
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.authRepository,
    required this.registerDeviceTokenUseCase,
    required this.deregisterDeviceTokenUseCase,
    required this.pushNotificationService,
    required this.notificationRepository,
  }) : super(const AuthState()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final result = await authRepository.getCurrentUser();
    result.fold(
      (failure) => state = state.copyWith(isAuthenticated: false),
      (user) {
        if (user != null) {
          state = state.copyWith(
            user: user,
            isAuthenticated: true,
          );
        }
      },
    );
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await loginUseCase(email, password);

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
          isAuthenticated: false,
        );
      },
      (user) {
        state = state.copyWith(
          user: user,
          isLoading: false,
          error: null,
          isAuthenticated: true,
        );
        // Register device token after successful login (fire-and-forget)
        _registerDeviceToken();
      },
    );
  }

  /// Register device token for push notifications.
  /// Errors are handled gracefully — registration failure does not block login.
  Future<void> _registerDeviceToken() async {
    try {
      final token = await pushNotificationService.getToken();
      if (token == null) return;

      final platform = pushNotificationService.getPlatform();
      await registerDeviceTokenUseCase(token, platform);
    } catch (_) {
      // Device token registration is non-blocking — log and continue
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

    // Deregister device token before clearing auth state (non-blocking)
    await _deregisterDeviceToken();

    final result = await logoutUseCase();

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (_) {
        state = const AuthState(isAuthenticated: false);
      },
    );
  }

  /// Deregister device token on logout.
  /// Errors are handled gracefully — cleanup failure does not block logout.
  Future<void> _deregisterDeviceToken() async {
    try {
      final tokenId = await notificationRepository.getStoredDeviceTokenId();
      if (tokenId == null) return;

      await deregisterDeviceTokenUseCase(tokenId);
    } catch (_) {
      // Device token cleanup is non-blocking — continue with logout
    }
  }
}
