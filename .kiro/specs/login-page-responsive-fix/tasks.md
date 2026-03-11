# Implementation Plan

- [ ] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** — RenderFlex Overflow on Narrow Screens
  - **CRITICAL**: This test MUST FAIL on unfixed code — failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior — it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate RenderFlex overflow on narrow viewports
  - **Scoped PBT Approach**: Scope to concrete failing widths: 320 dp for login page, 100 dp parent for header rows, 350 dp for tables
  - Create `test/features/responsive_overflow_test.dart`
  - Test 1: Render `NewLoginPage` at 320 dp width — assert no overflow errors (will FAIL on unfixed code due to tab row + remember-me row overflow)
  - Test 2: Render ASM review detail header at narrow parent constraint (~100 dp) — assert no overflow (will FAIL)
  - Test 3: Render HQ review detail header at narrow parent constraint (~155 dp) — assert no overflow (will FAIL)
  - Test 4: Render `InvoiceDocumentsTable` at 350 dp width with sample documents — assert no overflow (will FAIL)
  - Test 5: Render `CampaignDetailsTable` at 350 dp width with sample documents — assert no overflow (will FAIL)
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests FAIL (this is correct — proves the overflow bugs exist)
  - Document counterexamples found (overflow pixel amounts from Flutter error output)
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9_

- [ ] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** — Wide Screen Layout Unchanged
  - **IMPORTANT**: Follow observation-first methodology
  - Create `test/features/responsive_preservation_test.dart`
  - Observe: Login page at 400+ dp renders 3 tabs with icon + full label, remember-me row on single line
  - Observe: ASM/HQ header at 500+ dp renders reqNumber and date on single row
  - Observe: Tables at 600+ dp render all 5 columns in tabular layout
  - Write tests asserting these observed behaviors at normal widths (400, 500, 600+ dp)
  - Verify tests PASS on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (confirms baseline wide-screen behavior to preserve)
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10_

- [x] 3. Fix responsive overflow issues across 5 files

  - [x] 3.1 Fix login page tab row and remember-me row overflow
    - File: `frontend/lib/features/auth/presentation/pages/new_login_page.dart`
    - In `_buildTab`: Wrap the `Text` widget with `Flexible` and add `overflow: TextOverflow.ellipsis`
    - In `build` (remember-me row): Wrap the inner `Row` (Checkbox + "Remember me") with `Flexible`
    - _Bug_Condition: screenWidth < 360 dp causes tab row overflow ~58px and remember-me row overflow ~13px_
    - _Expected_Behavior: Tabs shrink with ellipsis, remember-me row flexes to fit_
    - _Preservation: On screens ≥ 400 dp, tabs display full labels and remember-me row stays on one line_
    - _Requirements: 2.1, 2.2, 2.3, 3.1, 3.2_

  - [x] 3.2 Fix ASM review detail page header row overflow
    - File: `frontend/lib/features/approval/presentation/pages/asm_review_detail_page.dart`
    - In `_buildHeaderSection`: Replace the `Row` containing reqNumber + date with `Wrap(spacing: 16, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center)`
    - Group calendar icon + date into a `Row(mainAxisSize: MainAxisSize.min)` as a single Wrap child
    - _Bug_Condition: parentConstraintWidth < 213 dp causes overflow ~111px_
    - _Expected_Behavior: Date wraps to next line on narrow screens_
    - _Preservation: On screens ≥ 500 dp, reqNumber and date remain on single row_
    - _Requirements: 2.4, 3.5_

  - [x] 3.3 Fix HQ review detail page header row overflow
    - File: `frontend/lib/features/approval/presentation/pages/hq_review_detail_page.dart`
    - Same `Row` → `Wrap` change as task 3.2
    - _Bug_Condition: parentConstraintWidth < 213 dp causes overflow ~58px_
    - _Expected_Behavior: Date wraps to next line on narrow screens_
    - _Preservation: On screens ≥ 500 dp, reqNumber and date remain on single row_
    - _Requirements: 2.5, 3.5_

  - [x] 3.4 Fix invoice documents table overflow
    - File: `frontend/lib/features/approval/presentation/widgets/invoice_documents_table.dart`
    - Wrap `Table` in `SingleChildScrollView(scrollDirection: Axis.horizontal)` with `ConstrainedBox(constraints: BoxConstraints(minWidth: 600))`
    - Ensure `BuildContext` is available in the method for `MediaQuery` if needed
    - _Bug_Condition: screenWidth < 400 dp causes character-by-character wrapping and ~3.1px overflow_
    - _Expected_Behavior: Table scrolls horizontally, content remains legible_
    - _Preservation: On screens ≥ 600 dp, table displays all 5 columns in current layout_
    - _Requirements: 2.6, 2.7, 3.8, 3.9, 3.10_

  - [x] 3.5 Fix campaign details table overflow
    - File: `frontend/lib/features/approval/presentation/widgets/campaign_details_table.dart`
    - Same horizontal scroll wrapper as task 3.4
    - _Bug_Condition: screenWidth < 400 dp causes same overflow and unreadable text_
    - _Expected_Behavior: Table scrolls horizontally, content remains legible_
    - _Preservation: On screens ≥ 600 dp, table displays all 5 columns in current layout_
    - _Requirements: 2.8, 2.9, 3.8, 3.9, 3.10_

  - [x] 3.6 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** — No RenderFlex Overflow on Narrow Screens
    - **IMPORTANT**: Re-run the SAME test from task 1 — do NOT write a new test
    - Run `test/features/responsive_overflow_test.dart`
    - **EXPECTED OUTCOME**: Test PASSES (confirms all 5 overflow bugs are fixed)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9_

  - [x] 3.7 Verify preservation tests still pass
    - **Property 2: Preservation** — Wide Screen Layout Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 — do NOT write new tests
    - Run `test/features/responsive_preservation_test.dart`
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions on wide screens)

- [ ] 4. Checkpoint — Ensure all tests pass
  - Run `flutter test` to verify all existing and new tests pass
  - Ensure no new analyzer warnings from `flutter analyze`
  - Ask the user if questions arise
