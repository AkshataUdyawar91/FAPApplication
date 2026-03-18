# PO Line Item Type Handling — Bugfix Design

## Overview

The SAP PO Balance API returns `po_line_item` as a JSON **array** when multiple line items exist,
but as a JSON **object** when only one line item exists. The same inconsistency can occur for
`gr_data` inside each line item. The current `CalculateBalance` method in `PoBalanceService`
calls `EnumerateArray()` directly on both fields, which throws a `JsonException` when the value
is an object instead of an array.

The fix introduces a private helper method `EnumerateArrayOrObject` that normalises either shape
into an enumerable of `JsonElement` values. No new classes, no new files — the change is
self-contained inside `PoBalanceService.cs`.

---

## Glossary

- **Bug_Condition (C)**: `po_line_item` (or `gr_data`) is a JSON object (`JsonValueKind.Object`)
  rather than a JSON array (`JsonValueKind.Array`).
- **Property (P)**: After normalisation, the field is treated as a single-element list and all
  downstream field reads (price_without_tax, currency, invoice_value, etc.) succeed without error.
- **Preservation**: All existing behaviour for array-shaped responses, header fields, and
  non-SAP code paths must remain byte-for-byte identical.
- **`CalculateBalance`**: Private method in
  `BajajDocumentProcessing.Infrastructure/Services/PoBalanceService.cs` that parses the SAP
  JSON response and computes the PO balance.
- **`EnumerateArrayOrObject`**: New private helper to be added to `PoBalanceService` that
  accepts a `JsonElement` and yields its items regardless of whether it is an array or object.
- **`gr_data`**: Optional nested field inside each `po_line_item` that may also arrive as an
  object or array.

---

## Bug Details

### Bug Condition

The bug manifests when the SAP PO Balance API returns `po_line_item` as a JSON object (single
line item). `CalculateBalance` calls `lineItems.EnumerateArray()`, which throws
`InvalidOperationException` for a non-array `JsonElement`. The same failure path exists for
`gr_data` when it is a single-object response.

**Formal Specification:**
```
FUNCTION isBugCondition(element)
  INPUT:  element — a JsonElement representing the po_line_item field value
  OUTPUT: boolean

  RETURN element.ValueKind = JsonValueKind.Object
END FUNCTION
```

### Examples

- **Bug triggered**: SAP returns `"po_line_item": { "po_num": "4500001234", ... }` →
  `EnumerateArray()` throws → caller receives 500 error.
- **Bug triggered (gr_data)**: SAP returns `"gr_data": { "invoice_value": "1000.00" }` inside
  a line item → inner `EnumerateArray()` throws.
- **No bug**: SAP returns `"po_line_item": [{ "po_num": "4500001234", ... }]` → works today.
- **No bug**: SAP returns `"po_line_item": [{ ... }, { ... }]` → works today.
- **Edge case**: SAP returns `"po_line_item": []` → empty array, balance = 0, no error (preserved).

---

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Multi-item array responses must continue to deserialize all items and compute the correct balance.
- Single-element array responses must continue to produce a one-element result.
- `po_header` fields are read from a separate JSON path and must be completely unaffected.
- Balance arithmetic (`price_without_tax` sum minus `invoice_value` sum) must produce identical
  results for any input that was already working.
- All error handling for non-`"S"` SAP status codes, HTTP failures, and invalid JSON must remain
  unchanged.

**Scope:**
All inputs where `po_line_item` is already a JSON array are unaffected by this fix. This includes:
- Any PO with two or more line items.
- Any PO with exactly one line item returned as a single-element array.
- All `gr_data` values that are already arrays.

---

## Hypothesized Root Cause

1. **Direct `EnumerateArray()` call without shape check**: `CalculateBalance` calls
   `lineItems.EnumerateArray()` unconditionally. `System.Text.Json` throws
   `InvalidOperationException` when `ValueKind != Array`. This is the primary cause.

2. **Same pattern repeated for `gr_data`**: The inner loop calls `grData.EnumerateArray()`
   with the same assumption. SAP may return `gr_data` as an object for single GR entries,
   triggering the same failure.

3. **No defensive shape normalisation at the parse boundary**: The service works directly with
   `JsonElement` (raw DOM) rather than a typed model, so there is no deserialization hook that
   could normalise the shape before the loop runs.

---

## Correctness Properties

Property 1: Bug Condition — Object-shaped `po_line_item` is normalised to a single-element enumerable

_For any_ `JsonElement` where `isBugCondition` holds (ValueKind is Object), the fixed
`EnumerateArrayOrObject` helper SHALL yield exactly one element equal to that object, and
`CalculateBalance` SHALL complete without throwing, returning a `PoBalanceResponse` with the
correct balance derived from that single item's fields.

**Validates: Requirements 2.1, 2.2**

Property 2: Preservation — Array-shaped `po_line_item` behaviour is unchanged

_For any_ `JsonElement` where `isBugCondition` does NOT hold (ValueKind is Array), the fixed
`EnumerateArrayOrObject` helper SHALL yield the same sequence of elements as the original
`EnumerateArray()` call, and `CalculateBalance` SHALL produce the same `PoBalanceResponse` as
the original code.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4**

---

## Fix Implementation

### Changes Required

**File**: `backend/src/BajajDocumentProcessing.Infrastructure/Services/PoBalanceService.cs`

**Function**: `CalculateBalance` (replace two `EnumerateArray()` calls) + new private helper

**Specific Changes:**

1. **Add `EnumerateArrayOrObject` helper**: A private static method that accepts a `JsonElement`
   and returns `IEnumerable<JsonElement>`. If `ValueKind == Array`, delegate to `EnumerateArray()`.
   If `ValueKind == Object`, yield the element itself as a single-item sequence. Otherwise yield
   nothing (defensive fallback for null/undefined).

   ```
   FUNCTION EnumerateArrayOrObject(element)
     IF element.ValueKind = JsonValueKind.Array  THEN RETURN element.EnumerateArray()
     IF element.ValueKind = JsonValueKind.Object THEN RETURN [ element ]
     RETURN []
   END FUNCTION
   ```

2. **Replace `lineItems.EnumerateArray()`** in `CalculateBalance` with
   `EnumerateArrayOrObject(lineItems)`.

3. **Replace `grData.EnumerateArray()`** in the inner loop with
   `EnumerateArrayOrObject(grData)`.

4. **No other changes**: HTTP call logic, balance arithmetic, logging, audit persistence, and
   error handling for non-`"S"` status are all untouched.

---

## Testing Strategy

### Validation Approach

Two-phase approach: first run exploratory tests against the **unfixed** code to confirm the root
cause, then run fix-checking and preservation tests against the **fixed** code.

### Exploratory Bug Condition Checking

**Goal**: Surface the `InvalidOperationException` on unfixed code to confirm the root cause is
the direct `EnumerateArray()` call.

**Test Plan**: Construct minimal SAP JSON payloads where `po_line_item` is an object and invoke
`CalculateBalance` via reflection or by extracting it to an internal/testable scope. Assert that
the unfixed code throws.

**Test Cases:**
1. **Single object line item**: `"po_line_item": { "price_without_tax": "500.00", ... }` →
   expect `InvalidOperationException` on unfixed code.
2. **Single object gr_data**: `"po_line_item": [{ ..., "gr_data": { "invoice_value": "100.00" } }]`
   → expect `InvalidOperationException` on unfixed code.
3. **Null / missing gr_data**: `"po_line_item": [{ ... }]` with no `gr_data` key → should not
   throw (already handled by `TryGetProperty`).

**Expected Counterexamples:**
- `EnumerateArray()` throws `InvalidOperationException: This value's ValueKind is Object, not Array`.

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed code produces the
correct `PoBalanceResponse`.

**Pseudocode:**
```
FOR ALL json WHERE isBugCondition(json.po_line_item) DO
  result := CalculateBalance_fixed(poNum, json)
  ASSERT result does not throw
  ASSERT result.Balance = price_without_tax - sum(gr_data.invoice_value)
  ASSERT result.Currency = po_line_item.currency
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed code
produces the same result as the original code.

**Pseudocode:**
```
FOR ALL json WHERE NOT isBugCondition(json.po_line_item) DO
  ASSERT CalculateBalance_original(poNum, json) = CalculateBalance_fixed(poNum, json)
END FOR
```

**Testing Approach**: Property-based testing with FsCheck is used for preservation because:
- It generates many combinations of item counts, price values, and currency strings automatically.
- It catches arithmetic edge cases (zero prices, multiple GR entries, missing optional fields).
- It provides strong guarantees that the array path is byte-for-byte unchanged.

### Unit Tests

**File**: `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/PoBalanceServiceTests.cs`

- `CalculateBalance_WhenPoLineItemIsObject_ReturnsCorrectBalance` — single object, no gr_data
- `CalculateBalance_WhenPoLineItemIsObject_WithGrData_ReturnsCorrectBalance` — single object with gr_data as object
- `CalculateBalance_WhenPoLineItemIsArray_RemainsUnchanged` — multi-item array (regression)
- `CalculateBalance_WhenPoLineItemIsSingleElementArray_RemainsUnchanged` — edge case
- `CalculateBalance_WhenGrDataIsObject_ReturnsCorrectBalance` — gr_data object inside array line item
- `CalculateBalance_WhenPoLineItemIsEmptyArray_ReturnsZeroBalance` — empty array edge case
- `CalculateBalance_WhenSapStatusIsNotS_Throws` — non-success status unchanged

### Property-Based Tests

**File**: `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/PoLineItemTypeHandlingProperties.cs`

- **Property 1 (Fix Checking)**: For any generated single-item object payload, `CalculateBalance`
  returns a `PoBalanceResponse` without throwing and the balance equals
  `price_without_tax - invoice_value`.
- **Property 2 (Preservation)**: For any generated N-item array payload (N ≥ 0), the fixed
  `CalculateBalance` returns the same balance as the original `EnumerateArray()` path, confirming
  no regression.

### Integration Tests

- Full `GetPoBalanceAsync` call with a mocked `HttpMessageHandler` returning a single-object
  `po_line_item` payload — asserts the returned `PoBalanceResponse` has the correct balance and
  the `POBalanceLog` is persisted with `IsSuccess = true`.
- Full call with a multi-item array payload — asserts existing behaviour is preserved end-to-end.
