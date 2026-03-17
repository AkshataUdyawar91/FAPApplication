import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/conversational_submission/presentation/pages/conversational_submission_page.dart';
import '../../features/conversational_submission/presentation/pages/my_submissions_page.dart';
import '../../features/submission/presentation/pages/agency_submission_detail_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isAuthenticated && !isLoggingIn) {
        return '/login';
      }

      if (isAuthenticated && isLoggingIn) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/conversational-submission',
        name: 'conversational-submission',
        builder: (context, state) => const ConversationalSubmissionPage(),
      ),
      GoRoute(
        path: '/my-submissions',
        name: 'my-submissions',
        builder: (context, state) => const MySubmissionsPage(),
      ),
      GoRoute(
        path: '/agency/submission-detail',
        name: 'submission-detail',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          final submissionId = args?['submissionId']?.toString() ?? '';
          final token = args?['token']?.toString() ?? '';
          final userName = args?['userName']?.toString() ?? '';

          return AgencySubmissionDetailPage(
            submissionId: submissionId,
            token: token,
            userName: userName,
          );
        },
      ),
    ],
  );
});

// Home page with navigation to conversational submission
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ClaimsIQ'),
        backgroundColor: const Color(0xFF003087),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.description_outlined,
                size: 72,
                color: Color(0xFF003087),
              ),
              const SizedBox(height: 16),
              const Text(
                'Welcome to ClaimsIQ',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003087),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Submit and manage your FAP claims',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 280,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/conversational-submission'),
                  icon: const Icon(Icons.add_comment),
                  label: const Text('New Submission'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003087),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 280,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/my-submissions'),
                  icon: const Icon(Icons.list_alt),
                  label: const Text('My Submissions'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF003087),
                    side: const BorderSide(color: Color(0xFF003087)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/conversational-submission'),
        backgroundColor: const Color(0xFF003087),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Claim'),
      ),
    );
  }
}
