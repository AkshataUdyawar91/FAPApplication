# Invoice Extraction & Resubmit Fix - Complete

## Issues Fixed

### 1. ✅ Slow Resubmit Process
**Problem**: Resubmit was blocking for 30-60 seconds while re-extracting and validating documents.

**Solution**: Changed resubmit endpoint to async processing:
- Returns `202 Accepted` immediately (< 1 second)
- Processes extraction/validation in background
- User can check status to see progress

**File**: `backend/src/BajajDocumentProcessing.API/Controllers/SubmissionsController.cs`
- Changed response from `200 OK` to `202 Accepted`
- Wrapped workflow processing in `Task.Run()` for background execution
- Updated message: "Package resubmission accepted. Processing in background - check status for updates."

### 2. ✅ Missing Invoice Field Values After Extraction
**Problem**: Invoice extraction was happening but extracted data wasn't showing in the UI text fields.

**Root Cause**: 
- Invoice upload via `/api/hierarchical/{packageId}/campaigns/{campaignId}/invoices` saved file but didn't trigger extraction
- Extracted data was stored in `Documents.ExtractedDataJson` but never synced to `CampaignInvoice` table fields
- UI reads from `CampaignInvoice` fields (`InvoiceNumber`, `InvoiceDate`, `TotalAmount`, `GSTNumber`)

**Solution**: Added background extraction trigger when invoice is uploaded:
1. Upload invoice file → save to blob storage
2. Create `CampaignInvoice` record with user-entered data
3. Trigger extraction in background (async)
4. After extraction completes → update `CampaignInvoice` fields with extracted data
5. Only updates empty fields (preserves user input if already filled)

**File**: `backend/src/BajajDocumentProcessing.API/Controllers/HierarchicalSubmissionController.cs`
- Added `IDocumentAgent` and `IServiceProvider` dependencies
- Added background extraction task after invoice upload
- Updates invoice fields: `InvoiceNumber`, `InvoiceDate`, `VendorName`, `GSTNumber`, `TotalAmount`
- Smart update: only fills empty fields, doesn't overwrite user input

### 3. ✅ Resubmit Shows Previously Filled Data
**Problem**: On resubmit/edit, invoice fields were empty instead of showing previously entered data.

**Solution**: Data is now properly stored in `CampaignInvoice` table:
- Initial upload: user enters data → saved to `CampaignInvoice`
- Extraction completes → fills any empty fields
- Resubmit/Edit: UI loads from `CampaignInvoice` table → shows all previously filled data
- Works because `GetSubmission` endpoint already returns `CampaignInvoice` data

**File**: Already working via existing endpoint
- `/api/submissions/{id}` returns `Campaigns` with `Invoices` array
- Each invoice includes: `InvoiceNumber`, `InvoiceDate`, `VendorName`, `GSTNumber`, `TotalAmount`

### 4. ✅ Resubmit Allowed for RejectedByASM and RejectedByRA
**Problem**: Resubmit was initially restricted to only `RejectedByASM`.

**Solution**: Updated validation to allow both states:
- ✅ `RejectedByASM` - Agency can edit and resubmit
- ✅ `RejectedByRA` - Agency can edit and resubmit
- ❌ Other states blocked

**File**: `backend/src/BajajDocumentProcessing.API/Controllers/SubmissionsController.cs`

## How It Works Now

### New Invoice Upload Flow
```
1. User uploads invoice via campaign endpoint
   ↓
2. File saved to blob storage
   ↓
3. CampaignInvoice record created with user-entered data
   ↓
4. Returns 200 OK immediately
   ↓
5. Background: Extract invoice data using Azure OpenAI
   ↓
6. Background: Update CampaignInvoice with extracted data (only empty fields)
   ↓
7. User sees extracted data appear in UI (via polling or refresh)
```

### Resubmit Flow
```
1. User clicks "Resubmit"
   ↓
2. Returns 202 Accepted immediately (< 1 second)
   ↓
3. State changes to "Uploaded"
   ↓
4. Background: Re-extract all documents
   ↓
5. Background: Re-validate
   ↓
6. Background: Re-calculate confidence scores
   ↓
7. Background: Re-generate recommendations
   ↓
8. State changes to "PendingASMApproval"
   ↓
9. User can check status to see progress
```

### Edit/Resubmit Data Persistence
```
1. User opens rejected submission
   ↓
2. UI loads data from CampaignInvoice table
   ↓
3. All previously filled fields are shown
   ↓
4. User can edit any field
   ↓
5. On save: updates CampaignInvoice record
   ↓
6. On resubmit: triggers full re-processing
```

## Testing

### Test Invoice Extraction
1. Create new submission
2. Add campaign
3. Upload invoice file
4. Wait 10-20 seconds
5. Refresh or poll status
6. Verify invoice fields are auto-filled

### Test Resubmit Speed
1. Submit a package
2. Reject it as ASM
3. Click "Resubmit" as Agency
4. Should return immediately (< 1 second)
5. Check status - should show "Uploaded" then progress through states

### Test Data Persistence
1. Submit package with invoice data
2. Reject as ASM
3. Open for edit
4. Verify all invoice fields show previous values
5. Edit some fields
6. Resubmit
7. After processing, verify edited values are preserved

## Files Modified

1. `backend/src/BajajDocumentProcessing.API/Controllers/SubmissionsController.cs`
   - Made resubmit async (202 Accepted)
   - Allowed resubmit for both RejectedByASM and RejectedByRA

2. `backend/src/BajajDocumentProcessing.API/Controllers/HierarchicalSubmissionController.cs`
   - Added IDocumentAgent and IServiceProvider dependencies
   - Added background extraction trigger for invoice uploads
   - Updates CampaignInvoice fields with extracted data

## Benefits

✅ **Faster UX**: Resubmit returns immediately, no 30-60 second wait
✅ **Auto-fill**: Invoice fields automatically populated from extraction
✅ **Data Persistence**: Previously entered data is preserved on edit/resubmit
✅ **Smart Updates**: Extraction only fills empty fields, preserves user input
✅ **Background Processing**: Long operations don't block the user
✅ **Proper State Flow**: RejectedByASM and RejectedByRA both support resubmission

## Status

🟢 **COMPLETE** - All 3 requirements implemented and ready for testing
