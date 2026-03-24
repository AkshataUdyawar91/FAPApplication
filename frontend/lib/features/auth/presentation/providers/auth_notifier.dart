import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';

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

  AuthNotifier({
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.authRepository,
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
      },
    );
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

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

  /// Get the Azure AD SSO authorization URL
  Future<String?> getSsoAuthorizeUrl(String redirectUri) async {
    final result = await authRepository.getSsoAuthorizeUrl(redirectUri);
    return result.fold(
      (failure) {
        state = state.copyWith(error: failure.message);
        return null;
      },
      (url) => url,
    );
  }

  /// Complete SSO login by exchanging the authorization code
  Future<void> ssoLogin(String code, String redirectUri) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await authRepository.ssoLogin(code, redirectUri);

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
      },
    );
  }
}
