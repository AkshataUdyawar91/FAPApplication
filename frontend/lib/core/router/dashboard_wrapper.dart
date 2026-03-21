import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../network/dio_client.dart';

/// Wrapper widget that fetches token and passes it to dashboard pages
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

        // Set the shared auth token once here so every widget using
        // dioProvider (AssistantChatPanel, ChatPage, etc.) automatically
        // gets the Bearer header — no per-page token wiring needed.
        if (token.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(authTokenProvider.notifier).state = token;
          });
        }

        print(
            '[DashboardWrapper] Token retrieved: ${token.isNotEmpty ? "${token.substring(0, 20)}..." : "EMPTY"}');
        print('[DashboardWrapper] UserName: $userName');
        print('[DashboardWrapper] User role: ${authState.user?.role}');

        return builder(token, userName, onLogout);
      },
    );
  }
}
