# Validation Trigger Fix - Extract API

## Issue
Invoice data was being saved to the `Invoices` table, but no validation results were being created in the `ValidationResults` table.

## Root Cause
The extract API was only saving the invoice entity but not triggering the proactive validation service that creates validation results.

## Solution
Added proactive validation trigger after invoice save in the extract API endpoint.

## Changes Made

### File: `backend/src/BajajDocumentProcessing.API/Controllers/DocumentsController.cs`

**Location**: After invoice save (around line 420)

**Added Code**:
```csharp
// Step 3.5: Trigger proactive validation for the invoice
if (_proactiveValidationService != null)
{
    try
    {
        _ = Task.Run(async () =>
        {
            try
            {
                using var scope = _serviceScopeFactory.CreateScope();
                var validationService = scope.ServiceProvider
                    .GetRequiredService<IProactiveValidationService>();
                
                _logger.LogInformation(
                    "🔍 [STEP 3.5] Starting proactive validation for invoice {InvoiceId}", 
                    invoice.Id);
                
                await validationService.ValidateDocumentAsync(
                    invoice.Id,
                    DocumentType.Invoice,
                    packageId.Value,
                    default);
                
                _logger.LogInformation(
                    "✅ [STEP 3.5] Proactive validation completed for invoice {InvoiceId}", 
                    invoice.Id);
            }
            catch (Exception valEx)
            {
                _logger.LogError(valEx, 
                    "❌ [STEP 3.5] Proactive validation failed for invoice {InvoiceId}", 
                    invoice.Id);
            }
        });
    }
    catch (Exception triggerEx)
    {
        _logger.LogError(triggerEx, 
            "Failed to trigger proactive validation for invoice {InvoiceId}", 
            invoice.Id);
        // Don't fail the extraction if validation trigger fails
    }
}
```

## How It Works

### Flow Diagram

```
Extract API
│
├─ Step 1: Upload file to blob storage
│
├─ Step 2: Extract data with AI (Azure OpenAI)
│
├─ Step 3: Save invoice to database
│   │
│   ├─ Validate PO exists
│   ├─ Create Invoice entity
│   ├─ Save to Invoices table
│   │
│   └─ Step 3.5: Trigger Proactive Validation ✨ NEW
│       │
│       ├─ Run in background (Task.Run)
│       ├─ Create new scope for scoped services
│       ├─ Call ProactiveValidationService.ValidateDocumentAsync()
│       │
│       └─ ProactiveValidationService
│           │
│           ├─ Load invoice from database
│           ├─ Load related PO for cross-checks
│           ├─ Run 9 validation rules:
│           │   1. INV_INVOICE_NUMBER_PRESENT
│           │   2. INV_DATE_PRESENT
│           │   3. INV_AMOUNT_PRESENT
│           │   4. INV_GST_NUMBER_PRESENT
│           │   5. INV_GST_PERCENT_PRESENT
│           │   6. INV_HSN_SAC_PRESENT
│           │   7. INV_VENDOR_CODE_PRESENT
│           │   8. INV_PO_NUMBER_MATCH
│           │   9. INV_AMOUNT_VS_PO_BALANCE
│           │
│           ├─ Create ValidationResult entity
│           ├─ Save to ValidationResults table
│           │
│           └─ Send SignalR notification (optional)
│
└─ Step 4: Return extracted data + documentId
```

## Validation Rules for Invoices

The ProactiveValidationService runs 9 validation rules for each invoice:

### Required Field Checks (7 rules)
1. **INV_INVOICE_NUMBER_PRESENT** - Invoice number must be present
2. **INV_DATE_PRESENT** - Invoice date must be present
3. **INV_AMOUNT_PRESENT** - Invoice amount must be present
4. **INV_GST_NUMBER_PRESENT** - GST number must be present
5. **INV_GST_PERCENT_PRESENT** - GST percentage must be present
6. **INV_HSN_SAC_PRESENT** - HSN/SAC code must be present
7. **INV_VENDOR_CODE_PRESENT** - Vendor code must be present

### Cross-Document Checks (2 rules)
8. **INV_PO_NUMBER_MATCH** - PO number on invoice must match selected PO
9. **INV_AMOUNT_VS_PO_BALANCE** - Invoice amount must not exceed PO remaining balance

## Database Impact

### Before Fix
```sql
-- Invoice saved
SELECT * FROM Invoices WHERE Id = 'f1e2d3c4-...'
-- ✅ Row exists

-- Validation results NOT created
SELECT * FROM ValidationResults WHERE DocumentId = 'f1e2d3c4-...'
-- ❌ No rows (ISSUE)
```

### After Fix
```sql
-- Invoice saved
SELECT * FROM Invoices WHERE Id = 'f1e2d3c4-...'
-- ✅ Row exists

-- Validation results created
SELECT * FROM ValidationResults 
WHERE DocumentId = 'f1e2d3c4-...' 
AND DocumentType = 'Invoice'
-- ✅ Row exists with RuleResultsJson populated
```

## Testing

### Test 1: Verify Validation Results Created

**Action**: Upload an invoice via extract API

**SQL Query**:
```sql
-- Get the latest invoice
SELECT TOP 1 
    i.Id AS InvoiceId,
    i.InvoiceNumber,
    i.PackageId,
    i.CreatedAt
FROM Invoices i
ORDER BY i.CreatedAt DESC

-- Check for validation results (use InvoiceId from above)
SELECT 
    vr.Id,
    vr.DocumentId,
    vr.DocumentType,
    vr.RuleResultsJson,
    vr.CreatedAt
FROM ValidationResults vr
WHERE vr.DocumentId = 'YOUR_INVOICE_ID_HERE'
AND vr.DocumentType = 'Invoice'
```

**Expected**:
- ValidationResults row exists
- `RuleResultsJson` contains array of 9 validation rules
- Each rule has: `RuleCode`, `Type`, `Passed`, `ExtractedValue`, `ExpectedValue`

### Test 2: Verify Validation Rules

**SQL Query**:
```sql
SELECT 
    vr.DocumentId,
    JSON_QUERY(vr.RuleResultsJson) AS Rules
FROM ValidationResults vr
WHERE vr.DocumentType = 'Invoice'
ORDER BY vr.CreatedAt DESC
```

**Expected JSON Structure**:
```json
[
  {
    "RuleCode": "INV_INVOICE_NUMBER_PRESENT",
    "Type": "Required",
    "Passed": true,
    "ExtractedValue": "INV-2024-001",
    "ExpectedValue": null
  },
  {
    "RuleCode": "INV_PO_NUMBER_MATCH",
    "Type": "Check",
    "Passed": true,
    "ExtractedValue": "PO-2024-001",
    "ExpectedValue": "PO-2024-001"
  },
  // ... 7 more rules
]
```

### Test 3: Check Logs

**Backend Console Output**:
```
[INFO] 📥 [STEP 3 INPUT] Saving to database - PackageId: 0608f7dc-..., DocType: invoice
[INFO] ✅ Invoice saved to database: InvoiceId: f1e2d3c4-..., POId: a1b2c3d4-..., InvoiceNumber: INV-2024-001, Total: 11800.00
[INFO] 🔍 [STEP 3.5] Starting proactive validation for invoice f1e2d3c4-...
[INFO] Starting proactive validation for document f1e2d3c4-... (type=Invoice, package=0608f7dc-...)
[INFO] Proactive validation complete for document f1e2d3c4-...: 7 pass, 0 fail, 2 warning
[INFO] ✅ [STEP 3.5] Proactive validation completed for invoice f1e2d3c4-...
```

## Benefits

### ✅ Immediate Validation Feedback
- Validation runs automatically after invoice save
- No manual trigger required
- Results available immediately for UI display

### ✅ Consistent with Upload API
- Extract API now has same validation behavior as upload API
- Both endpoints trigger validation after document save

### ✅ Background Processing
- Validation runs in background (Task.Run)
- Doesn't block the extract API response
- User gets extracted data immediately

### ✅ Error Resilience
- Validation failures don't fail the extraction
- Errors logged but extraction still succeeds
- Graceful degradation if validation service unavailable

## Verification Checklist

- [ ] Backend API restarted
- [ ] Upload invoice via extract API
- [ ] Check backend logs for validation messages
- [ ] Query ValidationResults table for new row
- [ ] Verify RuleResultsJson contains 9 rules
- [ ] Check that all required fields are validated
- [ ] Verify PO cross-checks work correctly
- [ ] Confirm validation doesn't block extraction response

## SQL Verification Queries

### Check Latest Invoice with Validation
```sql
SELECT 
    i.Id AS InvoiceId,
    i.InvoiceNumber,
    i.TotalAmount,
    i.CreatedAt AS InvoiceCreatedAt,
    vr.Id AS ValidationId,
    vr.CreatedAt AS ValidationCreatedAt,
    DATEDIFF(SECOND, i.CreatedAt, vr.CreatedAt) AS ValidationDelaySeconds
FROM Invoices i
LEFT JOIN ValidationResults vr ON vr.DocumentId = i.Id AND vr.DocumentType = 'Invoice'
WHERE i.IsDeleted = 0
ORDER BY i.CreatedAt DESC
```

### Count Invoices with/without Validation
```sql
SELECT 
    COUNT(*) AS TotalInvoices,
    SUM(CASE WHEN vr.Id IS NOT NULL THEN 1 ELSE 0 END) AS WithValidation,
    SUM(CASE WHEN vr.Id IS NULL THEN 1 ELSE 0 END) AS WithoutValidation
FROM Invoices i
LEFT JOIN ValidationResults vr ON vr.DocumentId = i.Id AND vr.DocumentType = 'Invoice'
WHERE i.IsDeleted = 0
```

### View Validation Rule Results
```sql
SELECT 
    i.InvoiceNumber,
    vr.RuleResultsJson
FROM Invoices i
INNER JOIN ValidationResults vr ON vr.DocumentId = i.Id
WHERE i.IsDeleted = 0
AND vr.DocumentType = 'Invoice'
ORDER BY i.CreatedAt DESC
```

## Next Steps

1. **Test the fix**:
   - Upload an invoice
   - Verify ValidationResults created
   - Check all 9 rules are present

2. **Apply to other document types**:
   - Add validation trigger for Cost Summary
   - Add validation trigger for Activity Summary
   - Add validation trigger for Team Photos

3. **UI Integration**:
   - Display validation results in upload form
   - Show pass/fail indicators per field
   - Allow user to see validation details

## Summary

The extract API now triggers proactive validation automatically after saving an invoice, ensuring that validation results are created in the `ValidationResults` table. This fix makes the extract API behavior consistent with the upload API and provides immediate validation feedback for the conversational submission flow.

**Status**: ✅ Fixed and Ready for Testing
