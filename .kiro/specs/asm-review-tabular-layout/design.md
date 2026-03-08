# ASM Review Tabular Layout Bugfix Design

## Overview

This design document specifies the conversion of the ASM review detail page from a card-based vertical layout to a structured tabular format. The current implementation displays document information, AI analysis results, and validation details in card sections with bullet points and inline text. The fix will reorganize this information into structured tables with clearly defined columns and rows for better data organization and readability.

Additionally, the comments field in the Review Decision section will be explicitly marked as non-mandatory by removing any visual indicators that suggest it is required.

All existing functionality (approval/rejection workflows, document downloads, confidence scoring, HQ rejection handling, navigation) will be preserved without modification.

## Glossary

- **Bug_Condition (C)**: The condition where the ASM review detail page displays information in card-based layout instead of tabular format
- **Property (P)**: The desired behavior where information is displayed in structured tables with clear row-column organization
- **Preservation**: All existing functionality (approval workflows, downloads, scoring, navigation) that must remain unchanged
- **ASMReviewDetailPage**: The StatefulWidget in `frontend/lib/features/approval/presentation/pages/asm_review_detail_page.dart` that displays submission details for ASM review
- **Card-based layout**: Current UI pattern using Card widgets with vertical stacking and bullet points
- **Tabular layout**: Target UI pattern using Table or DataTable widgets with structured rows and columns
- **AI Analysis Summary**: The section displaying verification points and AI-generated insights
- **Extracted Document Data**: The parsed data from PO, Invoice, and Cost Summary documents
- **Confidence Score**: Percentage value (0-100) indicating AI confidence in document validation

## Bug Details

### Bug Condition

The bug manifests when an ASM views the review detail page for a submission. The page displays document information in a card-based vertical layout with separate Card widgets for each document type. AI analysis results appear as bullet points within colored containers, and extracted document data is shown as inline text within card sections rather than in a structured table format.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type PageRenderContext
  OUTPUT: boolean
  
  RETURN input.page == 'ASMReviewDetailPage'
         AND input.aiAnalysisSection.displayFormat == 'bullet-points-in-card'
         AND input.documentDataSection.displayFormat == 'inline-text-in-card'
         AND NOT input.aiAnalysisSection.displayFormat == 'table-with-columns'
         AND NOT input.documentDataSection.displayFormat == 'table-with-rows'
END FUNCTION
```

### Examples

- **AI Analysis Section**: Currently displays verification points as bullet points with check icons in a colored container. Should display as a table with columns: "Check Item", "Status", "Details".

- **PO Document Data**: Currently displays "PO Number PO12345 verified" as inline text. Should display as a table with rows:
  | Field | Value |
  |-------|-------|
  | PO Number | PO12345 |
  | Amount | ₹50,000 |
  | Date | 15/03/2024 |
  | Status | Verified |

- **Invoice Document Data**: Currently displays "Invoice INV-789 validated successfully" as inline text. Should display as a table with Field-Value pairs.

- **Comments Field**: Currently may appear mandatory due to UI conventions. Should explicitly show as optional (no asterisk or "required" indicator).

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Approval workflow: clicking "Approve FAP" must continue to call `/submissions/{id}/asm-approve` API and navigate back
- Rejection workflow: clicking "Reject FAP" must continue to require rejection comments and call `/submissions/{id}/asm-reject` API
- Document download: clicking download buttons must continue to open documents in new browser tab using blob URL
- Confidence score display: percentage values must continue to show with color coding (green ≥85%, yellow ≥70%, red <70%)
- HQ rejection banner: must continue to display when state is 'RejectedByHQ' with resubmit option
- Navigation: back button must continue to refresh the submissions list
- Loading states: must continue to show CircularProgressIndicator during API calls
- Button states: action buttons must continue to disable during processing

**Scope:**
All inputs and interactions that do NOT involve viewing the document information sections should be completely unaffected by this fix. This includes:
- Header section with FAP ID and submission date
- HQ rejection section (if present)
- Review Decision panel with comments field and action buttons
- All API calls and state management logic
- Navigation and routing behavior

## Hypothesized Root Cause

Based on the bug description and code analysis, the root causes are:

1. **Widget Structure**: The current implementation uses Card widgets with Column children containing Row widgets for inline text display. This creates a vertical stacking pattern rather than a structured table layout.

2. **AI Analysis Display**: The `_buildDocumentSection` method renders analysis points using `_buildAnalysisPoint` helper which creates Row widgets with check icons and text. This should be replaced with a Table or DataTable widget.

3. **Document Data Display**: Extracted data (PO Number, Amount, Date, etc.) is embedded within the analysis points as formatted strings. This should be extracted into a separate table with Field-Value columns.

4. **Comments Field Styling**: The TextField for comments in `_buildReviewDecisionPanel` may inherit default styling that suggests it's mandatory. No explicit "optional" indicator is present.

## Correctness Properties

Property 1: Bug Condition - Tabular Display Format

_For any_ ASM review detail page render where document information is displayed, the fixed page SHALL display AI analysis verification points in a table structure with columns for "Check Item", "Status", and "Details", and SHALL display extracted document data in a table structure with "Field" and "Value" columns, replacing the current card-based bullet point layout.

**Validates: Requirements 2.1, 2.2, 2.3**

Property 2: Preservation - Existing Functionality

_For any_ user interaction that is NOT related to viewing the document information layout (approval actions, rejection actions, document downloads, navigation), the fixed code SHALL produce exactly the same behavior as the original code, preserving all workflows, API calls, state management, and navigation patterns.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8**

Property 3: Bug Condition - Comments Field Optional Indicator

_For any_ render of the Review Decision panel, the fixed page SHALL display the comments field without any visual indicators (asterisks, "required" labels, or styling) that suggest the field is mandatory, making it explicitly clear that comments are optional for approval actions.

**Validates: Requirements 2.4**

## Fix Implementation

### Changes Required

Assuming our root cause analysis is correct:

**File**: `frontend/lib/features/approval/presentation/pages/asm_review_detail_page.dart`

**Function**: `_buildDocumentSection`, `_buildPhotosSectionFromData`, `_buildReviewDecisionPanel`

**Specific Changes**:

1. **Create Table Widget for AI Analysis**:
   - Replace the current Container with bullet points in `_buildDocumentSection`
   - Create a new helper method `_buildAIAnalysisTable` that returns a Table widget
   - Define three columns: "Check Item", "Status", "Details"
   - Populate rows with verification points from the `analysisPoints` list
   - Apply Bajaj brand colors for table headers and borders

2. **Create Table Widget for Extracted Document Data**:
   - Add a new helper method `_buildDocumentDataTable` 
   - Extract field-value pairs from parsed document data (PO Number, Amount, Date, etc.)
   - Create a Table widget with two columns: "Field" and "Value"
   - Display each extracted data point as a table row
   - Apply consistent styling with borders and padding

3. **Restructure Document Section Layout**:
   - Modify `_buildDocumentSection` to display two separate tables:
     - First table: Extracted Document Data (Field-Value pairs)
     - Second table: AI Analysis Summary (Check Item-Status-Details)
   - Maintain the document header with title, confidence score, and download button
   - Remove the current inline text and bullet point display

4. **Update Photos Section**:
   - Modify `_buildPhotosSectionFromData` to use a table for AI analysis points
   - Keep the photo grid/wrap display unchanged
   - Replace the analysis points container with `_buildAIAnalysisTable`

5. **Update Comments Field Styling**:
   - In `_buildReviewDecisionPanel`, modify the TextField decoration
   - Remove any implicit "required" indicators
   - Add explicit "(Optional)" text to the label
   - Ensure hintText clearly indicates the field is optional

6. **Responsive Design**:
   - Ensure tables are horizontally scrollable on mobile devices
   - Use SingleChildScrollView with horizontal axis for tables
   - Maintain readable font sizes and padding on all screen sizes
   - Consider stacking table sections vertically on narrow screens

### Widget Structure

**New Helper Methods to Create**:

```dart
Widget _buildDocumentDataTable(Map<String, dynamic> parsedData, String documentType)
Widget _buildAIAnalysisTable(List<String> analysisPoints)
Widget _buildTableHeader(List<String> columnNames)
Widget _buildTableRow(List<String> cellValues, {bool isHeader = false})
```

**Modified Methods**:

```dart
Widget _buildDocumentSection(...) // Add table display logic
Widget _buildPhotosSectionFromData(...) // Add table for analysis
Widget _buildReviewDecisionPanel() // Update comments field label
```

### Styling Approach

**Table Styling**:
- Border: 1px solid AppColors.border
- Header background: AppColors.primary with white text
- Row background: Alternating white and AppColors.background (light gray)
- Cell padding: 12px horizontal, 8px vertical
- Font: AppTextStyles.bodyMedium for cells, bodySmall with fontWeight.w600 for headers
- Border radius: 8px for table container

**Responsive Breakpoints**:
- Mobile (<600px): Single column layout, horizontally scrollable tables
- Tablet (600-900px): Two column layout where appropriate
- Desktop (>900px): Full width tables with optimal column sizing

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bug on unfixed code (card-based layout), then verify the fix works correctly (tabular layout) and preserves existing behavior (all workflows unchanged).

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bug BEFORE implementing the fix. Confirm that the current implementation uses card-based layout with bullet points rather than tables.

**Test Plan**: Navigate to the ASM review detail page in the running application and visually inspect the document sections. Capture screenshots showing the current card-based layout. Verify that AI analysis appears as bullet points and document data appears as inline text.

**Test Cases**:
1. **AI Analysis Display Test**: Navigate to a submission detail page and verify that verification points appear as bullet points with check icons in a colored container (will show card layout on unfixed code)
2. **PO Data Display Test**: Verify that PO Number, Amount, and Date appear as inline text within analysis points rather than in a Field-Value table (will show inline text on unfixed code)
3. **Invoice Data Display Test**: Verify that invoice data appears as formatted strings in bullet points (will show inline text on unfixed code)
4. **Comments Field Test**: Verify that the comments field may appear mandatory due to styling conventions (may show implicit required indicator on unfixed code)

**Expected Counterexamples**:
- AI analysis verification points displayed as bullet points in colored container
- Document data embedded in analysis point text strings
- No structured table with Field-Value columns
- Comments field without explicit "optional" indicator

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds (viewing document sections), the fixed function produces the expected behavior (tabular display).

**Pseudocode:**
```
FOR ALL pageRender WHERE isBugCondition(pageRender) DO
  result := renderASMReviewDetailPage_fixed(pageRender)
  ASSERT result.aiAnalysisSection.displayFormat == 'table-with-columns'
  ASSERT result.documentDataSection.displayFormat == 'table-with-rows'
  ASSERT result.commentsField.hasOptionalIndicator == true
END FOR
```

**Test Plan**: After implementing the fix, navigate to multiple submission detail pages and verify that:
- AI analysis appears in a table with "Check Item", "Status", "Details" columns
- Document data appears in a table with "Field" and "Value" columns
- Tables are properly styled with Bajaj brand colors
- Tables are responsive and scrollable on mobile devices
- Comments field shows "(Optional)" indicator

**Test Cases**:
1. **AI Analysis Table Test**: Verify table structure with three columns and proper headers
2. **PO Data Table Test**: Verify Field-Value table with PO Number, Amount, Date rows
3. **Invoice Data Table Test**: Verify Field-Value table with Invoice Number, Amount, Date rows
4. **Cost Summary Table Test**: Verify Field-Value table with cost breakdown
5. **Photos Analysis Table Test**: Verify table structure for photo verification points
6. **Comments Optional Test**: Verify "(Optional)" text appears in comments field label
7. **Mobile Responsive Test**: Verify tables are horizontally scrollable on narrow screens
8. **Styling Test**: Verify table borders, colors, and padding match design specifications

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold (all non-viewing interactions), the fixed function produces the same result as the original function.

**Pseudocode:**
```
FOR ALL interaction WHERE NOT isBugCondition(interaction) DO
  ASSERT handleInteraction_original(interaction) = handleInteraction_fixed(interaction)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many test cases automatically across the interaction domain
- It catches edge cases that manual tests might miss
- It provides strong guarantees that behavior is unchanged for all non-layout interactions

**Test Plan**: Test all interactive elements and workflows to ensure they continue to work exactly as before.

**Test Cases**:
1. **Approval Workflow Preservation**: Click "Approve FAP", verify API call to `/submissions/{id}/asm-approve`, verify navigation back to list, verify success message
2. **Rejection Workflow Preservation**: Click "Reject FAP" without comments, verify validation error; add comments, click reject, verify API call to `/submissions/{id}/asm-reject`
3. **Document Download Preservation**: Click download button on PO, Invoice, Cost Summary; verify document opens in new tab using blob URL
4. **Confidence Score Preservation**: Verify confidence percentages display with correct color coding (green ≥85%, yellow ≥70%, red <70%)
5. **HQ Rejection Banner Preservation**: For submissions rejected by HQ, verify banner displays with rejection reason and resubmit button
6. **Navigation Preservation**: Click back button, verify navigation to submissions list and list refresh
7. **Loading State Preservation**: Verify CircularProgressIndicator displays during initial page load and during approval/rejection processing
8. **Button State Preservation**: Verify action buttons disable during processing and show loading indicators

### Unit Tests

- Test `_buildDocumentDataTable` with various document types (PO, Invoice, Cost Summary)
- Test `_buildAIAnalysisTable` with different numbers of analysis points
- Test table rendering with empty data (edge case)
- Test responsive layout switching at breakpoints
- Test comments field decoration includes "(Optional)" text

### Widget Tests

- Test complete page render with tabular layout
- Test table structure and content for each document type
- Test table scrolling behavior on mobile viewport
- Test preservation of all interactive elements (buttons, text fields)
- Test state changes (loading, processing, error states)

### Integration Tests

- Test full approval workflow from detail page to list refresh
- Test full rejection workflow with comments validation
- Test document download flow for all document types
- Test HQ rejection resubmit flow
- Test navigation flow between list and detail pages
- Test responsive behavior across different screen sizes
