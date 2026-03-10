import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/new_login_page.dart';
import 'features/submission/presentation/pages/agency_dashboard_page.dart';
import 'features/submission/presentation/pages/agency_upload_page.dart';
import 'features/submission/presentation/pages/agency_submission_detail_page.dart';
import 'features/approval/presentation/pages/asm_review_page.dart';
import 'features/approval/presentation/pages/asm_review_detail_page.dart';
import 'features/approval/presentation/pages/hq_review_page.dart';
import 'features/approval/presentation/pages/hq_review_detail_page.dart';
import 'features/approval/presentation/pages/agency_review_detail_page.dart';
import 'features/analytics/presentation/pages/hq_analytics_page.dart';
import 'features/chat/presentation/pages/chat_page.dart';

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
      title: 'Bajaj Document Processing',
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
              builder: (context) => AgencyDashboardPage(
                token: args?['token'] ?? '',
                userName: args?['userName'] ?? 'User',
              ),
            );
          case '/agency/upload':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => AgencyUploadPage(
                token: args?['token'] ?? '',
                userName: args?['userName'] ?? 'User',
              ),
            );
          case '/agency/submission-detail':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => AgencySubmissionDetailPage(
                submissionId: args?['submissionId'] ?? '',
                token: args?['token'] ?? '',
                userName: args?['userName'] ?? 'User',
              ),
            );
          case '/asm/review':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => ASMReviewPage(
                token: args?['token'] ?? '',
                userName: args?['userName'] ?? 'User',
              ),
            );
          case '/asm/review-detail':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => ASMReviewDetailPage(
                submissionId: args?['submissionId'] ?? '',
                token: args?['token'] ?? '',
                userName: args?['userName'] ?? 'User',
              ),
            );
          case '/hq/review':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => HQReviewPage(
                token: args?['token'] ?? '',
                userName: args?['userName'] ?? 'User',
              ),
            );
          case '/hq/review-detail':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => HQReviewDetailPage(
                submissionId: args?['submissionId'] ?? '',
                token: args?['token'] ?? '',
                userName: args?['userName'] ?? 'User',
              ),
            );
          case '/agency/review-detail':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => AgencyReviewDetailPage(
                submissionId: args?['submissionId'] ?? '',
                token: args?['token'] ?? '',
                userName: args?['userName'] ?? 'User',
              ),
            );
          case '/hq/analytics':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => HQAnalyticsPage(
                token: args?['token'] ?? '',
                userName: args?['userName'] ?? 'User',
              ),
            );
          case '/chat':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => ChatPage(
                token: args?['token'] ?? '',
                userName: args?['userName'] ?? 'User',
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
