# Bugfix Requirements Document

## Introduction

Multiple pages across the Flutter app produce RenderFlex overflow errors on narrow mobile screens (width ≲ 360 dp). The affected areas span 5 files across the login page, ASM/HQ review detail pages, and document table widgets. The root cause in each case is the use of fixed-width children or non-flexible Row layouts that exceed available horizontal space on narrow viewports. Additionally, the document tables use a 5-column `Table` layout with `FixedColumnWidth` values that make content unreadable on mobile — text wraps character-by-character and columns are too cramped to be legible.

Affected files:
1. `frontend/lib/features/auth/presentation/pages/new_login_page.dart` — tab row and "Remember me" / "Forgot password?" row
2. `frontend/lib/features/approval/presentation/pages/asm_review_detail_page.dart` — header reqNumber/date row
3. `frontend/lib/features/approval/presentation/pages/hq_review_detail_page.dart` — header reqNumber/date row
4. `frontend/lib/features/approval/presentation/widgets/invoice_documents_table.dart` — 5-column table layout
5. `frontend/lib/features/approval/presentation/widgets/campaign_details_table.dart` — 5-column table layout

## Bug Analysis

### Current Behavior (Defect)

**Login Page — Tab Row**

1.1 WHEN the login page is rendered on a narrow screen (width ≲ 360 dp) THEN the tab row overflows by approximately 58 pixels on the right, producing a yellow-black striped overflow warning.

1.2 WHEN the login page is rendered on a narrow screen THEN each individual tab item (Icon + SizedBox(width:6) + Text) overflows its `Expanded` allocation by approximately 3.1 pixels on the right.

**Login Page — Remember Me Row**

1.3 WHEN the login page is rendered on a narrow screen THEN the "Remember me" / "Forgot password?" row overflows by approximately 13 pixels on the right.

**ASM Review Detail Page — Header Row**

1.4 WHEN the ASM review detail page header is rendered on a narrow screen (constraint width ≈ 101.8 dp) THEN the Row containing reqNumber + SizedBox(width:16) + calendar icon + SizedBox(width:4) + date text overflows by approximately 111 pixels on the right.

**HQ Review Detail Page — Header Row**

1.5 WHEN the HQ review detail page header is rendered on a narrow screen (constraint width ≈ 154.7 dp) THEN the Row containing reqNumber + SizedBox(width:16) + calendar icon + SizedBox(width:4) + date text overflows by approximately 58 pixels on the right.

**Invoice Documents Table**

1.6 WHEN the invoice documents table is rendered on a mobile screen (width ≲ 400 dp) THEN the 5-column Table with FixedColumnWidth(60) for S.No and FixedColumnWidth(120) for Status causes document name cells to overflow by approximately 3.1 pixels, and all text content wraps character-by-character making it unreadable.

1.7 WHEN the invoice documents table header row is rendered on a mobile screen THEN the header text (S.No, Category, Document Name, Status, Remarks) wraps character-by-character in the cramped columns, making headers illegible.

**Campaign Details Table**

1.8 WHEN the campaign details table is rendered on a mobile screen (width ≲ 400 dp) THEN the identical 5-column Table layout causes the same 3.1 pixel overflow on document name cells and character-by-character text wrapping, making content unreadable.

1.9 WHEN the campaign details table header row is rendered on a mobile screen THEN the header text wraps character-by-character in the cramped columns, making headers illegible.

### Expected Behavior (Correct)

**Login Page — Tab Row**

2.1 WHEN the login page is rendered on a narrow screen (width ≲ 360 dp) THEN the tab row SHALL fit within the available width without any RenderFlex overflow, by allowing text to shrink or truncate gracefully.

2.2 WHEN the login page is rendered on a narrow screen THEN each individual tab item SHALL constrain its content (icon + text) within the space allocated by `Expanded`, using text ellipsis or flexible sizing as needed.

**Login Page — Remember Me Row**

2.3 WHEN the login page is rendered on a narrow screen THEN the "Remember me" / "Forgot password?" row SHALL wrap or flex its children to fit within the available width without overflow.

**ASM Review Detail Page — Header Row**

2.4 WHEN the ASM review detail page header is rendered on a narrow screen THEN the reqNumber and date information SHALL wrap to a second line or use flexible layout to fit within the available width without overflow, while remaining legible.

**HQ Review Detail Page — Header Row**

2.5 WHEN the HQ review detail page header is rendered on a narrow screen THEN the reqNumber and date information SHALL wrap to a second line or use flexible layout to fit within the available width without overflow, while remaining legible.

**Invoice Documents Table**

2.6 WHEN the invoice documents table is rendered on a mobile screen (width ≲ 400 dp) THEN the table SHALL either use horizontal scrolling or switch to a mobile-friendly layout (e.g., card-based) so that all content is legible and no overflow occurs.

2.7 WHEN the invoice documents table header is rendered on a mobile screen THEN the header text SHALL be fully readable without character-by-character wrapping.

**Campaign Details Table**

2.8 WHEN the campaign details table is rendered on a mobile screen (width ≲ 400 dp) THEN the table SHALL either use horizontal scrolling or switch to a mobile-friendly layout so that all content is legible and no overflow occurs.

2.9 WHEN the campaign details table header is rendered on a mobile screen THEN the header text SHALL be fully readable without character-by-character wrapping.

### Unchanged Behavior (Regression Prevention)

**Login Page**

3.1 WHEN the login page is rendered on a normal or wide screen (width ≥ 400 dp) THEN the tab row SHALL CONTINUE TO display all three tabs (Agency, ASM, HQ/RA) with icon and label fully visible, centered within each tab.

3.2 WHEN the login page is rendered on a normal or wide screen THEN the "Remember me" checkbox and "Forgot password?" link SHALL CONTINUE TO appear on the same row with space between them.

3.3 WHEN a user taps a role tab THEN the system SHALL CONTINUE TO switch the selected role, update credentials, and highlight the active tab with the blue underline indicator.

3.4 WHEN a user interacts with the "Remember me" checkbox or "Forgot password?" link THEN the system SHALL CONTINUE TO toggle the checkbox state or show the snackbar respectively.

**ASM / HQ Review Detail Pages**

3.5 WHEN the ASM or HQ review detail page header is rendered on a normal or wide screen (width ≥ 500 dp) THEN the reqNumber and date SHALL CONTINUE TO display on a single row with the calendar icon, maintaining the current visual layout.

3.6 WHEN a user taps the back button on the ASM or HQ review detail page THEN the system SHALL CONTINUE TO navigate back to the review list.

3.7 WHEN the ASM or HQ review detail page displays the status badge THEN the system SHALL CONTINUE TO show the correct status badge in the header area.

**Document Tables**

3.8 WHEN the invoice documents table or campaign details table is rendered on a wide screen (width ≥ 600 dp) THEN the tables SHALL CONTINUE TO display all 5 columns (S.No, Category, Document Name, Status, Remarks) in the current tabular layout with proper column widths.

3.9 WHEN a user taps a document name in either table THEN the system SHALL CONTINUE TO trigger the document tap callback to open/preview the document.

3.10 WHEN either table receives an empty document list THEN the system SHALL CONTINUE TO render nothing (SizedBox.shrink).
