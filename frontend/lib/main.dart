import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/new_login_page.dart';
import 'features/conversational_submission/presentation/pages/conversational_submission_page.dart';
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
    // Set the auth token synchronously before the child builds
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
