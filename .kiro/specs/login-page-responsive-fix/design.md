# Login Page & Review Pages Responsive Fix — Bugfix Design

## Overview

Five Flutter widgets produce RenderFlex overflow errors on narrow mobile screens (≲ 360 dp). The root cause is rigid `Row` layouts and fixed-width `Table` columns that exceed available horizontal space. The fix applies minimal, targeted layout changes: `Flexible` wrappers with text ellipsis for tab rows, `Wrap` widgets for rows that should break to a new line, and `SingleChildScrollView(scrollDirection: Axis.horizontal)` for data tables that must remain readable.

## Glossary

- **Bug_Condition (C)**: The screen width is narrow enough (≲ 360 dp for login, ≲ 500 dp for review headers, ≲ 400 dp for tables) that the combined intrinsic width of Row/Table children exceeds the parent constraint.
- **Property (P)**: No RenderFlex overflow occurs; all content remains legible and interactive.
- **Preservation**: On normal/wide screens, the visual layout is unchanged — tabs display fully, header rows stay on one line, tables render with current column widths.
- **RenderFlex overflow**: Flutter's yellow-black striped warning when children exceed a Row/Column's available space.
- **`Wrap` widget**: A Flutter widget that flows children to the next line when horizontal space is exhausted.
- **`Flexible` widget**: A Flutter widget that allows a child to shrink below its intrinsic width within a Row.

## Bug Details

### Bug Condition

The bug manifests when any of the 5 affected widgets are rendered on a screen narrower than their combined child widths. The `Row` widget does not allow children to shrink or wrap, causing overflow.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type { screenWidth: double, widgetId: enum }
  OUTPUT: boolean

  IF widgetId == LOGIN_TAB_ROW:
    RETURN screenWidth < 360
  ELSE IF widgetId == LOGIN_REMEMBER_ROW:
    RETURN screenWidth < 360
  ELSE IF widgetId == ASM_HEADER_ROW:
    RETURN parentConstraintWidth < 213  // reqNumber + gaps + icon + date
  ELSE IF widgetId == HQ_HEADER_ROW:
    RETURN parentConstraintWidth < 213
  ELSE IF widgetId == INVOICE_TABLE OR widgetId == CAMPAIGN_TABLE:
    RETURN screenWidth < 400
  ELSE:
    RETURN false
END FUNCTION
```

### Examples

- **Login tab row**: Screen width 320 dp → 3 tabs with icon+text in a Row overflow by ~58 px. Expected: tabs shrink, text truncates with ellipsis.
- **Login remember-me row**: Screen width 340 dp → checkbox + "Remember me" + "Forgot password?" overflow by ~13 px. Expected: inner "Remember me" Row shrinks via Flexible.
- **ASM header row**: Parent constraint ~102 dp → reqNumber + SizedBox(16) + icon + SizedBox(4) + date overflows by ~111 px. Expected: Wrap widget moves date to next line.
- **HQ header row**: Parent constraint ~155 dp → same pattern overflows by ~58 px. Expected: same Wrap fix.
- **Invoice/Campaign table**: Screen width 350 dp → FixedColumnWidth(60) + FixedColumnWidth(120) + flex columns = unreadable character-by-character wrapping. Expected: horizontal scroll wrapper.

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- On screens ≥ 400 dp, login tabs display all three roles (Agency, ASM, HQ/RA) with icon and full label, centered.
- On screens ≥ 400 dp, "Remember me" and "Forgot password?" appear on the same row with space between.
- Tab selection continues to switch roles, update credentials, and show the blue underline indicator.
- Checkbox toggle and "Forgot password?" snackbar continue to work.
- On screens ≥ 500 dp, ASM/HQ header rows display reqNumber and date on a single line.
- Back button navigation on review detail pages continues to work.
- Status badges continue to display correctly.
- On screens ≥ 600 dp, document tables display all 5 columns in the current tabular layout.
- Document name tap callbacks continue to trigger document open/preview.
- Empty document lists continue to render `SizedBox.shrink()`.

**Scope:**
All inputs on normal/wide screens are completely unaffected. The fix only changes layout behavior when the available width is insufficient for the current rigid layout.

## Hypothesized Root Cause

Based on the bug description and code analysis:

1. **Login Tab Row — Rigid Row children**: Each tab uses `Expanded` → `Row(mainAxisAlignment: center, children: [Icon, SizedBox(width:6), Text])`. The inner Row's intrinsic width (icon 18 + gap 6 + text ~60) can exceed the Expanded allocation on narrow screens because the Text widget has no overflow handling and the inner Row doesn't use Flexible.

2. **Login Remember-Me Row — No flex on inner Row**: The outer Row uses `mainAxisAlignment: spaceBetween` with two children: an inner `Row(children: [Checkbox, SizedBox(8), Text("Remember me")])` and a `TextButton("Forgot password?")`. The inner Row has no Flexible wrapper, so it claims its full intrinsic width even when space is tight.

3. **ASM/HQ Header Rows — Row instead of Wrap**: The reqNumber + date are in a `Row` with fixed-width SizedBox spacers. When the parent Column (inside an Expanded, next to IconButton and status badge) constrains width, the Row overflows because it cannot wrap to a second line.

4. **Document Tables — FixedColumnWidth on mobile**: Both tables use `FixedColumnWidth(60)` for S.No and `FixedColumnWidth(120)` for Status. On mobile, these fixed widths plus the flex columns leave almost no space for content, causing character-by-character wrapping and overflow.

## Correctness Properties

Property 1: Bug Condition — No RenderFlex Overflow on Narrow Screens

_For any_ screen width where the bug condition holds (isBugCondition returns true), the fixed widgets SHALL render without any RenderFlex overflow error, with all content remaining legible (text truncated with ellipsis, wrapped to next line, or horizontally scrollable as appropriate).

**Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9**

Property 2: Preservation — Wide Screen Layout Unchanged

_For any_ screen width where the bug condition does NOT hold (isBugCondition returns false), the fixed widgets SHALL produce the same visual layout as the original code, preserving tab display, row arrangement, table column widths, and all interactive behaviors.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10**

## Fix Implementation

### Changes Required

Assuming our root cause analysis is correct:

**File 1**: `frontend/lib/features/auth/presentation/pages/new_login_page.dart`

**Function**: `_buildTab`

**Change 1 — Tab text overflow**: Wrap the `Text` widget inside each tab's inner Row with `Flexible` and add `overflow: TextOverflow.ellipsis` to the Text. This allows the text to shrink and truncate when the Expanded allocation is too narrow.

```dart
// Before:
Text(label, style: ...)

// After:
Flexible(
  child: Text(label, style: ..., overflow: TextOverflow.ellipsis),
)
```

**Function**: `build` (remember-me row)

**Change 2 — Remember-me row flex**: Wrap the inner `Row` (checkbox + "Remember me" text) with `Flexible` so it can shrink when competing with the "Forgot password?" button for space.

```dart
// Before:
Row(children: [Checkbox, SizedBox, Text("Remember me")])

// After:
Flexible(child: Row(children: [Checkbox, SizedBox, Text("Remember me")]))
```

---

**File 2**: `frontend/lib/features/approval/presentation/pages/asm_review_detail_page.dart`

**Function**: `_buildHeaderSection`

**Change 3 — Header row wrap**: Replace the inner `Row` containing reqNumber + SizedBox + calendar icon + SizedBox + date with a `Wrap` widget using `spacing: 16` and `crossAxisAlignment: WrapCrossAlignment.center`. This allows the date portion to flow to the next line on narrow screens.

```dart
// Before:
Row(children: [Text(reqNumber), SizedBox(width:16), Icon, SizedBox(width:4), Text(date)])

// After:
Wrap(
  spacing: 16,
  runSpacing: 4,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [Text(reqNumber), Row(mainAxisSize: MainAxisSize.min, children: [Icon, SizedBox(width:4), Text(date)])]
)
```

---

**File 3**: `frontend/lib/features/approval/presentation/pages/hq_review_detail_page.dart`

**Function**: `_buildHeaderSection`

**Change 4**: Same `Row` → `Wrap` change as File 2.

---

**File 4**: `frontend/lib/features/approval/presentation/widgets/invoice_documents_table.dart`

**Function**: `_buildTable`

**Change 5 — Horizontal scroll wrapper**: Wrap the `Table` widget in a `SingleChildScrollView(scrollDirection: Axis.horizontal)` with a `ConstrainedBox(constraints: BoxConstraints(minWidth: 600))` to ensure the table maintains readable column widths and allows horizontal scrolling on mobile.

```dart
// Before:
return Table(...)

// After:
return SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: ConstrainedBox(
    constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width, maxWidth: 800),
    child: Table(...)
  ),
)
```

Note: This requires passing `BuildContext` to `_buildTable` or making it a method that has access to context.

---

**File 5**: `frontend/lib/features/approval/presentation/widgets/campaign_details_table.dart`

**Function**: `_buildTable`

**Change 6**: Same horizontal scroll wrapper as File 4.

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the overflow on unfixed code, then verify the fix eliminates overflow and preserves wide-screen layout.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the RenderFlex overflow BEFORE implementing the fix. Confirm or refute the root cause analysis.

**Test Plan**: Write widget tests that render each affected widget inside a `SizedBox` with constrained width (e.g., 320 dp for login, 100 dp parent for header rows) and check for overflow errors in the Flutter test framework. Run on UNFIXED code to observe failures.

**Test Cases**:
1. **Login Tab Row Test**: Render `NewLoginPage` at 320 dp width — expect overflow (will fail on unfixed code)
2. **Login Remember-Me Row Test**: Render `NewLoginPage` at 340 dp width — expect overflow (will fail on unfixed code)
3. **ASM Header Row Test**: Render `_buildHeaderSection` with narrow parent constraint — expect overflow (will fail on unfixed code)
4. **HQ Header Row Test**: Same as ASM but for HQ page (will fail on unfixed code)
5. **Invoice Table Test**: Render `InvoiceDocumentsTable` at 350 dp width — expect overflow or unreadable text (will fail on unfixed code)
6. **Campaign Table Test**: Same as invoice table (will fail on unfixed code)

**Expected Counterexamples**:
- RenderFlex overflow errors logged by Flutter framework
- Possible causes confirmed: rigid Row without Flexible, FixedColumnWidth on narrow screens

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed widgets render without overflow.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  result := renderWidget_fixed(input)
  ASSERT noOverflowErrors(result)
  ASSERT contentIsLegible(result)
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed widgets produce the same visual layout.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT renderWidget_original(input) == renderWidget_fixed(input)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many screen width values automatically across the non-buggy range
- It catches edge cases at boundary widths that manual tests might miss
- It provides strong guarantees that wide-screen layout is unchanged

**Test Plan**: Observe layout on UNFIXED code at normal widths (400+ dp), then write tests verifying the same layout after fix.

**Test Cases**:
1. **Wide Screen Tab Preservation**: Verify tabs at 400+ dp display icon + full label, centered
2. **Wide Screen Remember-Me Preservation**: Verify checkbox and link on same row at 400+ dp
3. **Wide Screen Header Preservation**: Verify reqNumber and date on single line at 500+ dp
4. **Wide Screen Table Preservation**: Verify 5-column table layout at 600+ dp

### Unit Tests

- Test each tab renders without overflow at 320 dp width
- Test remember-me row renders without overflow at 340 dp width
- Test header rows render without overflow at narrow parent constraints
- Test tables render with horizontal scroll at 350 dp width
- Test all interactive callbacks still fire (tab tap, checkbox, document tap)

### Property-Based Tests

- Generate random screen widths (200–800 dp) and verify no overflow for any width
- Generate random document lists and verify table renders without overflow at various widths
- Test boundary widths (359, 360, 361, 399, 400, 401) for correct layout switching

### Integration Tests

- Test full login flow on narrow screen: select each tab, enter credentials, submit
- Test full review detail flow on narrow screen: view header, scroll tables, tap documents
- Test that horizontal scroll on tables allows viewing all columns on mobile
