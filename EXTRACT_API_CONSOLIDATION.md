# Extract API Consolidation - Eliminating Duplicate Processing

## Problem
Currently, we have two APIs doing duplicate work:
1. **Extract API** (`POST /documents/extract`) - Uploads to temp blob, extracts data, deletes blob
2. **Upload API** (`POST /documents/upload`) - Uploads to permanent blob, creates DB entity, triggers background extraction

This means extraction happens TWICE for the same document, wasting time and Azure OpenAI credits.

## Solution ✅ IMPLEMENTED

Consolidated both operations into the **Extract API**. Now it works in two modes:

### Mode 1: Extract Only (No packageId)
- Uploads to temp blob
- Extracts data using AI
- Deletes temp blob
- Returns extracted data only
- **Use case**: Preview/validation before submission

### Mode 2: Extract + Save (With packageId)
- Uploads to permanent blob
- Extracts data using AI
- Saves to database with extracted data
- Returns extracted data + documentId
- **Use case**: Final submission with auto-populated fields

## Backend Changes ✅ DONE

### Updated Extract Endpoint
**File**: `backend/src/BajajDocumentProcessing.API/Controllers/DocumentsController.cs`

```csharp
[HttpPost("extract")]
public async Task<IActionResult> ExtractDocument(
    [FromForm] IFormFile file,
    [FromForm] string documentType,
    [FromForm] Guid? packageId,  // NEW: Optional packageId
    [FromServices] IDocumentAgent documentAgent,
    CancellationToken cancellationToken)
{
    bool isPermanentUpload = packageId.HasValue && packageId.Value != Guid.Empty;
    
    // Step 1: Upload (permanent if packageId, temp otherwise)
    if (isPermanentUpload)
        fileName = $"{Guid.NewGuid()}{ext}";
    else
        fileName = $"temp-extract/{Guid.NewGuid()}{ext}";
    
    // Step 2: Extract data using AI
    extracted = await documentAgent.ExtractInvoiceAsync(blobUrl, cancellationToken);
    
    // Step 3: Save to database if packageId provided
    if (isPermanentUpload && extracted != null)
    {
        var invoice = new Invoice
        {
            // ... populate from extracted data
            InvoiceNumber = invoiceData.InvoiceNumber,
            TotalAmount = invoiceData.TotalAmount,
            ExtractedDataJson = JsonSerializer.Serialize(invoiceData),
            // ...
        };
        _context.Invoices.Add(invoice);
        await _context.SaveChangesAsync();
    }
    
    // Step 4: Cleanup temp blob (only if not permanent)
    if (!isPermanentUpload)
        await _fileStorageService.DeleteFileAsync(blobUrl);
    
    return Ok(new { 
        extractedData = extracted,
        documentId = documentId,  // Only if saved to DB
        packageId = packageId,
        blobUrl = isPermanentUpload ? blobUrl : null
    });
}
```

## Frontend Changes NEEDED

### Update Invoice Upload Widget
**File**: `frontend/lib/features/submission/presentation/widgets/invoice_list_section.dart`

Change from:
```dart
// OLD: Upload then poll for extraction
await dio.post('/documents/upload', ...);
_pollInvoiceExtraction(documentId, index);
```

To:
```dart
// NEW: Extract with packageId (does both in one call)
final formData = FormData.fromMap({
  'file': await MultipartFile.fromFile(invoice.file!.path!, filename: invoice.file!.name),
  'documentType': 'invoice',
  'packageId': widget.packageId,  // Include packageId
});

final response = await dio.post('/documents/extract', data: formData, ...);

// Data is already extracted and saved!
final extractedData = response.data['extractedData'];
final documentId = response.data['documentId'];

// Auto-populate fields immediately (no polling needed)
setState(() {
  _invoices[index].invoiceNumber = extractedData['invoiceNumber'] ?? '';
  _invoices[index].totalAmount = extractedData['totalAmount']?.toString() ?? '';
  // ...
});
```

## Benefits

✅ **No Duplicate Processing**: Extraction happens only once
✅ **Faster Response**: No need to poll for results
✅ **Cost Savings**: Reduces Azure OpenAI API calls by 50%
✅ **Simpler Code**: No background processing, no polling logic
✅ **Immediate Feedback**: User sees extracted data instantly
✅ **Consistent Behavior**: Same API for preview and final submission

## API Comparison

### Before (Two APIs)
```
1. POST /documents/extract (preview)
   - Upload to temp
   - Extract
   - Delete temp
   - Return data

2. POST /documents/upload (final)
   - Upload to permanent
   - Save to DB
   - Trigger background extraction (DUPLICATE!)
   - Poll for results
```

### After (One API)
```
POST /documents/extract?packageId=xxx
   - Upload to permanent (if packageId)
   - Extract
   - Save to DB (if packageId)
   - Return data + documentId
   - No polling needed!
```

## Migration Steps

1. ✅ Update backend extract endpoint to accept packageId
2. ✅ Add database save logic when packageId provided
3. ⏳ Update frontend to use extract API with packageId
4. ⏳ Remove polling logic from frontend
5. ⏳ Remove background processing from upload API (optional cleanup)
6. ⏳ Test end-to-end flow

## Testing

```bash
# Test extract with packageId (extract + save)
curl -X POST http://localhost:5000/api/documents/extract \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@invoice.pdf" \
  -F "documentType=invoice" \
  -F "packageId=DRAFT_SUBMISSION_ID"

# Response includes extracted data AND documentId
{
  "extractedData": {
    "invoiceNumber": "INV-001",
    "totalAmount": 1000.00,
    ...
  },
  "documentId": "guid",
  "packageId": "guid",
  "blobUrl": "https://..."
}
```

## Next Steps

1. Update `invoice_list_section.dart` to use extract API
2. Remove `_pollInvoiceExtraction` method (no longer needed)
3. Update other document types (CostSummary, ActivitySummary) similarly
4. Test complete flow from draft creation to submission
5. Monitor Azure OpenAI usage to confirm cost savings
