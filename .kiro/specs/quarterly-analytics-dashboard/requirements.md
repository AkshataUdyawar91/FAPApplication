# Requirements Document

## Introduction

This feature expands the ASM and HQ/RA review pages to match the Agency dashboard's layout pattern (sidebar navigation, AI chat panel), adds quarterly FAP KPI tracking with quarter/year filters to both pages, and rebrands all "HQ" labels to "HQ/RA" throughout the application. The goal is a consistent user experience across all three role-based dashboards with simple quarterly analytics.

## Glossary

- **Agency_Dashboard**: The existing Agency user dashboard page that serves as the reference implementation for layout, sidebar, and chat panel patterns
- **ASM_Page**: The Area Sales Manager review page that currently has a simple header layout without sidebar or chat panel
- **HQRA_Page**: The HQ/RA review page (formerly labeled "HQ") that currently has a simple header layout without sidebar or chat panel
- **Sidebar**: A navigation panel displayed on the left side of the page on desktop/tablet viewports, containing nav items (Dashboard, Notifications, Settings) and user info
- **Drawer**: A slide-out navigation panel used on mobile viewports, containing the same nav items as the Sidebar
- **Chat_Panel**: An AI assistant chat interface displayed as a side panel on desktop/tablet or as an end drawer on mobile, matching the Agency_Dashboard chat implementation
- **Chat_FAB**: A floating action button that toggles the Chat_Panel visibility
- **FAP**: Free After Performance — a type of invoice/PO representing promotional spend; identified by Invoice documents within approved DocumentPackages
- **FAP_Amount**: The total monetary value (TotalAmount) extracted from Invoice documents within approved DocumentPackages
- **FAP_Count**: The number of distinct approved DocumentPackages containing at least one Invoice document
- **Quarter**: A fiscal quarter (Q1: Jan–Mar, Q2: Apr–Jun, Q3: Jul–Sep, Q4: Oct–Dec) derived from the DocumentPackage CreatedAt timestamp
- **Quarter_Filter**: A UI dropdown allowing the user to select a specific quarter (Q1, Q2, Q3, Q4, or All)
- **Year_Filter**: A UI dropdown allowing the user to select a specific year (e.g., 2024, 2025, 2026)
- **KPI_Card**: A summary card displaying a single metric (FAP_Amount or FAP_Count) with its numeric value
- **Analytics_API**: The backend REST API endpoint serving quarterly FAP aggregation data
- **Rebrand**: The process of replacing all "HQ" labels in the UI with "HQ/RA"

## Requirements

### Requirement 1: Rebrand HQ to HQ/RA

**User Story:** As a developer, I want all "HQ" labels replaced with "HQ/RA" throughout the application, so that the UI reflects the correct role name.

#### Acceptance Criteria

1. THE Application SHALL display "HQ/RA" in place of "HQ" on the login page role selector
2. THE Application SHALL display "HQ/RA" in place of "HQ" in the HQRA_Page header and navigation labels
3. THE Application SHALL display "HQ/RA" in place of "HQ" in the ASM_Page status labels that reference HQ (e.g., "With HQ" becomes "With HQ/RA")
4. THE Application SHALL display "HQ/RA" in place of "HQ" in any notification text, toast messages, or status badges that reference the HQ role

### Requirement 2: ASM Page Layout Restructure

**User Story:** As an ASM user, I want the ASM review page to have a sidebar and consistent navigation, so that the experience matches the Agency dashboard.

#### Acceptance Criteria

1. THE ASM_Page SHALL display a Sidebar on desktop and tablet viewports with nav items: Dashboard, Notifications, Settings
2. WHEN the viewport is mobile, THE ASM_Page SHALL replace the Sidebar with a Drawer accessible via a hamburger menu icon in the app bar
3. THE ASM_Page Sidebar SHALL display the Bajaj logo, user name, user role, and a logout button matching the Agency_Dashboard Sidebar layout
4. THE ASM_Page SHALL display a header bar with the page title "ASM Review" on desktop and tablet viewports
5. WHEN the ASM_Page loads, THE ASM_Page SHALL display the existing stats cards, filters, and document table below the header

### Requirement 3: HQ/RA Page Layout Restructure

**User Story:** As an HQ/RA user, I want the HQ/RA review page to have a sidebar and consistent navigation, so that the experience matches the Agency dashboard.

#### Acceptance Criteria

1. THE HQRA_Page SHALL display a Sidebar on desktop and tablet viewports with nav items: Dashboard, Notifications, Settings
2. WHEN the viewport is mobile, THE HQRA_Page SHALL replace the Sidebar with a Drawer accessible via a hamburger menu icon in the app bar
3. THE HQRA_Page Sidebar SHALL display the Bajaj logo, user name, user role ("HQ/RA"), and a logout button matching the Agency_Dashboard Sidebar layout
4. THE HQRA_Page SHALL display a header bar with the page title "HQ/RA Review" on desktop and tablet viewports
5. WHEN the HQRA_Page loads, THE HQRA_Page SHALL display the existing stats cards, filters, and document table below the header

### Requirement 4: AI Chat Panel on ASM Page

**User Story:** As an ASM user, I want an AI chat assistant panel on the ASM review page, so that I can ask questions about submissions without leaving the page.

#### Acceptance Criteria

1. THE ASM_Page SHALL display a Chat_FAB when the Chat_Panel is closed
2. WHEN the user taps the Chat_FAB on desktop or tablet, THE ASM_Page SHALL open the Chat_Panel as a side panel on the right
3. WHEN the user taps the Chat_FAB on mobile, THE ASM_Page SHALL open the Chat_Panel as an end drawer
4. THE Chat_Panel on the ASM_Page SHALL provide the same chat functionality as the Agency_Dashboard Chat_Panel (send messages, display responses, loading states)
5. WHEN the Chat_Panel is open on desktop or tablet, THE ASM_Page SHALL hide the Chat_FAB

### Requirement 5: AI Chat Panel on HQ/RA Page

**User Story:** As an HQ/RA user, I want an AI chat assistant panel on the HQ/RA review page, so that I can ask questions about submissions without leaving the page.

#### Acceptance Criteria

1. THE HQRA_Page SHALL display a Chat_FAB when the Chat_Panel is closed
2. WHEN the user taps the Chat_FAB on desktop or tablet, THE HQRA_Page SHALL open the Chat_Panel as a side panel on the right
3. WHEN the user taps the Chat_FAB on mobile, THE HQRA_Page SHALL open the Chat_Panel as an end drawer
4. THE Chat_Panel on the HQRA_Page SHALL provide the same chat functionality as the Agency_Dashboard Chat_Panel (send messages, display responses, loading states)
5. WHEN the Chat_Panel is open on desktop or tablet, THE HQRA_Page SHALL hide the Chat_FAB

### Requirement 6: Quarterly FAP KPI Aggregation API

**User Story:** As an ASM or HQ/RA user, I want the backend to aggregate FAP totals by quarter, so that the dashboard can display quarterly KPIs.

#### Acceptance Criteria

1. WHEN a user requests quarterly KPI data with a quarter and year, THE Analytics_API SHALL return FAP_Amount and FAP_Count for the specified quarter and year
2. WHEN a user requests quarterly KPI data with year only (quarter set to "All"), THE Analytics_API SHALL return FAP_Amount and FAP_Count aggregated across all quarters for that year
3. THE Analytics_API SHALL compute FAP_Amount by summing the TotalAmount from extracted Invoice data of approved DocumentPackages
4. THE Analytics_API SHALL compute FAP_Count by counting distinct approved DocumentPackages that contain at least one Invoice document
5. THE Analytics_API SHALL assign each DocumentPackage to a quarter based on the CreatedAt timestamp using calendar quarters (Q1: Jan–Mar, Q2: Apr–Jun, Q3: Jul–Sep, Q4: Oct–Dec)
6. THE Analytics_API SHALL include only DocumentPackages with State equal to Approved when computing FAP_Amount and FAP_Count
7. IF no DocumentPackages match the applied filters, THEN THE Analytics_API SHALL return zero for both FAP_Amount and FAP_Count
8. THE Analytics_API SHALL require authentication with ASM or HQ role for authorization
9. THE Analytics_API SHALL return results within 3 seconds for the full dataset

### Requirement 7: Quarterly KPI Display on ASM Page

**User Story:** As an ASM user, I want to see quarterly FAP KPI cards on my review page, so that I can monitor FAP spend and volume at a glance.

#### Acceptance Criteria

1. THE ASM_Page SHALL display two KPI_Cards above the existing document table: one for total FAP_Amount and one for FAP_Count
2. THE ASM_Page SHALL display a Quarter_Filter dropdown with options: Q1, Q2, Q3, Q4, All
3. THE ASM_Page SHALL display a Year_Filter dropdown populated with available years (e.g., 2024, 2025, 2026)
4. WHEN the ASM_Page loads, THE ASM_Page SHALL default the Quarter_Filter to the current quarter and the Year_Filter to the current year
5. WHEN the user changes the Quarter_Filter or Year_Filter, THE ASM_Page SHALL re-fetch and update the KPI_Cards with the filtered data
6. WHILE KPI data is loading, THE ASM_Page SHALL display a loading skeleton placeholder for each KPI_Card
7. IF the Analytics_API returns an error, THEN THE ASM_Page SHALL display a user-friendly error message with a retry button
8. THE ASM_Page SHALL format FAP_Amount as Indian currency (₹) with comma-separated thousands

### Requirement 8: Quarterly KPI Display on HQ/RA Page

**User Story:** As an HQ/RA user, I want to see quarterly FAP KPI cards on my review page, so that I can monitor FAP spend and volume at a glance.

#### Acceptance Criteria

1. THE HQRA_Page SHALL display two KPI_Cards above the existing document table: one for total FAP_Amount and one for FAP_Count
2. THE HQRA_Page SHALL display a Quarter_Filter dropdown with options: Q1, Q2, Q3, Q4, All
3. THE HQRA_Page SHALL display a Year_Filter dropdown populated with available years (e.g., 2024, 2025, 2026)
4. WHEN the HQRA_Page loads, THE HQRA_Page SHALL default the Quarter_Filter to the current quarter and the Year_Filter to the current year
5. WHEN the user changes the Quarter_Filter or Year_Filter, THE HQRA_Page SHALL re-fetch and update the KPI_Cards with the filtered data
6. WHILE KPI data is loading, THE HQRA_Page SHALL display a loading skeleton placeholder for each KPI_Card
7. IF the Analytics_API returns an error, THEN THE HQRA_Page SHALL display a user-friendly error message with a retry button
8. THE HQRA_Page SHALL format FAP_Amount as Indian currency (₹) with comma-separated thousands

### Requirement 9: Quarterly Data Aggregation Correctness

**User Story:** As an ASM or HQ/RA user, I want the quarterly aggregation to be accurate, so that I can trust the KPI numbers for decision-making.

#### Acceptance Criteria

1. THE Analytics_API SHALL extract FAP_Amount from the TotalAmount field of the deserialized Invoice ExtractedDataJson on each Document of type Invoice within the package
2. FOR ALL quarterly aggregations, the sum of per-quarter FAP_Amounts for a given year SHALL equal the total FAP_Amount when Quarter_Filter is set to "All" for that year (additive consistency)
3. FOR ALL quarterly aggregations, the sum of per-quarter FAP_Counts for a given year SHALL equal the total FAP_Count when Quarter_Filter is set to "All" for that year (additive consistency)
