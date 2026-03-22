# Draft Submission Workflow Implementation

## Overview
Implemented a draft submission workflow where:
1. A new submission ID is created immediately when user clicks "New Submission"
2. Invoice files are uploaded automatically when selected
3. Invoice data is extracted and processed automatically in the background

## ✅ IMPLEMENTATION COMPLETE

### Backend Changes (DONE)

#### 1. Updated CreateDraft Endpoint
**File**: `backend/src/BajajDocumentProcessing.API/Controllers/SubmissionsController.cs`

- Made `CreateDraftRequest` fields optional (PoId and AgencyId)
- Draft can now be created without a PO selected
- AgencyId defaults to authenticated user's agency
- Creates DocumentPackage with `State = PackageState.Draft`

#### 2. Updated CreateDraftRequest DTO
**File**: `backend/src/BajajDocumentProcessing.Application/DTOs/Submissions/CreateDraftRequest.cs`

- Removed `[Required]` attributes from PoId and AgencyId
- Both fields are now nullable

#### 3. Added Automatic Invoice Processing
**File**: `backend/src/BajajDocumentProcessing.API/Controllers/DocumentsController.cs`

- Added `IServiceScopeFactory` to constructor for background processing
- When an Invoice is uploaded, triggers automatic processing in background:
  - Extracts invoice data using DocumentAgent
  - Updates invoice entity with extracted fields
  - Logs processing status
- Processing happens asynchronously without blocking the upload response

#### 4. Added ExtractInvoiceDataAsync Method
**Files**: 
- `backend/src/BajajDocumentProcessing.Application/Common/Interfaces/IDocumentAgent.cs`
- `backend/src/BajajDocumentProcessing.Infrastructure/Services/DocumentAgent.cs`

- Added wrapper method `ExtractInvoiceDataAsync(blobUrl, fileName, cancellationToken)`
- Provides filename context for logging
- Calls existing `ExtractInvoiceAsync` method

### Frontend Changes (DONE)

#### 1. Create Draft on "New Submission" Click ✅
**File**: `frontend/lib/features/submission/presentation/pages/agency_dashboard_page.dart`

Updated `_navigateToUpload()` method to:
- Call `/api/submissions/draft` endpoint with empty body
- Get submissionId from response
- Navigate to upload page with submissionId parameter
- Show error message if draft creation fails

```dart
void _navigateToUpload() async {
  try {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'));
    final response = await dio.post(
      '/submissions/draft',
      data: {},
      options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
    );
    
    if (response.statusCode == 201 && mounted) {
      final submissionId = response.data['submissionId'];
      context.pushNamed('agency-upload', extra: {
        'token': widget.token,
        'userName': widget.userName,
        'submissionId': submissionId,
      });
    }
  } catch (e) {
    // Show error snackbar
  }
}
```

#### 2. Auto-Upload Invoice on File Selection ✅
**File**: `frontend/lib/features/submission/presentation/widgets/invoice_list_section.dart`

Updated `_pickInvoiceFile()` method to:
- Upload file immediately after selection
- Show upload progress
- Poll for extraction results every 2 seconds
- Auto-populate invoice fields when extraction completes
- Show success/error messages

Added new methods:
- `_uploadInvoiceFile(index)` - Uploads invoice to backend
- `_pollInvoiceExtraction(documentId, index)` - Polls for extraction results

## How It Works

### User Flow
1. User clicks "New Submission" button on dashboard
2. System creates draft submission (POST /api/submissions/draft)
3. User is navigated to upload page with submissionId
4. User selects invoice PDF file
5. File uploads automatically to backend
6. Backend processes invoice in background (5-10 seconds)
7. Frontend polls for results and auto-fills invoice fields
8. User can continue with other documents

### API Flow

#### Draft Creation
```
User clicks "New Submission"
   ↓
POST /api/submissions/draft
Body: {}
   ↓
Backend creates DocumentPackage
State: Draft
   ↓
Returns: { submissionId: "guid" }
   ↓
Navigate to /agency-upload?submissionId=guid
```

#### Invoice Upload & Processing
```
User selects invoice.pdf
   ↓
POST /api/documents/upload
FormData: file, documentType=Invoice, packageId
   ↓
Backend uploads to Azure Blob
   ↓
Backend creates Invoice entity
   ↓
Backend triggers background processing
   ↓
Returns: { documentId: "guid" } (immediate)
   ↓
Background: Azure OpenAI extracts data
   ↓
Background: Updates Invoice entity
   ↓
Frontend polls GET /invoices/{documentId}
   ↓
Frontend auto-fills invoice fields
```

## Testing

### Test the Complete Flow

1. **Start Backend**
```bash
cd backend
dotnet run --project src/BajajDocumentProcessing.API
```

2. **Start Frontend**
```bash
cd frontend
flutter run -d chrome
```

3. **Test Steps**
- Login as Agency user
- Click "New Submission" or "New Request" button
- Check browser network tab - should see POST to /submissions/draft
- Verify you're navigated to upload page
- Click "Upload Invoice" button
- Select a PDF invoice file
- Check network tab - should see POST to /documents/upload
- Wait 5-10 seconds
- Invoice fields should auto-populate with extracted data

### Manual API Testing

```bash
# 1. Create draft
curl -X POST http://localhost:5000/api/submissions/draft \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}'

# Response: { "submissionId": "guid", "submissionNumber": null }

# 2. Upload invoice
curl -X POST http://localhost:5000/api/documents/upload \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@invoice.pdf" \
  -F "documentType=Invoice" \
  -F "packageId=SUBMISSION_ID_FROM_STEP_1"

# Response: { "documentId": "guid", "packageId": "guid", ... }

# 3. Check extraction status (poll this)
curl -X GET http://localhost:5000/api/invoices/DOCUMENT_ID_FROM_STEP_2 \
  -H "Authorization: Bearer YOUR_TOKEN"

# Response will include extracted fields after processing completes
```

## Database State

### DocumentPackage States
- **Draft**: Initial state when draft is created (NEW)
- **Uploaded**: When all required documents are uploaded
- **Extracting**: When AI extraction is in progress
- **Validating**: When validation is running
- **PendingApproval**: Ready for review

### Invoice Entity Fields Auto-Populated
- InvoiceNumber
- InvoiceDate
- VendorName
- GSTNumber
- SubTotal
- TaxAmount
- TotalAmount
- ExtractedDataJson (full JSON)
- ExtractionConfidence (0.0 to 1.0)

## Benefits

✅ Immediate submission ID generation - no waiting
✅ Automatic file upload on selection - one less click
✅ Background AI processing without blocking - better UX
✅ Auto-populated fields - less manual data entry
✅ Real-time feedback with polling - user sees progress
✅ Reduced manual steps for users - faster workflow
✅ Consistent state management - no orphaned files

## Known Limitations

1. **Polling Duration**: Currently polls for 30 seconds (15 attempts × 2 seconds). If extraction takes longer, fields won't auto-populate.
2. **No Progress Indicator**: User doesn't see extraction progress percentage.
3. **Single Invoice Only**: Auto-upload works for first invoice, multiple invoices need manual handling.
4. **No Retry**: If extraction fails, user must re-upload the file.

## Future Enhancements

1. **WebSocket Support**: Replace polling with real-time updates
2. **Progress Indicator**: Show extraction progress (0-100%)
3. **Batch Upload**: Support multiple invoice auto-upload
4. **Retry Mechanism**: Allow retry if extraction fails
5. **Offline Support**: Queue uploads when offline
6. **File Validation**: Validate file before upload (size, type, content)
