import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/new_login_page.dart';
import 'features/submission/presentation/pages/agency_dashboard_page.dart';
import 'features/submission/presentation/pages/agency_upload_page.dart';
import 'features/submission/presentation/pages/agency_submission_detail_page.dart';
import 'features/conversational_submission/presentation/pages/conversational_submission_page.dart';
import 'features/assistant/presentation/pages/chat_screen.dart';
import 'features/admin/presentation/pages/admin_dashboard_page.dart';
import 'core/network/dio_client.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClaimsIQ',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (context) => const NewLoginPage(),
            );
          case '/agency/dashboard':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => _AuthWrapper(
                token: args?['token'] ?? '',
                child: AgencyDashboardPage(
                  token: args?['token'] ?? '',
                  userName: args?['userName'] ?? '',
                ),
              ),
            );
          case '/agency/upload':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => _AuthWrapper(
                token: args?['token'] ?? '',
                child: AgencyUploadPage(
                  token: args?['token'] ?? '',
                  userName: args?['userName'] ?? '',
                  submissionId: args?['submissionId']?.toString(),
                ),
              ),
            );
          case '/agency/submission-detail':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => _AuthWrapper(
                token: args?['token'] ?? '',
                child: AgencySubmissionDetailPage(
                  submissionId: args?['submissionId']?.toString() ?? '',
                  token: args?['token'] ?? '',
                  userName: args?['userName'] ?? '',
                  poNumber: args?['poNumber'] ?? '',
                ),
              ),
            );
          case '/agency/assistant':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => _AuthWrapper(
                token: args?['token'] ?? '',
                child: const ChatScreen(),
              ),
            );
          case '/admin/dashboard':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => _AuthWrapper(
                token: args?['token'] ?? '',
                child: AdminDashboardPage(
                  token: args?['token'] ?? '',
                  userName: args?['userName'] ?? '',
                ),
              ),
            );
          case '/agency/conversational-submission':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => _ConversationalSubmissionWrapper(
                token: args?['token'] ?? '',
              ),
            );
          default:
            return MaterialPageRoute(
              builder: (context) => const NewLoginPage(),
            );
        }
      },
    );
  }
}

/// Wrapper that sets the [authTokenProvider] so the conversational
/// submission feature (which uses Riverpod Dio client) can authenticate.
class _ConversationalSubmissionWrapper extends ConsumerStatefulWidget {
  final String token;
  const _ConversationalSubmissionWrapper({required this.token});

  @override
  ConsumerState<_ConversationalSubmissionWrapper> createState() =>
      _ConversationalSubmissionWrapperState();
}

class _ConversationalSubmissionWrapperState
    extends ConsumerState<_ConversationalSubmissionWrapper> {
  bool _tokenSet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authTokenProvider.notifier).state = widget.token;
      if (mounted) setState(() => _tokenSet = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_tokenSet) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const ConversationalSubmissionPage();
  }
}

/// Generic auth wrapper that sets the token before rendering the child.
class _AuthWrapper extends ConsumerStatefulWidget {
  final String token;
  final Widget child;
  const _AuthWrapper({required this.token, required this.child});

  @override
  ConsumerState<_AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<_AuthWrapper> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authTokenProvider.notifier).state = widget.token;
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return widget.child;
  }
}
