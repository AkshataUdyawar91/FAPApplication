import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/conversational_submission/presentation/pages/conversational_submission_page.dart';
import '../../features/conversational_submission/presentation/pages/my_submissions_page.dart';
import '../../features/submission/presentation/pages/agency_submission_detail_page.dart';
import '../../features/submission/presentation/pages/agency_dashboard_page.dart';
import '../../features/submission/presentation/pages/agency_upload_page.dart';
import '../../features/approval/presentation/pages/asm_review_page.dart';
import '../../features/approval/presentation/pages/asm_review_detail_page.dart';
import '../../features/approval/presentation/pages/hq_review_page.dart';
import '../../features/approval/presentation/pages/hq_review_detail_page.dart';
import 'dashboard_wrapper.dart';
import '../../features/assistant/presentation/providers/assistant_providers.dart';
import '../network/dio_client.dart';

/// Helper function to handle logout with GoRouter
/// Call this instead of Navigator.pushReplacementNamed(context, '/')
void handleLogout(BuildContext context, WidgetRef ref) {
  // Clear assistant chat history on logout
  ref.read(assistantNotifierProvider.notifier).reset();
  // Clear auth token
  ref.read(authTokenProvider.notifier).state = null;
  // Logout from auth notifier
  ref.read(authNotifierProvider.notifier).logout();
  // Navigate to login page
  context.go('/login');
}

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
        // Redirect to role-specific dashboard
        final userRole = authState.user?.role.toLowerCase();
        print('[Router] User authenticated with role: $userRole');

        switch (userRole) {
          case 'agency':
            print('[Router] Redirecting to Agency dashboard: /home');
            return '/home';
          case 'asm':
            print('[Router] Redirecting to ASM dashboard: /asm/dashboard');
            return '/asm/dashboard';
          case 'ra':
            print('[Router] Redirecting to RA/HQ dashboard: /hq/dashboard');
            return '/hq/dashboard';
          default:
            print(
                '[Router] Unknown role, defaulting to Agency dashboard: /home');
            return '/home';
        }
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
        builder: (context, state) {
          return DashboardWrapper(
            builder: (token, userName) => AgencyDashboardPage(
              token: token,
              userName: userName,
            ),
          );
        },
      ),
      GoRoute(
        path: '/asm/dashboard',
        name: 'asm-dashboard',
        builder: (context, state) {
          return DashboardWrapper(
            builder: (token, userName) => ASMReviewPage(
              token: token,
              userName: userName,
            ),
          );
        },
      ),
      GoRoute(
        path: '/hq/dashboard',
        name: 'hq-dashboard',
        builder: (context, state) {
          return DashboardWrapper(
            builder: (token, userName) => HQReviewPage(
              token: token,
              userName: userName,
            ),
          );
        },
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
          final poNumber = args?['poNumber']?.toString() ?? '';

          return AgencySubmissionDetailPage(
            submissionId: submissionId,
            token: token,
            userName: userName,
            poNumber: poNumber,
          );
        },
      ),
      GoRoute(
        path: '/agency/upload',
        name: 'agency-upload',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          final token = args?['token']?.toString() ?? '';
          final userName = args?['userName']?.toString() ?? '';
          final submissionId = args?['submissionId']?.toString();

          return AgencyUploadPage(
            token: token,
            userName: userName,
            submissionId: submissionId,
          );
        },
      ),
      GoRoute(
        path: '/asm/review-detail',
        name: 'asm-review-detail',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          final submissionId = args?['submissionId']?.toString() ?? '';
          final token = args?['token']?.toString() ?? '';
          final userName = args?['userName']?.toString() ?? '';

          return ASMReviewDetailPage(
            submissionId: submissionId,
            token: token,
            userName: userName,
          );
        },
      ),
      GoRoute(
        path: '/hq/review-detail',
        name: 'hq-review-detail',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          final submissionId = args?['submissionId']?.toString() ?? '';
          final token = args?['token']?.toString() ?? '';
          final userName = args?['userName']?.toString() ?? '';

          return HQReviewDetailPage(
            submissionId: submissionId,
            token: token,
            userName: userName,
          );
        },
      ),
    ],
  );
});
