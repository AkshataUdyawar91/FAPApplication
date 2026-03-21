import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../network/dio_client.dart';

/// Wrapper widget that fetches token and passes it to dashboard pages
class DashboardWrapper extends ConsumerWidget {
  final Widget Function(String token, String userName) builder;

  const DashboardWrapper({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final localDataSource = ref.watch(authLocalDataSourceProvider);

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

        print(
            '[DashboardWrapper] Token retrieved: ${token.isNotEmpty ? "${token.substring(0, 20)}..." : "EMPTY"}');
        print('[DashboardWrapper] UserName: $userName');
        print('[DashboardWrapper] User role: ${authState.user?.role}');

        // Ensure authTokenProvider is always in sync with the persisted token
        if (token.isNotEmpty) {
          final currentProviderToken = ref.read(authTokenProvider);
          if (currentProviderToken != token) {
            Future.microtask(() {
              ref.read(authTokenProvider.notifier).state = token;
            });
          }
        }

        return builder(token, userName);
      },
    );
  }
}
