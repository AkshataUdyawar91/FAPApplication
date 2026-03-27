import 'package:bajaj_document_processing/features/submission/presentation/pages/new_agency_upload_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/sso_callback_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/conversational_submission/presentation/pages/conversational_submission_page.dart';
import '../../features/conversational_submission/presentation/pages/my_submissions_page.dart';
import '../../features/submission/presentation/pages/agency_submission_detail_page.dart';
import '../../features/submission/presentation/pages/agency_dashboard_page.dart';
import '../../features/approval/presentation/pages/asm_review_page.dart';
import '../../features/approval/presentation/pages/asm_review_detail_page.dart';
import '../../features/approval/presentation/pages/hq_review_page.dart';
import '../../features/approval/presentation/pages/hq_review_detail_page.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
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

/// A [ChangeNotifier] that bridges Riverpod's [AuthState] to GoRouter's
/// [refreshListenable]. This lets the router re-evaluate its redirect
/// without being recreated from scratch — critical for release-mode web.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen<AuthState>(authNotifierProvider, (_, __) {
      notifyListeners();
    });
  }
}

/// Provides a stable [_AuthChangeNotifier] that GoRouter can listen to.
final _authChangeNotifierProvider = Provider<_AuthChangeNotifier>((ref) {
  return _AuthChangeNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final authChangeNotifier = ref.watch(_authChangeNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authChangeNotifier,
    redirect: (context, state) {
      // Read (not watch) — the refreshListenable handles reactivity.
      final authState = ref.read(authNotifierProvider);
      final isAuthenticated = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';
      final isSsoCallback = state.matchedLocation == '/sso-callback';

      if (!isAuthenticated && !isLoggingIn && !isSsoCallback) {
        return '/login';
      }

      if (isAuthenticated && isLoggingIn) {
        // Redirect to role-specific dashboard
        final userRole = authState.user?.role.toLowerCase();
        if (kDebugMode) {
          print('[Router] User authenticated with role: $userRole');
        }

        switch (userRole) {
          case 'agency':
            return '/home';
          case 'asm':
            return '/asm/dashboard';
          case 'ra':
            return '/hq/dashboard';
          case 'admin':
            return '/admin/dashboard';
          default:
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
        path: '/sso-callback',
        name: 'sso-callback',
        builder: (context, state) {
          final code = state.uri.queryParameters['code'];
          final error = state.uri.queryParameters['error'];
          final errorDescription =
              state.uri.queryParameters['error_description'];
          return SsoCallbackPage(
            code: code,
            error: error,
            errorDescription: errorDescription,
          );
        },
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) {
          return DashboardWrapper(
            builder: (token, userName, onLogout) => AgencyDashboardPage(
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
            builder: (token, userName, onLogout) => ASMReviewPage(
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
            builder: (token, userName, onLogout) => HQReviewPage(
              token: token,
              userName: userName,
            ),
          );
        },
      ),
      GoRoute(
        path: '/admin/dashboard',
        name: 'admin-dashboard',
        builder: (context, state) {
          return DashboardWrapper(
            builder: (token, userName, onLogout) => AdminDashboardPage(
              token: token,
              userName: userName,
              onLogout: onLogout,
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

          return NewAgencyUploadPage(
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
          final poNumber = args?['poNumber']?.toString();

          return ASMReviewDetailPage(
            submissionId: submissionId,
            token: token,
            userName: userName,
            poNumber: poNumber,
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
          final poNumber = args?['poNumber']?.toString();

          return HQReviewDetailPage(
            submissionId: submissionId,
            token: token,
            userName: userName,
            poNumber: poNumber,
          );
        },
      ),
    ],
  );
});
