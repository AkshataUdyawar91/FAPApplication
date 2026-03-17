# PO Number Extraction Fix Applied

## Issue
PO Number was not being extracted from documents. The API was returning:
```json
"poNumber": "",
"poAmount": 236000
```

The PO Number `PO/BAJ/MKT/2026/000231` was visible in the document but not captured.

## Root Cause
Azure Document Intelligence's `prebuilt-invoice` model looks for the field name `"InvoiceId"`, but PO documents use different field labels like:
- "PO Number:"
- "Purchase Order:"
- "PO No:"

The structured field extraction was failing because the field name didn't match.

## Solution Applied
Added a **fallback text extraction** mechanism in `AzureDocumentIntelligenceService.cs`:

1. **Primary Method**: Try to extract from structured fields (`InvoiceId`)
2. **Fallback Method**: If not found, scan the raw text for:
   - Lines containing "PO Number:", "Purchase Order:", "PO No:", etc.
   - Lines starting with "PO/" pattern (common in PO numbers)
3. **Extract the value** after the label and assign high confidence (0.85-0.90)

### Code Changes
```csharp
// Fallback: If PO number not found, try to extract from raw text
if (string.IsNullOrEmpty(poData.PONumber))
{
    foreach (var page in result.Pages)
    {
        foreach (var line in page.Lines)
        {
            // Look for "PO Number:" pattern
            if (lineText.Contains("PO Number:", StringComparison.OrdinalIgnoreCase))
            {
                // Extract value after the label
                poData.PONumber = extractedValue;
                poData.FieldConfidences["PONumber"] = 0.85;
            }
            
            // Look for "PO/" pattern (e.g., PO/BAJ/MKT/2026/000231)
            if (lineText.StartsWith("PO/", StringComparison.OrdinalIgnoreCase))
            {
                poData.PONumber = lineText.Trim();
                poData.FieldConfidences["PONumber"] = 0.90;
            }
        }
    }
}
```

## Testing Instructions

### ⚠️ IMPORTANT: Upload Fresh Documents
The old packages in your database have corrupted data. You MUST upload new documents to test this fix.

### Step 1: Login
```cmd
curl -X POST http://localhost:5000/api/auth/login -H "Content-Type: application/json" -d "{\"email\":\"agency@bajaj.com\",\"password\":\"Password123!\"}"
```

### Step 2: Upload NEW PO Document
```cmd
curl -X POST http://localhost:5000/api/Documents/upload -H "Authorization: Bearer YOUR_TOKEN" -F "file=@C:\path\to\PO.pdf" -F "documentType=PO" -F "packageId="
```

### Step 3: Upload Other Documents
Upload Invoice, Cost Summary, and Photos using the same packageId.

### Step 4: Process Package
```cmd
curl -X POST http://localhost:5000/api/submissions/PACKAGE_ID/process-now -H "Authorization: Bearer YOUR_TOKEN"
```

### Step 5: Verify Results
```cmd
curl -X GET http://localhost:5000/api/submissions/PACKAGE_ID -H "Authorization: Bearer YOUR_TOKEN"
```

## Expected Results
After processing with the new code:
```json
{
  "poNumber": "PO/BAJ/MKT/2026/000231",  // ✅ Now populated
  "poAmount": 236000,                     // ✅ Already working
  "invoiceNumber": "INV-12345",          // ✅ Should work
  "invoiceAmount": 236000,                // ✅ Should work
  "overallConfidence": 0.85               // ✅ Should be calculated
}
```

## Status
- ✅ Fix applied to code
- ✅ Code committed to Git
- ✅ Code pushed to GitHub
- ✅ API restarted with new code
- ⏳ **Waiting for testing with fresh document upload**

## Next Steps
1. Upload a NEW PO document (don't reuse old package IDs)
2. Complete the full workflow with all 4 document types
3. Verify PO Number is now extracted correctly
4. Check API logs for any errors during extraction

The fix is live and ready for testing! 🚀
