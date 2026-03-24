// =============================================================================
// Integration Test Configuration
//
// All file paths and test settings in one place for easy updates.
// These paths point to local demo documents used during integration testing.
// =============================================================================

/// Base folder containing all demo documents.
const String kDemoDocsBase =
    r'C:\Users\sausonar\Downloads\OneDrive_2026-03-05\03 Demo Documents\Pilot FAP Docs';

/// Individual document paths used in the upload flow.
/// For local disk paths (non-web), use these.
/// For Flutter web, files are loaded from assets/test_docs/ instead.
class TestDocPaths {
  TestDocPaths._();

  // ── Local disk paths (for reference / non-web tests) ──

  static const String invoice =
      r'C:\Users\sausonar\Downloads\OneDrive_2026-03-05\03 Demo Documents\Pilot FAP Docs\Invoice_Document\E-Invoice-145.pdf';

  static const String costSummary =
      r'C:\Users\sausonar\Downloads\OneDrive_2026-03-05\03 Demo Documents\Pilot FAP Docs\Cost_Summary\Cost Summary for Bajaj Maxima Z Swarojgar Activity Up .pdf';

  static const String activitySummary =
      r'C:\Users\sausonar\Downloads\OneDrive_2026-03-05\03 Demo Documents\Pilot FAP Docs\Activity_Summary\MS Swift UP Activity Summary.jpg';

  static const String enquiryReport =
      r'C:\Users\sausonar\Downloads\OneDrive_2026-03-05\03 Demo Documents\Pilot FAP Docs\Enquiry_Report\IBU - Activation Reporting Format.xlsx';

  static const String purchaseOrder =
      r'C:\Users\sausonar\Downloads\OneDrive_2026-03-05\03 Demo Documents\Pilot FAP Docs\PO_Document\PO - UP.png';

  // ── Flutter asset paths (used by integration_test_runner on web) ──

  static const String invoiceAsset = 'assets/test_docs/E-Invoice-145.pdf';
  static const String costSummaryAsset = 'assets/test_docs/Cost_Summary.pdf';
  static const String activitySummaryAsset = 'assets/test_docs/Activity_Summary.jpg';
  static const String teamPhotoAsset = 'assets/test_docs/Team_Photo.jpeg';
  static const String teamPhoto2Asset = 'assets/test_docs/Team_photo2.jpeg';
  static const String teamPhoto3Asset = 'assets/test_docs/Team_photo3.jpeg';
  static const String enquiryReportAsset = 'assets/test_docs/Enquiry_Report.xlsx';
}

/// Test credentials (dev-seeded agency user).
class TestCredentials {
  TestCredentials._();

  static const String email = 'agency@bajaj.com';
  static const String password = 'Password123!';
}

/// API configuration for tests.
class TestApiConfig {
  TestApiConfig._();

  static const String baseUrl = 'http://localhost:5000';
  static const String apiBaseUrl = 'http://localhost:5000/api';
}

/// Upload page test settings.
class TestUploadConfig {
  TestUploadConfig._();

  /// Which PO to select (null = first available).
  static const String? poNumber = null;

  /// Which state to select for activation.
  static const String activationState = 'Maharashtra';
}
