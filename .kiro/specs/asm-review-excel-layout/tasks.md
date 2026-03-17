# Implementation Plan: ASM Review Page Excel-Based Layout

## Overview

This implementation plan transforms the ASM Review Detail Page from a document card layout to an Excel-based tabular layout. The approach creates reusable data models and widgets, implements data transformation utilities, and refactors the main page to use the new component hierarchy while preserving all existing workflow functionality.

## Tasks

- [x] 1. Create data models for table structures
  - [x] 1.1 Create ValidationStatus enum and InvoiceDocumentRow model
    - Create `frontend/lib/features/approval/data/models/invoice_document_row.dart`
    - Define `ValidationStatus` enum with `ok` and `failed` values
    - Define `InvoiceDocumentRow` class with serialNumber, category, documentName, status, remarks, blobUrl
    - _Requirements: 3.3, 3.4_

  - [x] 1.2 Create CampaignDetailRow model
    - Create `frontend/lib/features/approval/data/models/campaign_detail_row.dart`
    - Define `CampaignDetailRow` class with serialNumber, dealerName, campaignDate, documentName, status, remarks, blobUrl, isFirstInGroup
    - _Requirements: 4.3, 4.4, 4.9_

  - [x] 1.3 Create InvoiceSummaryData model
    - Create `frontend/lib/features/approval/data/models/invoice_summary_data.dart`
    - Define `InvoiceSummaryData` class with invoiceAmount, agencyName, submittedDate
    - Include `InvoiceSummaryData.empty()` factory for missing data handling
    - _Requirements: 2.2, 2.3, 2.4, 2.5_

- [x] 2. Create data transformation utility
  - [x] 2.1 Create SubmissionDataTransformer class
    - Create `frontend/lib/features/approval/presentation/utils/submission_data_transformer.dart`
    - Implement `extractInvoiceSummary()` to extract invoice amount, agency name, submission date
    - Implement `transformToInvoiceDocuments()` to convert documents to InvoiceDocumentRow list
    - Implement `transformToCampaignDetails()` to convert photos to CampaignDetailRow list grouped by dealer
    - Include helper methods for date formatting and validation lookup
    - _Requirements: 2.2, 2.3, 2.4, 2.5, 3.3, 3.4, 3.5, 4.3, 4.4, 4.5, 4.6_

  - [ ]* 2.2 Write property test for invoice summary extraction (Property 3)
    - **Property 3: Invoice Summary Data Extraction**
    - Test that submissions with invoice documents correctly extract amount, agency, date
    - **Validates: Requirements 2.2, 2.3, 2.4**

  - [ ]* 2.3 Write property test for missing data handling (Property 4)
    - **Property 4: Missing Data Handling**
    - Test that missing invoice data, agency name, or submission date returns "N/A"
    - **Validates: Requirements 2.5**

  - [ ]* 2.4 Write property test for document type transformation (Property 5)
    - **Property 5: Document Type to Table Row Transformation**
    - Test that Invoice, PO, Cost Summary documents each appear as exactly one row
    - **Validates: Requirements 3.3**

  - [ ]* 2.5 Write property test for validation status values (Property 6)
    - **Property 6: Validation Status Values**
    - Test that all rows have status of exactly "ok" or "failed"
    - **Validates: Requirements 3.4, 4.5**

  - [ ]* 2.6 Write property test for photo dealer grouping (Property 9)
    - **Property 9: Photo Dealer Grouping and Naming**
    - Test that photos are grouped by dealer with sequential Pic1, Pic2 naming
    - **Validates: Requirements 4.3, 4.4**

  - [ ]* 2.7 Write property test for dealer visual grouping indicator (Property 10)
    - **Property 10: Dealer Visual Grouping Indicator**
    - Test that first row of each dealer group has isFirstInGroup = true
    - **Validates: Requirements 4.9**

- [x] 3. Checkpoint - Ensure data models and transformer tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Create ASMReviewExcelHeader widget
  - [x] 4.1 Implement ASMReviewExcelHeader widget
    - Create `frontend/lib/features/approval/presentation/widgets/asm_review_excel_header.dart`
    - Display back button, FAP ID, status badge
    - Display Approve FAP and Reject FAP action buttons
    - Disable buttons and show loading indicator when isProcessing is true
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

  - [ ]* 4.2 Write property test for button disabled state (Property 1)
    - **Property 1: Button Disabled State During Processing**
    - Test that when isProcessing is true, both buttons are disabled
    - **Validates: Requirements 1.5**

- [x] 5. Create InvoiceSummarySection widget
  - [x] 5.1 Implement InvoiceSummarySection widget
    - Create `frontend/lib/features/approval/presentation/widgets/invoice_summary_section.dart`
    - Display invoice amount, agency name, submitted date in card format
    - Handle "N/A" display for missing data
    - Use responsive layout (horizontal on desktop, vertical on mobile)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

- [x] 6. Create InvoiceDocumentsTable widget
  - [x] 6.1 Implement InvoiceDocumentsTable widget
    - Create `frontend/lib/features/approval/presentation/widgets/invoice_documents_table.dart`
    - Display table with columns: S.No, Category, Document Name, Status, Remarks
    - Apply alternating row colors (white/background)
    - Handle document tap callback for viewing/download
    - Support horizontal scrolling on mobile
    - _Requirements: 3.1, 3.2, 3.4, 3.5, 3.6, 3.7_

  - [ ]* 6.2 Write property test for alternating row colors (Property 8)
    - **Property 8: Alternating Row Colors**
    - Test that even rows are white, odd rows are background color
    - **Validates: Requirements 3.7, 4.8**

- [x] 7. Create CampaignDetailsTable widget
  - [x] 7.1 Implement CampaignDetailsTable widget
    - Create `frontend/lib/features/approval/presentation/widgets/campaign_details_table.dart`
    - Display table with columns: S.No, Dealer Name, Campaign Date, Document Name, Status, Remarks
    - Apply alternating row colors
    - Visual grouping for dealer rows (using isFirstInGroup)
    - Handle photo tap callback for viewing
    - Support horizontal scrolling on mobile
    - _Requirements: 4.1, 4.2, 4.5, 4.6, 4.7, 4.8, 4.9_

- [x] 8. Create HQRejectionSection widget
  - [x] 8.1 Extract HQRejectionSection widget from existing code
    - Create `frontend/lib/features/approval/presentation/widgets/hq_rejection_section.dart`
    - Extract existing `_buildHQRejectionSection()` logic into standalone widget
    - Display HQ rejection reason and date
    - Include Resubmit to HQ button with dialog
    - _Requirements: 6.3, 6.4_

  - [ ]* 8.2 Write property test for HQ rejection section visibility (Property 14)
    - **Property 14: HQ Rejection Section Visibility**
    - Test that section is visible only when state is "RejectedByHQ"
    - **Validates: Requirements 6.4**

- [x] 9. Checkpoint - Ensure all widget tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Refactor ASMReviewDetailPage to use new components
  - [x] 10.1 Update imports and add data transformation
    - Import new data models and widgets
    - Add data transformation in `_loadSubmissionDetails()` to create InvoiceSummaryData, InvoiceDocumentRow list, CampaignDetailRow list
    - Store transformed data in state variables
    - _Requirements: 2.1, 3.1, 4.1_

  - [x] 10.2 Replace build method with new component hierarchy
    - Replace `_buildHeader()` with ASMReviewExcelHeader widget
    - Add InvoiceSummarySection below header
    - Replace `_buildDocumentSections()` with InvoiceDocumentsTable
    - Add CampaignDetailsTable for photos
    - Replace `_buildHQRejectionSection()` with HQRejectionSection widget
    - _Requirements: 1.1, 1.2, 2.1, 3.1, 4.1, 6.4_

  - [x] 10.3 Remove legacy methods and components
    - Remove `_buildAIQuickSummary()`
    - Remove `_buildDocumentSections()`, `_buildDocumentSectionFromData()`, `_buildPhotosSectionFromData()`
    - Remove `_buildDocumentSection()`, `_buildPhotoCard()`, `_buildAnalysisPoint()`
    - Remove `_buildAIAnalysisTable()`, `_buildDocumentDataTable()`, `_buildDocumentDataTableFromAnalysis()`
    - Remove `_buildReviewDecisionPanel()`, `_buildSummaryPoint()`
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [x] 10.4 Implement rejection dialog with validation
    - Create rejection reason dialog triggered by Reject FAP button
    - Validate rejection reason is not empty or whitespace-only
    - Display error message if validation fails
    - _Requirements: 1.4, 1.6_

  - [ ]* 10.5 Write property test for rejection reason validation (Property 2)
    - **Property 2: Rejection Reason Validation**
    - Test that empty or whitespace-only strings are rejected
    - **Validates: Requirements 1.6**

- [x] 11. Implement responsive design
  - [x] 11.1 Add responsive layout handling
    - Use LayoutBuilder to detect screen width
    - Apply mobile layout (< 600px): vertical stacking, horizontal scroll for tables
    - Apply tablet layout (600-900px): optimized column widths
    - Apply desktop layout (> 900px): full table display without horizontal scroll
    - Ensure action buttons remain accessible on all screen sizes
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

  - [ ]* 11.2 Write property test for mobile horizontal scroll (Property 11)
    - **Property 11: Mobile Horizontal Scroll**
    - Test that tables are wrapped in horizontal scroll on screens < 600px
    - **Validates: Requirements 5.2**

  - [ ]* 11.3 Write property test for desktop full table display (Property 12)
    - **Property 12: Desktop Full Table Display**
    - Test that tables display without horizontal scroll on screens > 900px
    - **Validates: Requirements 5.4**

  - [ ]* 11.4 Write property test for action buttons accessibility (Property 13)
    - **Property 13: Action Buttons Accessibility**
    - Test that action buttons are visible on all screen sizes
    - **Validates: Requirements 5.5**

- [x] 12. Verify workflow functionality preservation
  - [x] 12.1 Verify ASM approval workflow
    - Test that Approve FAP button triggers approval API call
    - Test that success navigates back to review list
    - Test that error displays notification
    - _Requirements: 6.1, 6.5, 6.6_

  - [x] 12.2 Verify ASM rejection workflow
    - Test that Reject FAP button shows rejection dialog
    - Test that rejection with reason triggers rejection API call
    - Test that success navigates back to review list
    - _Requirements: 6.2, 6.5, 6.6_

  - [x] 12.3 Verify HQ resubmit workflow
    - Test that Resubmit to HQ button shows notes dialog
    - Test that resubmit with notes triggers resubmit API call
    - Test that success navigates back to review list
    - _Requirements: 6.3, 6.4, 6.5, 6.6_

  - [ ]* 12.4 Write property test for workflow action notifications (Property 15)
    - **Property 15: Workflow Action Notifications**
    - Test that all workflow actions display success/error notifications
    - **Validates: Requirements 6.5**

- [x] 13. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- The existing API integration code is preserved and reused
- Widget extraction follows Flutter best practices (one widget per file, < 300 lines)
