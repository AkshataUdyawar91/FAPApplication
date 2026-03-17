# Design Document: ASM Review Page Excel-Based Layout

## Overview

This design document describes the redesign of the ASM Review Detail Page to adopt an Excel-based layout structure. The new design replaces the current document card sections with a cleaner, tabular format that presents document validation information in two main tables: Invoice and Additional Documents Table, and Campaign Details Table.

### Key Changes

1. **Header Redesign**: Move action buttons (Approve FAP, Reject FAP) from the side panel to the header area
2. **Invoice Summary Section**: New section displaying key invoice information at a glance
3. **Invoice Documents Table**: Replaces PO, Invoice, and Cost Summary document cards with a structured table
4. **Campaign Details Table**: Replaces Event Photos section with dealer-grouped photo table
5. **Removal of Legacy Components**: Remove AI Quick Summary, side panel, and document card layouts

### Design Goals

- Improve information density and scannability
- Reduce vertical scrolling by consolidating information into tables
- Maintain all existing workflow functionality (approve, reject, resubmit)
- Ensure responsive design across mobile, tablet, and desktop

## Architecture

### Component Hierarchy

```
ASMReviewDetailPage (StatefulWidget)
├── _ASMReviewExcelHeader (StatelessWidget)
│   ├── BackButton
│   ├── Title
│   └── ActionButtonsRow
│       ├── ApproveFAPButton
│       └── RejectFAPButton
├── _InvoiceSummarySection (StatelessWidget)
│   ├── InvoiceAmountCard
│   ├── AgencyNameCard
│   └── SubmittedDateCard
├── _InvoiceDocumentsTable (StatelessWidget)
│   └── DataTable with columns: S.No, Category, Document Name, Status, Remarks
├── _CampaignDetailsTable (StatelessWidget)
│   └── DataTable with columns: S.No, Dealer Name, Campaign Date, Document Name, Status, Remarks
└── _HQRejectionSection (StatelessWidget) [Conditional]
    └── ResubmitToHQButton
```

### State Management

The page continues to use StatefulWidget with local state management (consistent with current implementation). State variables:

- `_isLoading`: Boolean for initial data loading
- `_isProcessing`: Boolean for action button processing state
- `_submission`: Map containing submission data from API
- `_commentsController`: TextEditingController for rejection reason input

### Data Flow

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   API Response  │────▶│  Data Transform  │────▶│  Table Models   │
│   (submission)  │     │    Functions     │     │                 │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                                         │
                                                         ▼
                                                 ┌─────────────────┐
                                                 │   UI Widgets    │
                                                 │   (Tables)      │
                                                 └─────────────────┘
```

## Components and Interfaces

### 1. ASMReviewExcelHeader Widget

**File**: `frontend/lib/features/approval/presentation/widgets/asm_review_excel_header.dart`

```dart
class ASMReviewExcelHeader extends StatelessWidget {
  final String fapId;
  final String state;
  final bool isProcessing;
  final VoidCallback onBack;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  
  const ASMReviewExcelHeader({
    super.key,
    required this.fapId,
    required this.state,
    required this.isProcessing,
    required this.onBack,
    required this.onApprove,
    required this.onReject,
  });
}
```

**Responsibilities**:
- Display back navigation button
- Display FAP ID and status badge
- Display action buttons (Reject, Send Back, Put On Hold, Approve Request) ONLY when state is "PendingApproval" or "RejectedByHQ"
- Hide action buttons when state is "Approved", "Rejected", or any other final state
- Disable buttons during processing state
- Show loading indicator when processing

**Conditional Visibility Logic**:
```dart
bool _isActionable(String state) {
  final normalizedState = state.toLowerCase();
  return normalizedState == 'pendingapproval' || normalizedState == 'rejectedbyhq';
}
```

### 2. InvoiceSummarySection Widget

**File**: `frontend/lib/features/approval/presentation/widgets/invoice_summary_section.dart`

```dart
class InvoiceSummarySection extends StatelessWidget {
  final String invoiceAmount;
  final String agencyName;
  final String submittedDate;
  
  const InvoiceSummarySection({
    super.key,
    required this.invoiceAmount,
    required this.agencyName,
    required this.submittedDate,
  });
}
```

**Responsibilities**:
- Display invoice amount in prominent format
- Display agency name
- Display submission date
- Handle "N/A" for missing data

### 2A. CommentsSection Widget

**File**: Inline in `asm_review_detail_page.dart` as `_buildCommentsSection()`

```dart
Widget _buildCommentsSection() {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Comments (Optional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            controller: _commentsController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Add your review comments here...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: AppColors.background,
            ),
          ),
        ],
      ),
    ),
  );
}
```

**Responsibilities**:
- Display multi-line text input for optional review comments
- Only render when submission state is "PendingApproval" or "RejectedByHQ"
- Hide when submission state is "Approved", "Rejected", or any other final state
- Include comments in approval API request when Approve Request button is clicked

**Conditional Visibility Logic**:
```dart
bool _isSubmissionActionable() {
  final state = _submission?['state']?.toString().toLowerCase() ?? '';
  return state == 'pendingapproval' || state == 'rejectedbyhq';
}

// In build method:
if (_isSubmissionActionable())
  _buildCommentsSection(),
```

### 3. InvoiceDocumentsTable Widget

**File**: `frontend/lib/features/approval/presentation/widgets/invoice_documents_table.dart`

```dart
class InvoiceDocumentsTable extends StatelessWidget {
  final List<InvoiceDocumentRow> documents;
  final Function(InvoiceDocumentRow) onDocumentTap;
  
  const InvoiceDocumentsTable({
    super.key,
    required this.documents,
    required this.onDocumentTap,
  });
}
```

**Responsibilities**:
- Render table with columns: S.No, Category, Document Name, Status, Remarks
- Apply alternating row colors
- Handle document tap for viewing/download
- Support horizontal scrolling on mobile

### 4. CampaignDetailsTable Widget

**File**: `frontend/lib/features/approval/presentation/widgets/campaign_details_table.dart`

```dart
class CampaignDetailsTable extends StatelessWidget {
  final List<CampaignDetailRow> campaignDetails;
  final Function(CampaignDetailRow) onPhotoTap;
  
  const CampaignDetailsTable({
    super.key,
    required this.campaignDetails,
    required this.onPhotoTap,
  });
}
```

**Responsibilities**:
- Render table with columns: S.No, Dealer Name, Campaign Date, Document Name, Status, Remarks
- Group rows visually by dealer
- Apply alternating row colors
- Handle photo tap for viewing
- Support horizontal scrolling on mobile

### 5. Data Transformation Functions

**File**: `frontend/lib/features/approval/presentation/utils/submission_data_transformer.dart`

```dart
class SubmissionDataTransformer {
  /// Extracts invoice summary data from submission
  static InvoiceSummaryData extractInvoiceSummary(Map<String, dynamic> submission);
  
  /// Transforms documents into InvoiceDocumentRow list
  static List<InvoiceDocumentRow> transformToInvoiceDocuments(
    List<dynamic> documents,
    Map<String, dynamic>? validationResult,
  );
  
  /// Transforms photos into CampaignDetailRow list grouped by dealer
  static List<CampaignDetailRow> transformToCampaignDetails(
    List<dynamic> photos,
    Map<String, dynamic>? validationResult,
  );
}
```

## Data Models

### InvoiceSummaryData

```dart
/// Data model for the Invoice Summary section
class InvoiceSummaryData {
  final String invoiceAmount;
  final String agencyName;
  final String submittedDate;
  
  const InvoiceSummaryData({
    required this.invoiceAmount,
    required this.agencyName,
    required this.submittedDate,
  });
  
  factory InvoiceSummaryData.empty() => const InvoiceSummaryData(
    invoiceAmount: 'N/A',
    agencyName: 'N/A',
    submittedDate: 'N/A',
  );
}
```

### InvoiceDocumentRow

```dart
/// Data model for a row in the Invoice Documents Table
class InvoiceDocumentRow {
  final int serialNumber;
  final String category;        // "Invoice", "PO", "Cost Summary"
  final String documentName;    // Filename
  final ValidationStatus status; // ok, failed
  final String remarks;         // AI validation remarks
  final String? blobUrl;        // For download/view
  
  const InvoiceDocumentRow({
    required this.serialNumber,
    required this.category,
    required this.documentName,
    required this.status,
    required this.remarks,
    this.blobUrl,
  });
}

enum ValidationStatus {
  ok,
  failed,
}
```

### CampaignDetailRow

```dart
/// Data model for a row in the Campaign Details Table
class CampaignDetailRow {
  final int serialNumber;
  final String dealerName;      // "D1", "D2", etc.
  final String campaignDate;    // Date of campaign
  final String documentName;    // "Pic1", "Pic2", etc.
  final ValidationStatus status; // ok, failed
  final String remarks;         // AI validation remarks (e.g., "photo was clear")
  final String? blobUrl;        // For viewing
  final bool isFirstInGroup;    // For visual grouping
  
  const CampaignDetailRow({
    required this.serialNumber,
    required this.dealerName,
    required this.campaignDate,
    required this.documentName,
    required this.status,
    required this.remarks,
    this.blobUrl,
    this.isFirstInGroup = false,
  });
}
```

### Data Extraction from Current API Response

The current API response structure for a submission:

```json
{
  "id": "guid",
  "state": "PendingApproval",
  "createdAt": "2024-01-15T10:30:00Z",
  "documents": [
    {
      "type": "Invoice",
      "filename": "invoice.pdf",
      "blobUrl": "https://...",
      "extractedData": {
        "InvoiceNumber": "INV-001",
        "TotalAmount": "50000",
        "Date": "2024-01-10"
      }
    },
    {
      "type": "PO",
      "filename": "po.pdf",
      "blobUrl": "https://...",
      "extractedData": {...}
    },
    {
      "type": "CostSummary",
      "filename": "cost.pdf",
      "blobUrl": "https://...",
      "extractedData": {...}
    },
    {
      "type": "Photo",
      "filename": "event_photo_1.jpg",
      "blobUrl": "https://...",
      "metadata": {
        "dealerCode": "D1",
        "campaignDate": "2024-01-08"
      }
    }
  ],
  "validationResult": {
    "allValidationsPassed": true,
    "documentValidations": [
      {
        "documentType": "Invoice",
        "isValid": true,
        "remarks": "Invoice validated successfully"
      }
    ]
  },
  "confidenceScore": {
    "overallConfidence": 0.92,
    "invoiceConfidence": 0.95,
    "poConfidence": 0.90
  }
}
```

### Transformation Logic

```dart
// Extract Invoice Summary
InvoiceSummaryData extractInvoiceSummary(Map<String, dynamic> submission) {
  final documents = submission['documents'] as List? ?? [];
  String invoiceAmount = 'N/A';
  
  // Find invoice document and extract amount
  for (var doc in documents) {
    if (doc['type'] == 'Invoice' && doc['extractedData'] != null) {
      final data = _parseExtractedData(doc['extractedData']);
      invoiceAmount = '₹${data['TotalAmount'] ?? '0'}';
      break;
    }
  }
  
  return InvoiceSummaryData(
    invoiceAmount: invoiceAmount,
    agencyName: submission['agencyName'] ?? 'N/A',
    submittedDate: _formatDate(submission['createdAt']),
  );
}

// Transform to Invoice Documents Table rows
List<InvoiceDocumentRow> transformToInvoiceDocuments(
  List<dynamic> documents,
  Map<String, dynamic>? validationResult,
) {
  final rows = <InvoiceDocumentRow>[];
  int serialNo = 1;
  
  // Order: Invoice, PO, Cost Summary
  final docTypes = ['Invoice', 'PO', 'CostSummary'];
  final categoryNames = {'Invoice': 'Invoice', 'PO': 'PO', 'CostSummary': 'Cost Summary'};
  
  for (var type in docTypes) {
    final doc = documents.firstWhere(
      (d) => d['type'] == type,
      orElse: () => null,
    );
    
    if (doc != null) {
      final validation = _findValidation(validationResult, type);
      rows.add(InvoiceDocumentRow(
        serialNumber: serialNo++,
        category: categoryNames[type] ?? type,
        documentName: doc['filename'] ?? 'document.pdf',
        status: validation['isValid'] == true 
            ? ValidationStatus.ok 
            : ValidationStatus.failed,
        remarks: validation['remarks'] ?? 'Validated',
        blobUrl: doc['blobUrl'],
      ));
    }
  }
  
  return rows;
}

// Transform to Campaign Details Table rows
List<CampaignDetailRow> transformToCampaignDetails(
  List<dynamic> photos,
  Map<String, dynamic>? validationResult,
) {
  final rows = <CampaignDetailRow>[];
  
  // Group photos by dealer
  final dealerGroups = <String, List<dynamic>>{};
  for (var photo in photos) {
    final dealerCode = photo['metadata']?['dealerCode'] ?? 'Unknown';
    dealerGroups.putIfAbsent(dealerCode, () => []).add(photo);
  }
  
  int serialNo = 1;
  for (var entry in dealerGroups.entries) {
    final dealerName = entry.key;
    final dealerPhotos = entry.value;
    
    for (int i = 0; i < dealerPhotos.length; i++) {
      final photo = dealerPhotos[i];
      final validation = _findPhotoValidation(validationResult, photo['id']);
      
      rows.add(CampaignDetailRow(
        serialNumber: serialNo++,
        dealerName: dealerName,
        campaignDate: photo['metadata']?['campaignDate'] ?? 'N/A',
        documentName: 'Pic${i + 1}',
        status: validation['isValid'] == true 
            ? ValidationStatus.ok 
            : ValidationStatus.failed,
        remarks: validation['remarks'] ?? 'Photo validated',
        blobUrl: photo['blobUrl'],
        isFirstInGroup: i == 0,
      ));
    }
  }
  
  return rows;
}
```



## Responsive Design Approach

### Breakpoints

Following Flutter best practices and project guidelines:

| Screen Size | Width | Layout Behavior |
|-------------|-------|-----------------|
| Mobile | < 600px | Single column, horizontal scroll for tables |
| Tablet | 600px - 900px | Single column, optimized column widths |
| Desktop | > 900px | Full table layout, no horizontal scroll |

### Layout Strategy

```dart
Widget build(BuildContext context) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = constraints.maxWidth;
      final isMobile = screenWidth < 600;
      final isTablet = screenWidth >= 600 && screenWidth < 900;
      final isDesktop = screenWidth >= 900;
      
      return Scaffold(
        body: Column(
          children: [
            // Header with action buttons - always visible
            ASMReviewExcelHeader(...),
            
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  children: [
                    // Invoice Summary - responsive grid
                    InvoiceSummarySection(...),
                    SizedBox(height: isMobile ? 16 : 24),
                    
                    // Invoice Documents Table - horizontal scroll on mobile
                    _buildResponsiveTable(
                      InvoiceDocumentsTable(...),
                      isMobile: isMobile,
                    ),
                    SizedBox(height: isMobile ? 16 : 24),
                    
                    // Campaign Details Table - horizontal scroll on mobile
                    _buildResponsiveTable(
                      CampaignDetailsTable(...),
                      isMobile: isMobile,
                    ),
                    
                    // HQ Rejection Section (conditional)
                    if (_showHQRejection) ...[
                      SizedBox(height: isMobile ? 16 : 24),
                      HQRejectionSection(...),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildResponsiveTable(Widget table, {required bool isMobile}) {
  if (isMobile) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: table,
    );
  }
  return table;
}
```

### Mobile-Specific Adaptations

1. **Header**: Stack action buttons vertically if space is constrained
2. **Invoice Summary**: Display as vertical list instead of horizontal row
3. **Tables**: Enable horizontal scrolling with fixed first column
4. **Touch Targets**: Ensure minimum 48x48 tap areas for all interactive elements

### Table Column Widths

```dart
// Invoice Documents Table
final invoiceTableColumnWidths = {
  0: FixedColumnWidth(50),   // S.No
  1: FixedColumnWidth(120),  // Category
  2: FlexColumnWidth(2),     // Document Name
  3: FixedColumnWidth(80),   // Status
  4: FlexColumnWidth(3),     // Remarks
};

// Campaign Details Table
final campaignTableColumnWidths = {
  0: FixedColumnWidth(50),   // S.No
  1: FixedColumnWidth(100),  // Dealer Name
  2: FixedColumnWidth(120),  // Campaign Date
  3: FixedColumnWidth(100),  // Document Name
  4: FixedColumnWidth(80),   // Status
  5: FlexColumnWidth(2),     // Remarks
};
```

## File Organization

### New Files to Create

```
frontend/lib/features/approval/
├── data/
│   └── models/
│       ├── invoice_document_row.dart      # NEW
│       ├── campaign_detail_row.dart       # NEW
│       └── invoice_summary_data.dart      # NEW
├── presentation/
│   ├── pages/
│   │   └── asm_review_detail_page.dart    # MODIFY (major refactor)
│   ├── widgets/
│   │   ├── asm_review_excel_header.dart   # NEW
│   │   ├── invoice_summary_section.dart   # NEW
│   │   ├── invoice_documents_table.dart   # NEW
│   │   ├── campaign_details_table.dart    # NEW
│   │   └── hq_rejection_section.dart      # NEW (extract from page)
│   └── utils/
│       └── submission_data_transformer.dart # NEW
```

### Files to Modify

1. **asm_review_detail_page.dart**: Major refactor to use new widget structure
   - Remove: `_buildHeader()`, `_buildAIQuickSummary()`, `_buildDocumentSections()`, `_buildReviewDecisionPanel()`
   - Add: Integration with new widgets and data transformers

### Files to Remove (Code Sections)

The following methods in `asm_review_detail_page.dart` will be removed:
- `_buildAIQuickSummary()`
- `_buildDocumentSections()`
- `_buildDocumentSectionFromData()`
- `_buildPhotosSectionFromData()`
- `_buildDocumentSection()`
- `_buildPhotoCard()`
- `_buildAnalysisPoint()`
- `_buildAIAnalysisTable()`
- `_buildDocumentDataTable()`
- `_buildDocumentDataTableFromAnalysis()`
- `_buildReviewDecisionPanel()`
- `_buildSummaryPoint()`

## State Management for Action Buttons

### Current State Variables (Preserved)

```dart
class _ASMReviewDetailPageState extends State<ASMReviewDetailPage> {
  bool _isLoading = true;
  bool _isProcessing = false;
  Map<String, dynamic>? _submission;
  final _commentsController = TextEditingController();
}
```

### Conditional Visibility State

The visibility of action buttons and comments section is determined by the submission state:

```dart
bool _isSubmissionActionable() {
  final state = _submission?['state']?.toString().toLowerCase() ?? '';
  // Action buttons and comments should only be visible for PendingApproval or RejectedByHQ states
  return state == 'pendingapproval' || state == 'rejectedbyhq';
}
```

**Actionable States**:
- `PendingApproval`: Initial state when ASM needs to review
- `RejectedByHQ`: HQ rejected and sent back to ASM for resubmission

**Non-Actionable States** (buttons and comments hidden):
- `Approved`: Already approved by ASM
- `Rejected`: Already rejected by ASM
- `ReuploadRequested`: Sent back to agency
- Any other final state

### Action Button State Flow

```
┌─────────────────┐
│  Initial State  │
│  isProcessing:  │
│     false       │
│  Actionable:    │
│  Check state    │
└────────┬────────┘
         │
         ▼ If state is PendingApproval or RejectedByHQ
┌─────────────────┐
│  Show Buttons   │
│  & Comments     │
│  isProcessing:  │
│     false       │
└────────┬────────┘
         │
         ▼ User clicks Approve/Reject
┌─────────────────┐
│  Processing     │
│  isProcessing:  │
│     true        │
│  Buttons:       │
│   disabled      │
└────────┬────────┘
         │
         ▼ API Response
┌─────────────────┐     ┌─────────────────┐
│   Success       │     │    Error        │
│  Navigate back  │     │  Show snackbar  │
│  to list page   │     │  isProcessing:  │
└─────────────────┘     │     false       │
                        └─────────────────┘
```

### Rejection Flow with Validation

```dart
Future<void> _handleReject() async {
  // Show rejection reason dialog
  final reason = await _showRejectionDialog();
  
  if (reason == null || reason.trim().isEmpty) {
    // User cancelled or empty reason
    _showError('Please provide a rejection reason');
    return;
  }
  
  setState(() => _isProcessing = true);
  
  try {
    await _rejectSubmission(reason);
    _showSuccess('FAP rejected successfully');
    Navigator.pop(context);
  } catch (e) {
    _showError('Failed to reject: ${e.toString()}');
  } finally {
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }
}
```

## Workflow Functionality Preservation

### Existing Workflows to Maintain

1. **ASM Approval Flow**
   - Endpoint: `PATCH /api/submissions/{id}/asm-approve`
   - Payload: `{ "notes": "optional comments" }`
   - Success: Navigate back to review list

2. **ASM Rejection Flow**
   - Endpoint: `PATCH /api/submissions/{id}/asm-reject`
   - Payload: `{ "reason": "required rejection reason" }`
   - Validation: Reason must not be empty
   - Success: Navigate back to review list

3. **HQ Rejection Resubmit Flow**
   - Condition: `state == 'RejectedByHQ'`
   - Endpoint: `PATCH /api/submissions/{id}/resubmit-to-hq`
   - Payload: `{ "notes": "required notes" }`
   - Success: Navigate back to review list

### API Integration (Unchanged)

```dart
// Approval
Future<void> _approveSubmission() async {
  final response = await _dio.patch(
    '/submissions/${widget.submissionId}/asm-approve',
    data: {'notes': _commentsController.text.trim()},
    options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
  );
  // Handle response...
}

// Rejection
Future<void> _rejectSubmission(String reason) async {
  final response = await _dio.patch(
    '/submissions/${widget.submissionId}/asm-reject',
    data: {'reason': reason},
    options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
  );
  // Handle response...
}

// Resubmit to HQ
Future<void> _resubmitToHQ(String notes) async {
  final response = await _dio.patch(
    '/submissions/${widget.submissionId}/resubmit-to-hq',
    data: {'notes': notes},
    options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
  );
  // Handle response...
}
```

## Visual Design Specifications

### Color Scheme (Bajaj Brand)

```dart
// Header
headerBackground: AppColors.primary  // #0066FF
headerText: Colors.white

// Invoice Summary Section
summaryBackground: AppColors.cardBackground  // #FFFFFF
summaryBorder: AppColors.border  // #E5E7EB

// Table Header
tableHeaderBackground: AppColors.primary  // #0066FF
tableHeaderText: Colors.white

// Table Rows (Alternating)
tableRowEven: Colors.white
tableRowOdd: AppColors.background  // #F9FAFB

// Status Indicators
statusOk: Color(0xFF10B981)  // Green
statusFailed: Color(0xFFEF4444)  // Red

// Action Buttons
approveButton: Color(0xFF10B981)  // Green
rejectButton: Color(0xFFEF4444)  // Red (outlined)
```

### Typography

```dart
// Header Title
headerTitle: AppTextStyles.h2.copyWith(
  color: Colors.white,
  fontWeight: FontWeight.bold,
)

// Table Header
tableHeader: AppTextStyles.bodySmall.copyWith(
  fontWeight: FontWeight.w600,
  color: Colors.white,
)

// Table Cell
tableCell: AppTextStyles.bodyMedium

// Status Text
statusText: AppTextStyles.bodySmall.copyWith(
  fontWeight: FontWeight.w600,
)
```

### Spacing

```dart
// Page padding
pagePadding: EdgeInsets.all(24)  // Desktop/Tablet
pagePaddingMobile: EdgeInsets.all(16)

// Section spacing
sectionSpacing: 24.0  // Desktop/Tablet
sectionSpacingMobile: 16.0

// Table cell padding
tableCellPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)
```



## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Button Disabled State During Processing

*For any* processing state where `isProcessing` is true, both the Approve FAP and Reject FAP buttons should be disabled and a loading indicator should be visible.

**Validates: Requirements 1.5**

### Property 2: Rejection Reason Validation

*For any* string that is empty or composed entirely of whitespace characters, attempting to submit a rejection should be prevented and an error message should be displayed.

**Validates: Requirements 1.6**

### Property 3: Invoice Summary Data Extraction

*For any* submission containing an invoice document with extracted data, the Invoice Summary section should display the correct invoice amount (from TotalAmount field), agency name, and formatted submission date.

**Validates: Requirements 2.2, 2.3, 2.4**

### Property 4: Missing Data Handling

*For any* submission where invoice data, agency name, or submission date is missing or null, the corresponding field in the Invoice Summary section should display "N/A".

**Validates: Requirements 2.5**

### Property 5: Document Type to Table Row Transformation

*For any* submission containing Invoice, PO, or Cost Summary documents, each document type should appear as exactly one row in the Invoice Documents Table with the correct category label.

**Validates: Requirements 3.3**

### Property 6: Validation Status Values

*For any* row in the Invoice Documents Table or Campaign Details Table, the Status column should contain exactly one of two values: "ok" or "failed" — no other values are permitted.

**Validates: Requirements 3.4, 4.5**

### Property 7: Validation Remarks Display

*For any* document or photo that has associated validation remarks in the API response, those remarks should appear in the Remarks column of the corresponding table row.

**Validates: Requirements 3.5, 4.6**

### Property 8: Alternating Row Colors

*For any* table (Invoice Documents or Campaign Details) with multiple rows, even-indexed rows should have a white background and odd-indexed rows should have the background color (`#F9FAFB`).

**Validates: Requirements 3.7, 4.8**

### Property 9: Photo Dealer Grouping and Naming

*For any* set of photos with dealer codes, the Campaign Details Table should group photos by dealer and assign sequential document names (Pic1, Pic2, etc.) within each dealer group.

**Validates: Requirements 4.3, 4.4**

### Property 10: Dealer Visual Grouping Indicator

*For any* dealer group in the Campaign Details Table, the first row of each group should have a visual indicator (e.g., `isFirstInGroup` flag) that distinguishes it from subsequent rows in the same group.

**Validates: Requirements 4.9**

### Property 11: Mobile Horizontal Scroll

*For any* screen width less than 600px, tables should be wrapped in a horizontal scroll container, allowing users to scroll horizontally to view all columns.

**Validates: Requirements 5.2**

### Property 12: Desktop Full Table Display

*For any* screen width greater than 900px, tables should display all columns without requiring horizontal scrolling.

**Validates: Requirements 5.4**

### Property 13: Action Buttons Accessibility

*For any* screen size (mobile, tablet, or desktop), the Approve FAP and Reject FAP buttons should remain visible and accessible in the header section.

**Validates: Requirements 5.5**

### Property 14: HQ Rejection Section Visibility

*For any* submission with state equal to "RejectedByHQ", the HQ Rejection section with resubmit option should be visible. For any other state, this section should not be rendered.

**Validates: Requirements 6.4**

### Property 15: Workflow Action Notifications

*For any* workflow action (approve, reject, or resubmit to HQ), upon completion (success or failure), a notification (SnackBar) should be displayed to the user indicating the result.

**Validates: Requirements 6.5**

## Error Handling

### API Error Handling

| Error Type | HTTP Status | User Message | Recovery Action |
|------------|-------------|--------------|-----------------|
| Network Error | N/A | "Failed to load submission. Please check your connection." | Retry button |
| Not Found | 404 | "Submission not found" | Navigate back |
| Unauthorized | 401 | "Session expired. Please log in again." | Redirect to login |
| Server Error | 500 | "Something went wrong. Please try again." | Retry button |
| Validation Error | 400 | Display specific validation message | Show inline error |

### Error Handling Implementation

```dart
Future<void> _loadSubmissionDetails() async {
  setState(() => _isLoading = true);

  try {
    final response = await _dio.get(
      '/submissions/${widget.submissionId}',
      options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
    );

    if (response.statusCode == 200 && mounted) {
      setState(() {
        _submission = response.data;
        _isLoading = false;
      });
    }
  } on DioException catch (e) {
    if (!mounted) return;
    
    setState(() => _isLoading = false);
    
    final message = switch (e.response?.statusCode) {
      401 => 'Session expired. Please log in again.',
      404 => 'Submission not found',
      500 => 'Server error. Please try again later.',
      _ => 'Failed to load submission: ${e.message}',
    };
    
    _showErrorSnackBar(message);
    
    if (e.response?.statusCode == 401) {
      // Navigate to login
    } else if (e.response?.statusCode == 404) {
      Navigator.pop(context);
    }
  }
}
```

### Input Validation Errors

```dart
// Rejection reason validation
String? _validateRejectionReason(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Please provide a rejection reason';
  }
  if (value.trim().length < 10) {
    return 'Rejection reason must be at least 10 characters';
  }
  return null;
}

// Resubmit notes validation
String? _validateResubmitNotes(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Please provide notes explaining what was addressed';
  }
  return null;
}
```

### Graceful Degradation

- If validation remarks are missing, display "Validated" as default
- If dealer code is missing from photo metadata, group under "Unknown"
- If campaign date is missing, display "N/A"
- If blob URL is missing, disable the view/download action and show tooltip

## Testing Strategy

### Unit Tests

Unit tests focus on specific examples, edge cases, and data transformation logic.

**Data Transformer Tests** (`submission_data_transformer_test.dart`):
- Test `extractInvoiceSummary` with complete data
- Test `extractInvoiceSummary` with missing invoice document
- Test `extractInvoiceSummary` with null extractedData
- Test `transformToInvoiceDocuments` with all document types present
- Test `transformToInvoiceDocuments` with missing document types
- Test `transformToCampaignDetails` with multiple dealers
- Test `transformToCampaignDetails` with single dealer
- Test `transformToCampaignDetails` with missing dealer codes

**Widget Tests**:
- Test `ASMReviewExcelHeader` renders back button
- Test `ASMReviewExcelHeader` renders action buttons
- Test `ASMReviewExcelHeader` disables buttons when processing
- Test `InvoiceSummarySection` displays all fields
- Test `InvoiceSummarySection` displays N/A for missing data
- Test `InvoiceDocumentsTable` renders correct columns
- Test `InvoiceDocumentsTable` handles document tap
- Test `CampaignDetailsTable` renders correct columns
- Test `CampaignDetailsTable` groups by dealer visually

### Property-Based Tests

Property-based tests use randomized inputs to verify universal properties. Use the `fast_check` package for Dart property-based testing.

**Configuration**: Each property test runs minimum 100 iterations.

**Test File**: `asm_review_excel_layout_properties_test.dart`

```dart
// Feature: asm-review-excel-layout, Property 2: Rejection Reason Validation
test('whitespace-only rejection reasons are rejected', () {
  fc.check(
    fc.property(
      fc.string().filter((s) => s.trim().isEmpty),
      (whitespaceString) {
        final result = validateRejectionReason(whitespaceString);
        expect(result, isNotNull); // Should return error message
      },
    ),
    numRuns: 100,
  );
});

// Feature: asm-review-excel-layout, Property 6: Validation Status Values
test('all document rows have valid status values', () {
  fc.check(
    fc.property(
      arbitrarySubmissionDocuments(),
      (documents) {
        final rows = transformToInvoiceDocuments(documents, null);
        for (final row in rows) {
          expect(
            row.status,
            anyOf(ValidationStatus.ok, ValidationStatus.failed),
          );
        }
      },
    ),
    numRuns: 100,
  );
});

// Feature: asm-review-excel-layout, Property 8: Alternating Row Colors
test('table rows have alternating colors', () {
  fc.check(
    fc.property(
      fc.integer(min: 2, max: 20),
      (rowCount) {
        final rows = List.generate(rowCount, (i) => createMockRow(i));
        for (int i = 0; i < rows.length; i++) {
          final expectedColor = i.isEven ? Colors.white : AppColors.background;
          expect(getRowColor(i), equals(expectedColor));
        }
      },
    ),
    numRuns: 100,
  );
});

// Feature: asm-review-excel-layout, Property 9: Photo Dealer Grouping
test('photos are grouped by dealer with sequential naming', () {
  fc.check(
    fc.property(
      arbitraryPhotosWithDealers(),
      (photos) {
        final rows = transformToCampaignDetails(photos, null);
        
        // Group rows by dealer
        final dealerGroups = <String, List<CampaignDetailRow>>{};
        for (final row in rows) {
          dealerGroups.putIfAbsent(row.dealerName, () => []).add(row);
        }
        
        // Verify sequential naming within each group
        for (final group in dealerGroups.values) {
          for (int i = 0; i < group.length; i++) {
            expect(group[i].documentName, equals('Pic${i + 1}'));
          }
        }
      },
    ),
    numRuns: 100,
  );
});
```

### Integration Tests

- Test complete approval flow from page load to navigation
- Test complete rejection flow with dialog interaction
- Test HQ resubmit flow when in RejectedByHQ state
- Test responsive layout at different screen sizes

### Test Organization

```
frontend/test/features/approval/
├── data/
│   └── models/
│       ├── invoice_document_row_test.dart
│       ├── campaign_detail_row_test.dart
│       └── invoice_summary_data_test.dart
├── presentation/
│   ├── pages/
│   │   └── asm_review_detail_page_test.dart
│   ├── widgets/
│   │   ├── asm_review_excel_header_test.dart
│   │   ├── invoice_summary_section_test.dart
│   │   ├── invoice_documents_table_test.dart
│   │   └── campaign_details_table_test.dart
│   └── utils/
│       └── submission_data_transformer_test.dart
└── properties/
    └── asm_review_excel_layout_properties_test.dart
```

