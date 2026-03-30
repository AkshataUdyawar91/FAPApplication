import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../network/dio_client.dart';

/// Wrapper widget that fetches token and passes it to dashboard pages.
///
/// Uses the in-memory token from [AuthState] as the primary source and
/// falls back to secure storage. This ensures the app works even when
/// secure storage fails (common on web release builds).
class DashboardWrapper extends ConsumerWidget {
  final Widget Function(String token, String userName, VoidCallback onLogout) builder;

  const DashboardWrapper({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final localDataSource = ref.watch(authLocalDataSourceProvider);

    void onLogout() {
      ref.read(authNotifierProvider.notifier).logout();
      context.go('/login');
    }

    // Prefer in-memory token from AuthState (always available after login).
    final inMemoryToken = authState.token;
    if (inMemoryToken != null && inMemoryToken.isNotEmpty) {
      final userName = authState.user?.name ?? authState.user?.email ?? '';

      // Push the token into the shared provider so Dio picks it up.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(authTokenProvider.notifier).state = inMemoryToken;
      });

      return builder(inMemoryToken, userName, onLogout);
    }

    // Fallback: read from secure storage (covers page-refresh scenarios
    // where in-memory state is lost but storage still has the token).
    return FutureBuilder<String?>(
      future: localDataSource.getAccessToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final token = snapshot.data ?? '';
        final userName = authState.user?.name ?? authState.user?.email ?? '';

        if (token.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(authTokenProvider.notifier).state = token;
          });
        }

        if (kDebugMode) {
          print('[DashboardWrapper] Token source: secure storage, '
              'present: ${token.isNotEmpty}');
        }

        return builder(token, userName, onLogout);
      },
    );
  }
}
