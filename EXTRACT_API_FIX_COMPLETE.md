# Extract API Fix - Complete Implementation

## Problem Identified
The extract API wasn't saving invoices to the database because:
1. ❌ Frontend wasn't sending `packageId` to extract API
2. ❌ Extract API was missing PO validation logic
3. ❌ Extract API wasn't setting required fields (POId, VersionNumber, CreatedBy)

## Solution Implemented ✅

### Backend Changes (DONE)

#### Updated Extract API
**File**: `backend/src/BajajDocumentProcessing.API/Controllers/DocumentsController.cs`

Now properly:
1. ✅ Validates PO exists before creating invoice
2. ✅ Gets POId from package.SelectedPOId or finds PO in package
3. ✅ Sets VersionNumber from package
4. ✅ Sets CreatedBy/UpdatedBy fields
5. ✅ Logs detailed information for debugging

```csharp
// CRITICAL: Validate PO exists (same as upload API)
var existingPo = package.SelectedPOId.HasValue
    ? await _context.POs.FirstOrDefaultAsync(p => p.Id == package.SelectedPOId.Value)
    : await _context.POs.FirstOrDefaultAsync(p => p.PackageId == packageId.Value);

if (existingPo == null)
{
    return BadRequest(new { error = "Cannot upload invoice: no Purchase Order is linked..." });
}

var invoice = new Invoice
{
    PackageId = packageId.Value,
    POId = existingPo.Id,  // ✅ Link to existing PO
    VersionNumber = package.VersionNumber,  // ✅ Match package version
    CreatedBy = userId.ToString(),  // ✅ Set creator
    // ... all extracted fields
};
```

### Frontend Changes (DONE)

#### 1. Updated agency_upload_page.dart
**File**: `frontend/lib/features/submission/presentation/pages/agency_upload_page.dart`

```dart
// OLD: No packageId sent
final formDataMap = {
  'file': ...,
  'documentType': 'Invoice',
};

// NEW: Include packageId if available
final formDataMap = {
  'file': ...,
  'documentType': 'Invoice',
};

if (_currentPackageId != null && _currentPackageId!.isNotEmpty) {
  formDataMap['packageId'] = _currentPackageId;  // ✅ Send packageId
}
```

#### 2. Updated invoice_list_section.dart
**File**: `frontend/lib/features/submission/presentation/widgets/invoice_list_section.dart`

```dart
// OLD: Used upload API with polling
await dio.post('/documents/upload', ...);
_pollInvoiceExtraction(documentId, index);

// NEW: Use extract API with packageId (no polling needed!)
final formData = FormData.fromMap({
  'file': ...,
  'documentType': 'invoice',
  'packageId': widget.packageId,  // ✅ Include packageId
});

final response = await dio.post('/documents/extract', data: formData);

// Data is already extracted and saved!
final extractedData = response.data['extractedData'];
final documentId = response.data['documentId'];

// Auto-populate immediately (no polling!)
setState(() {
  _invoices[index].invoiceNumber = extractedData['invoiceNumber'];
  // ...
});
```

## Complete Flow Now

### 1. User clicks "New Submission"
```
POST /api/submissions/draft
Response: { submissionId: "guid" }
```

### 2. User selects invoice file
```
Frontend automatically calls:

POST /api/documents/extract
FormData:
  - file: invoice.pdf
  - documentType: invoice
  - packageId: <submission_id_from_step_1>  ✅ NOW INCLUDED

Backend:
  1. Uploads to permanent blob
  2. Extracts data using Azure OpenAI
  3. Validates PO exists
  4. Creates Invoice entity with:
     - PackageId ✅
     - POId ✅
     - VersionNumber ✅
     - All extracted fields ✅
     - CreatedBy/UpdatedBy ✅
  5. Saves to database
  6. Returns extracted data + documentId

Frontend:
  - Receives response immediately
  - Auto-populates invoice fields
  - Shows success message
  - NO POLLING NEEDED!
```

## Database Verification

After uploading an invoice, check the Invoices table:

```sql
SELECT 
    Id,
    PackageId,
    POId,
    InvoiceNumber,
    InvoiceDate,
    VendorName,
    TotalAmount,
    GSTNumber,
    VersionNumber,
    CreatedBy,
    CreatedAt
FROM Invoices
ORDER BY CreatedAt DESC;
```

You should now see:
- ✅ Invoice record created
- ✅ PackageId populated
- ✅ POId populated (linked to PO)
- ✅ All extracted fields populated
- ✅ VersionNumber set
- ✅ CreatedBy set

## Testing Steps

1. **Start backend**:
```bash
cd backend
dotnet run --project src/BajajDocumentProcessing.API
```

2. **Start frontend**:
```bash
cd frontend
flutter run -d chrome
```

3. **Test flow**:
   - Login as Agency user
   - Click "New Submission" → Draft created with submissionId
   - Select a PO (or upload PO first)
   - Upload invoice PDF
   - Check browser network tab:
     - Should see POST to `/documents/extract`
     - Request should include `packageId` in FormData
   - Invoice fields auto-populate immediately
   - Check database: Invoice record should exist

4. **Verify in database**:
```sql
-- Check if invoice was saved
SELECT * FROM Invoices WHERE PackageId = '<your_submission_id>';

-- Check if PO link is correct
SELECT 
    i.InvoiceNumber,
    i.TotalAmount,
    p.PONumber,
    p.TotalAmount as POAmount
FROM Invoices i
JOIN POs p ON i.POId = p.Id
WHERE i.PackageId = '<your_submission_id>';
```

## Benefits Achieved

✅ **Single API call** - No duplicate processing
✅ **Instant results** - No polling, data returned immediately
✅ **Database saved** - Invoice record created with all fields
✅ **PO validation** - Ensures PO exists before creating invoice
✅ **Proper relationships** - POId correctly linked
✅ **50% cost savings** - No duplicate Azure OpenAI calls
✅ **Simpler code** - No background processing, no polling

## Troubleshooting

### If invoice still not saving:

1. **Check backend logs** for:
   - "PackageId: {PackageId}" in extraction log
   - "PO found" or "No PO found" message
   - "Invoice saved to database" success message

2. **Check browser network tab**:
   - POST to `/documents/extract` should include `packageId` in FormData
   - Response should include `documentId` (not null)

3. **Check database**:
   - Does the package exist? `SELECT * FROM DocumentPackages WHERE Id = '<packageId>'`
   - Does a PO exist for this package? `SELECT * FROM POs WHERE PackageId = '<packageId>'`
   - Or is SelectedPOId set? Check `DocumentPackages.SelectedPOId`

4. **Common issues**:
   - No PO selected → Invoice creation fails with error message
   - PackageId not sent → Invoice not saved (temp extraction only)
   - Wrong documentType case → Use lowercase 'invoice' not 'Invoice'
