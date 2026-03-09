/// API endpoint constants
class ApiConstants {
  // Base URL - update this to match your backend
  static const String baseUrl = 'http://localhost:5000/api';

  // Auth endpoints
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // Submission endpoints
  static const String submissions = '/submissions';
  static String submissionById(String id) => '/submissions/$id';
  static String approveSubmission(String id) => '/submissions/$id/approve';
  static String rejectSubmission(String id) => '/submissions/$id/reject';
  static String requestReupload(String id) => '/submissions/$id/request-reupload';

  // Document endpoints
  static const String uploadDocument = '/documents/upload';
  static String documentById(String id) => '/documents/$id';

  // Analytics endpoints
  static const String kpis = '/analytics/kpis';
  static const String stateRoi = '/analytics/state-roi';
  static const String campaignBreakdown = '/analytics/campaign-breakdown';
  static const String exportAnalytics = '/analytics/export';
  static const String quarterlyFapKpis = '/analytics/quarterly-fap';

  // Chat endpoints
  static const String chatMessage = '/chat/message';
  static const String chatHistory = '/chat/history';

  // Notification endpoints
  static const String notifications = '/notifications';
  static String markNotificationRead(String id) => '/notifications/$id/read';
}
