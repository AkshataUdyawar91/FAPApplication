# Implementation Plan: Quarterly Analytics Dashboard

## Overview

This plan implements the quarterly analytics dashboard feature in three phases: (1) HQ → HQ/RA rebranding across frontend files, (2) extracting shared widgets from the Agency dashboard and restructuring ASM/HQ pages to use them, (3) adding the backend quarterly FAP KPI endpoint and wiring KPI cards with filters into both pages. Property-based tests validate aggregation correctness throughout.

## Tasks

- [x] 1. Rebrand HQ to HQ/RA across frontend
  - [x] 1.1 Replace "HQ" display strings with "HQ/RA" in all affected frontend files
    - Update `frontend/lib/features/auth/presentation/pages/new_login_page.dart`: `'HQ'` → `'HQ/RA'` in role tab label
    - Update `frontend/lib/features/approval/presentation/pages/asm_review_page.dart`: `'With HQ'` → `'With HQ/RA'` in status dropdown
    - Update `frontend/lib/features/approval/presentation/pages/hq_review_page.dart`: `'Pending HQ Review'` → `'Pending HQ/RA Review'` in stat cards, status dropdown, status badge; page title to `'HQ/RA Review'`
    - Update `frontend/lib/features/approval/presentation/pages/hq_review_detail_page.dart`: `'Pending HQ Review'` → `'Pending HQ/RA Review'` in status badge
    - Update `frontend/lib/features/submission/presentation/pages/agency_dashboard_page.dart`: `'Pending HQ Approval'` → `'Pending HQ/RA Approval'` in status badge
    - Update `frontend/lib/features/submission/presentation/pages/agency_submission_detail_page.dart`: `'HQ'` → `'HQ/RA'` in rejection card label
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 2. Extract shared widgets from Agency dashboard
  - [x] 2.1 Create `AppSidebar` widget in `frontend/lib/core/widgets/app_sidebar.dart`
    - Extract sidebar logic from `agency_dashboard_page.dart` `_buildSidebar` method
    - Parameterize with `userName`, `userRole`, `navItems` (List\<NavItem\>), `onLogout`, `isCollapsed`
    - Create `NavItem` model class in `frontend/lib/core/widgets/nav_item.dart`
    - _Requirements: 2.1, 2.3, 3.1, 3.3_

  - [x] 2.2 Create `AppDrawer` widget in `frontend/lib/core/widgets/app_drawer.dart`
    - Extract drawer logic from `agency_dashboard_page.dart` `_buildDrawer` method
    - Parameterize with `userName`, `userRole`, `navItems`, `onLogout`
    - _Requirements: 2.2, 3.2_

  - [x] 2.3 Create `ChatSidePanel` widget in `frontend/lib/core/widgets/chat_side_panel.dart`
    - Extract chat panel logic from `agency_dashboard_page.dart` `_buildChatPanel` and `_buildChatContent`
    - Parameterize with `token`, `deviceType`, `onClose`
    - Manage internal chat state (messages, sending state, text controller)
    - _Requirements: 4.2, 4.4, 5.2, 5.4_

  - [x] 2.4 Create `ChatEndDrawer` widget in `frontend/lib/core/widgets/chat_end_drawer.dart`
    - Extract end drawer logic from `agency_dashboard_page.dart` `_buildChatDrawer`
    - Wrap `ChatSidePanel` content in a `Drawer` widget
    - _Requirements: 4.3, 5.3_

  - [x] 2.5 Create `KpiCard` widget in `frontend/lib/core/widgets/kpi_card.dart`
    - Reusable card displaying label, formatted value, icon, and color
    - Support loading skeleton state via an `isLoading` flag
    - _Requirements: 7.1, 7.6, 8.1, 8.6_

  - [x] 2.6 Create `QuarterYearFilter` widget in `frontend/lib/core/widgets/quarter_year_filter.dart`
    - Row of two dropdowns: Quarter (Q1, Q2, Q3, Q4, All) and Year
    - Props: `selectedQuarter`, `selectedYear`, `onQuarterChanged`, `onYearChanged`, `availableYears`
    - Default to current quarter and current year
    - _Requirements: 7.2, 7.3, 7.4, 8.2, 8.3, 8.4_

  - [x] 2.7 Refactor `agency_dashboard_page.dart` to use the new shared widgets
    - Replace inline sidebar/drawer/chat panel code with `AppSidebar`, `AppDrawer`, `ChatSidePanel`, `ChatEndDrawer`
    - Verify Agency dashboard behavior is unchanged after refactor
    - _Requirements: 2.1, 2.2 (ensures shared widgets work correctly in the reference implementation)_

- [x] 3. Checkpoint - Verify shared widgets and rebrand
  - Ensure `flutter analyze` passes with no errors
  - Ensure the Agency dashboard renders correctly with extracted shared widgets
  - Ensure all "HQ" labels now show "HQ/RA"
  - Ask the user if questions arise

- [x] 4. Restructure ASM page layout
  - [x] 4.1 Restructure `asm_review_page.dart` to use shared sidebar, drawer, and chat panel
    - Add `AppSidebar` on desktop/tablet with nav items: Dashboard, Notifications, Settings
    - Add `AppDrawer` on mobile with hamburger menu in app bar
    - Add `ChatSidePanel` on desktop/tablet, `ChatEndDrawer` on mobile
    - Add `ChatFAB` toggle (hidden when chat panel is open on desktop/tablet)
    - Display header bar with "ASM Review" title on desktop/tablet
    - Preserve existing stats cards, filters, and document table below the header
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 5. Restructure HQ/RA page layout
  - [x] 5.1 Restructure `hq_review_page.dart` to use shared sidebar, drawer, and chat panel
    - Add `AppSidebar` on desktop/tablet with nav items: Dashboard, Notifications, Settings
    - Add `AppDrawer` on mobile with hamburger menu in app bar
    - Add `ChatSidePanel` on desktop/tablet, `ChatEndDrawer` on mobile
    - Add `ChatFAB` toggle (hidden when chat panel is open on desktop/tablet)
    - Display header bar with "HQ/RA Review" title on desktop/tablet
    - Preserve existing stats cards, filters, and document table below the header
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 6. Checkpoint - Verify page restructures
  - Ensure `flutter analyze` passes with no errors
  - Ensure ASM and HQ/RA pages render sidebar, drawer, and chat panel correctly
  - Ask the user if questions arise

- [x] 7. Backend: Quarterly FAP KPI endpoint
  - [x] 7.1 Create `QuarterlyFapKpiResponse` DTO
    - Create `backend/src/BajajDocumentProcessing.Application/DTOs/Analytics/QuarterlyFapKpiResponse.cs`
    - Properties: `Quarter` (string), `Year` (int), `FapAmount` (decimal), `FapCount` (int)
    - _Requirements: 6.1, 6.2_

  - [x] 7.2 Add `GetQuarterlyFapKpisAsync` to `IAnalyticsAgent` interface and implement in `AnalyticsAgent`
    - Add method signature to `backend/src/BajajDocumentProcessing.Application/Common/Interfaces/IAnalyticsAgent.cs`
    - Implement in `backend/src/BajajDocumentProcessing.Infrastructure/Services/AnalyticsAgent.cs`
    - Create a helper method for quarter-to-date-range mapping (Q1: Jan 1–Mar 31, etc.)
    - Query: filter `DocumentPackages` by `State == Approved`, `IsDeleted == false`, date range
    - Include `Documents` of type `Invoice`, deserialize `ExtractedDataJson` to extract `TotalAmount`
    - Handle null/malformed `ExtractedDataJson` gracefully (treat as 0)
    - Sum `TotalAmount` → `FapAmount`; count distinct packages with invoices → `FapCount`
    - Add stub implementation to `NullAnalyticsAgent` returning zeros
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 9.1_

  - [x] 7.3 Add `GetQuarterlyFapKpis` endpoint to `AnalyticsController`
    - Add `[HttpGet("quarterly-fap")]` action method to `backend/src/BajajDocumentProcessing.API/Controllers/AnalyticsController.cs`
    - Accept `[FromQuery] string quarter = "current"` and `[FromQuery] int year = currentYear`
    - Add `[Authorize(Roles = "ASM,HQ")]` at action level to override controller-level auth
    - Validate quarter (Q1–Q4 or All) and year (2000–currentYear+1); return 400 for invalid input
    - Pass `CancellationToken` through to service
    - _Requirements: 6.1, 6.2, 6.8_

  - [ ]* 7.4 Write property test: Quarter Assignment Correctness
    - **Property 1: Quarter Assignment Correctness**
    - Create `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/QuarterAssignmentProperties.cs`
    - Generate random `DateTime` values; verify Jan–Mar → Q1, Apr–Jun → Q2, Jul–Sep → Q3, Oct–Dec → Q4
    - Verify year component matches the DateTime's year
    - FsCheck with `MaxTest = 100`
    - **Validates: Requirements 6.5, 7.4, 8.4**

  - [ ]* 7.5 Write property test: FAP Aggregation Correctness
    - **Property 2: FAP Aggregation Correctness**
    - Create `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/FapAggregationProperties.cs`
    - Generate random lists of `DocumentPackage` with varying states, dates, and Invoice documents with random `TotalAmount`
    - Verify only `Approved` + `IsDeleted == false` packages contribute; verify `FapAmount` and `FapCount` match expected
    - FsCheck with `MaxTest = 100`
    - **Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.6**

  - [ ]* 7.6 Write property test: Additive Consistency Across Quarters
    - **Property 5: Additive Consistency Across Quarters**
    - Create `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/FapAdditiveConsistencyProperties.cs`
    - Generate random approved packages within a single year; verify sum of Q1+Q2+Q3+Q4 FapAmount equals "All" FapAmount; same for FapCount
    - FsCheck with `MaxTest = 100`
    - **Validates: Requirements 9.2, 9.3**

  - [ ]* 7.7 Write property test: Invoice TotalAmount Extraction Round-Trip
    - **Property 4: Invoice TotalAmount Extraction Round-Trip**
    - Create `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/InvoiceTotalAmountExtractionProperties.cs`
    - Generate random `decimal` values, serialize to JSON, deserialize and extract `TotalAmount`; verify round-trip equality
    - Test null and malformed JSON returns 0
    - FsCheck with `MaxTest = 100`
    - **Validates: Requirements 9.1**

  - [ ]* 7.8 Write unit tests for quarterly FAP endpoint
    - Create `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/QuarterlyFapKpiTests.cs`
    - Test: returns correct shape with known data, returns 400 for invalid quarter, returns zeros when no data, ignores deleted packages, handles null `ExtractedDataJson`
    - Use Moq to mock `IAnalyticsAgent`
    - _Requirements: 6.1, 6.2, 6.7_

- [x] 8. Checkpoint - Verify backend endpoint and tests
  - Run `dotnet build` and `dotnet test` to ensure all backend tests pass
  - Ask the user if questions arise

- [x] 9. Frontend: Quarterly KPI integration on ASM page
  - [x] 9.1 Create `QuarterlyFapKpi` model and datasource method
    - Create `frontend/lib/features/analytics/data/models/quarterly_fap_kpi_model.dart` with `fromJson` factory
    - Add `getQuarterlyFapKpis(String quarter, int year)` method to `analytics_remote_datasource.dart`
    - Call `GET /api/analytics/quarterly-fap?quarter={quarter}&year={year}`
    - _Requirements: 6.1, 6.2_

  - [x] 9.2 Create Indian currency formatting utility
    - Create `frontend/lib/core/utils/currency_formatter.dart`
    - Implement `formatIndianCurrency(double amount)` returning `₹X,XX,XXX.XX` format
    - _Requirements: 7.8, 8.8_

  - [x] 9.3 Add KPI cards and quarter/year filter to ASM review page
    - Add `QuarterYearFilter` widget above the document table
    - Add two `KpiCard` widgets: FAP Amount (formatted as Indian currency) and FAP Count
    - Default quarter to current quarter, year to current year on page load
    - Re-fetch KPI data when filter changes
    - Show skeleton loading placeholders while loading
    - Show error message with retry button on API error
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8_

- [x] 10. Frontend: Quarterly KPI integration on HQ/RA page
  - [x] 10.1 Add KPI cards and quarter/year filter to HQ/RA review page
    - Add `QuarterYearFilter` widget above the document table
    - Add two `KpiCard` widgets: FAP Amount (formatted as Indian currency) and FAP Count
    - Default quarter to current quarter, year to current year on page load
    - Re-fetch KPI data when filter changes
    - Show skeleton loading placeholders while loading
    - Show error message with retry button on API error
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8_

- [ ] 11. Frontend: Indian currency formatting property test
  - [ ]* 11.1 Write property test: Indian Currency Formatting
    - **Property 3: Indian Currency Formatting**
    - Create a Dart test in `frontend/test/core/utils/currency_formatter_test.dart`
    - Generate random non-negative doubles; verify output starts with "₹" and follows Indian grouping (3 from right, then groups of 2)
    - **Validates: Requirements 7.8, 8.8**

- [x] 12. Final checkpoint - Full integration verification
  - Run `dotnet test` to ensure all backend tests pass
  - Run `flutter analyze` to ensure no frontend errors
  - Ensure ASM and HQ/RA pages display KPI cards with correct data from the API
  - Ensure quarter/year filter dropdowns update KPI values on change
  - Ask the user if questions arise

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Property tests validate universal correctness properties from the design document
- The rebrand (task 1) is done first since it's a simple string change with no dependencies
- Shared widget extraction (task 2) must complete before page restructures (tasks 4–5)
- Backend endpoint (task 7) must be ready before frontend KPI integration (tasks 9–10)
