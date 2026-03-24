/// API endpoint constants
class ApiConstants {
  // Base URL — configured via --dart-define=API_BASE_URL=<url> at build time.
  // Dev default: http://localhost:5000/api
  // Production build (deploy.ps1): passes /api so requests are same-origin.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5001/api',
  );

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
  static String documentStatus(String id) => '/documents/$id/status';
  static String documentValidationResults(String id) => '/documents/$id/validation-results';

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

  // Conversational Submission endpoints
  static const String conversationMessage = '/conversation/message';
  static String conversationState(String id) => '/conversation/$id/state';
  static String conversationResume(String id) => '/conversation/$id/resume';

  // Purchase Order endpoints
  static const String purchaseOrderSearch = '/purchase-orders/search';
  static const String purchaseOrders = '/purchase-orders';

  // Dealer search endpoints
  static const String dealerSearch = '/state/dealers';

  // SignalR Hub
  static String get signalRHubUrl => baseUrl.replaceAll('/api', '/hubs/submission');
}
