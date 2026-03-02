import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/new_login_page.dart';
import 'features/submission/presentation/pages/agency_dashboard_page.dart';
import 'features/submission/presentation/pages/agency_upload_page.dart';
import 'features/approval/presentation/pages/asm_review_page.dart';
import 'features/analytics/presentation/pages/hq_analytics_page.dart';

void main() {
  runApp(const MyApp());
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
          case '/asm/review':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => ASMReviewPage(
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
          default:
            return MaterialPageRoute(
              builder: (context) => const NewLoginPage(),
            );
        }
      },
    );
  }
}
