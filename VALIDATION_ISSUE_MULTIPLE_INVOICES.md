# Issue: Validation Only Checks First Invoice

## Problem

The validation is not catching missing invoice numbers because it only validates the **first** invoice document when multiple invoices are uploaded.

## Current Behavior

Your package has **3 invoice documents**:
1. `Cost Summary.pdf` - Invoice Number: "SE-01/2025-26" ✅
2. `Invoice_Missing_Invoice_Number.pdf` - Invoice Number: **EMPTY** ❌
3. `PO for FAP 240909.pdf` - Invoice Number: **EMPTY** ❌

The validation only checks document #1 (which has an invoice number), so it doesn't catch the missing invoice numbers in documents #2 and #3.

## Root Cause

In `ValidationAgent.cs` line 110:

```csharp
var invoiceDoc = package.Documents.FirstOrDefault(d => d.Type == DocumentType.Invoice);
```

This gets only the **first** invoice document, not all of them.

## Expected Behavior

The system should either:

### Option A: Validate ALL Invoices
Check every invoice document and report missing fields in any of them.

### Option B: Enforce Single Invoice Rule
Only allow ONE invoice per package and reject packages with multiple invoices.

## Current Validation Logic

The validation assumes:
- 1 PO document
- 1 Invoice document
- 1 Cost Summary document
- 1 Activity document (optional)
- Multiple Photo documents (up to 20)

## Why You Have 3 Invoices

Looking at your documents:
1. **"Cost Summary.pdf"** - Classified as Invoice (should be Cost Summary)
2. **"Invoice_Missing_Invoice_Number.pdf"** - Correctly classified as Invoice
3. **"PO for FAP 240909.pdf"** - Classified as Invoice (should be PO)

The document classification is incorrect for documents #1 and #3.

## Recommended Solution

### Immediate Fix: Validate All Invoices

Modify `ValidationAgent.cs` to validate ALL invoice documents:

```csharp
// Get ALL invoice documents
var invoiceDocs = package.Documents.Where(d => d.Type == DocumentType.Invoice).ToList();

// Validate each invoice
foreach (var invoiceDoc in invoiceDocs)
{
    if (invoiceDoc?.ExtractedDataJson != null)
    {
        var invoiceData = JsonSerializer.Deserialize<InvoiceData>(invoiceDoc.ExtractedDataJson);
        
        // Validate invoice fields
        var fieldPresence = ValidateInvoiceFieldPresence(invoiceData);
        if (!fieldPresence.AllFieldsPresent)
        {
            result.Issues.Add(new ValidationIssue
            {
                Field = $"Invoice Fields ({invoiceDoc.FileName})",
                Issue = $"Missing required fields: {string.Join(", ", fieldPresence.MissingFields)}",
                Severity = "Error"
            });
        }
    }
}
```

### Long-term Fix: Enforce Document Rules

Add validation to ensure only ONE of each required document type:

```csharp
// Check for duplicate document types
var invoiceCount = package.Documents.Count(d => d.Type == DocumentType.Invoice);
if (invoiceCount > 1)
{
    result.Issues.Add(new ValidationIssue
    {
        Field = "Completeness",
        Issue = $"Multiple invoices detected ({invoiceCount}). Only one invoice is allowed per package.",
        Severity = "Error"
    });
}
```

## Workaround for Now

To test the validation properly:

1. **Upload documents with correct types**:
   - Upload "PO for FAP 240909.pdf" as **PO** (not Invoice)
   - Upload "Invoice_Missing_Invoice_Number.pdf" as **Invoice**
   - Upload "Cost Summary.pdf" as **Cost Summary** (not Invoice)

2. **Or delete the extra invoices**:
   - Keep only ONE invoice document per package
   - Delete the other two

## Testing After Fix

Once the validation is fixed to check all invoices, you should see:

```json
{
  "failureReason": "Missing required fields in Invoice_Missing_Invoice_Number.pdf: Invoice Number; Missing required fields in PO for FAP 240909.pdf: Invoice Number, Invoice Date, ..."
}
```

## Document Classification Issue

The real problem is that your documents are being misclassified:
- **"Cost Summary.pdf"** should be classified as **CostSummary**, not Invoice
- **"PO for FAP 240909.pdf"** should be classified as **PO**, not Invoice

This happens because:
1. You're uploading them with `documentType=Invoice` in the upload request
2. The system trusts your document type selection

Make sure to select the correct document type when uploading!
