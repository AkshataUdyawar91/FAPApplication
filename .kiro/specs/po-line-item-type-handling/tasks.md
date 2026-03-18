# Implementation Plan

- [x] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Object-Shaped po_line_item Throws on Unfixed Code
  - **CRITICAL**: This test MUST FAIL on unfixed code — failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior — it will validate the fix when it passes after implementation
  - **GOAL**: Surface the InvalidOperationException thrown by EnumerateArray() on a JsonElement with ValueKind = Object
  - **Scoped PBT Approach**: Scope the property to the concrete failing case — a single-object po_line_item with any valid price_without_tax value
  - File: `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/PoBalanceServiceTests.cs`
  - Test: `CalculateBalance_WhenPoLineItemIsObject_ThrowsOnUnfixedCode`
  - Construct a minimal SAP JSON payload where `po_line_item` is a JSON object (not array): `"po_line_item": { "price_without_tax": "500.00", "currency": "INR", ... }`
  - Invoke `CalculateBalance` and assert it throws `InvalidOperationException` (confirming EnumerateArray() fails on Object kind)
  - Also cover the gr_data variant: `"po_line_item": [{ ..., "gr_data": { "invoice_value": "100.00" } }]` — assert same throw
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS with `InvalidOperationException: This value's ValueKind is Object, not Array` — this is correct and proves the bug exists
  - Document counterexamples found (e.g., `CalculateBalance("4500001234", objectPayload)` throws instead of returning PoBalanceResponse)
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.2_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Array-Shaped po_line_item Produces Unchanged Results
  - **IMPORTANT**: Follow observation-first methodology
  - File: `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/PoLineItemTypeHandlingProperties.cs`
  - Observe on UNFIXED code: `CalculateBalance` with a multi-item array payload returns correct balance (sum of price_without_tax minus sum of invoice_value)
  - Observe on UNFIXED code: single-element array payload returns one-item result with correct balance
  - Observe on UNFIXED code: empty array payload returns zero balance without error
  - Write FsCheck property: for all generated N-item array payloads (N ≥ 0), `CalculateBalance` returns a PoBalanceResponse where balance = sum(price_without_tax) - sum(invoice_value) across all line items (from Preservation Requirements in design)
  - The property generator should vary: item count (0–10), price_without_tax values, currency strings, presence/absence of gr_data arrays
  - Verify tests PASS on UNFIXED code (confirms baseline array behavior to preserve)
  - **EXPECTED OUTCOME**: Tests PASS — confirms existing array path is the baseline
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 3. Fix for object-shaped po_line_item and gr_data causing InvalidOperationException

  - [x] 3.1 Implement the fix in PoBalanceService.cs
    - File: `backend/src/BajajDocumentProcessing.Infrastructure/Services/PoBalanceService.cs`
    - Add private static helper: `private static IEnumerable<JsonElement> EnumerateArrayOrObject(JsonElement element)` — if ValueKind == Array, return element.EnumerateArray(); if ValueKind == Object, yield return element; otherwise yield break (defensive fallback)
    - Replace `lineItems.EnumerateArray()` in `CalculateBalance` with `EnumerateArrayOrObject(lineItems)`
    - Replace `grData.EnumerateArray()` in the inner loop with `EnumerateArrayOrObject(grData)`
    - No other changes — HTTP logic, balance arithmetic, logging, audit persistence, and non-"S" status error handling are untouched
    - _Bug_Condition: isBugCondition(element) where element.ValueKind = JsonValueKind.Object_
    - _Expected_Behavior: EnumerateArrayOrObject yields the element itself as a single-item sequence; CalculateBalance completes without throwing and returns PoBalanceResponse with correct balance_
    - _Preservation: All inputs where po_line_item is already a JSON array must produce byte-for-byte identical PoBalanceResponse results_
    - _Requirements: 2.1, 2.2, 3.1, 3.2, 3.3, 3.4_

  - [x] 3.2 Add unit tests for the fix
    - File: `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/PoBalanceServiceTests.cs`
    - `CalculateBalance_WhenPoLineItemIsObject_ReturnsCorrectBalance` — single object, no gr_data; assert balance = price_without_tax
    - `CalculateBalance_WhenPoLineItemIsObject_WithGrData_ReturnsCorrectBalance` — single object with gr_data as object; assert balance = price_without_tax - invoice_value
    - `CalculateBalance_WhenPoLineItemIsArray_RemainsUnchanged` — multi-item array; assert all items summed correctly
    - `CalculateBalance_WhenPoLineItemIsSingleElementArray_RemainsUnchanged` — single-element array; assert one-item result unchanged
    - `CalculateBalance_WhenGrDataIsObject_ReturnsCorrectBalance` — gr_data object inside array line item; assert correct deduction
    - `CalculateBalance_WhenPoLineItemIsEmptyArray_ReturnsZeroBalance` — empty array; assert balance = 0, no exception
    - `CalculateBalance_WhenSapStatusIsNotS_Throws` — non-"S" SAP status; assert existing error handling unchanged
    - _Requirements: 2.1, 2.2, 3.1, 3.2, 3.3, 3.4_

  - [x] 3.3 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Object-Shaped po_line_item Returns Correct Balance
    - **IMPORTANT**: Re-run the SAME test from task 1 — do NOT write a new test
    - The test from task 1 encodes the expected behavior (no throw, correct PoBalanceResponse returned)
    - Run `CalculateBalance_WhenPoLineItemIsObject_ThrowsOnUnfixedCode` against fixed code
    - **EXPECTED OUTCOME**: Test PASSES — confirms the InvalidOperationException is gone and the fix works
    - _Requirements: 2.1, 2.2_

  - [x] 3.4 Verify preservation property tests still pass
    - **Property 2: Preservation** - Array-Shaped po_line_item Produces Unchanged Results
    - **IMPORTANT**: Re-run the SAME FsCheck tests from task 2 — do NOT write new tests
    - Run all property tests in `PoLineItemTypeHandlingProperties.cs` against fixed code
    - **EXPECTED OUTCOME**: Tests PASS — confirms no regressions on the existing array path
    - Confirm all generated array-shaped inputs still produce identical balance results after the fix

- [x] 4. Checkpoint — Ensure all tests pass
  - Run `dotnet test` from the backend directory and confirm all tests pass
  - Verify: exploration test passes (bug fixed), preservation properties pass (no regression), all new unit tests pass
  - Ask the user if any questions arise
