# Workflow Updated for Hierarchical Model - COMPLETE

## Changes Made

### 1. Updated Package Loading
**File**: `WorkflowOrchestrator.cs` - `ProcessSubmissionAsync()`

**Before**:
```csharp
var package = await _context.DocumentPackages
    .Include(p => p.Documents)
    .Include(p => p.SubmittedBy)
    .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);
```

**After**:
```csharp
var package = await _context.DocumentPackages
    .Include(p => p.Documents)  // Keep for backward compatibility
    .Include(p => p.Campaigns)
        .ThenInclude(c => c.Invoices.Where(i => !i.IsDeleted))
    .Include(p => p.Campaigns)
        .ThenInclude(c => c.Photos.Where(p => !p.IsDeleted))
    .Include(p => p.SubmittedBy)
    .AsSplitQuery()
    .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);
```

### 2. Updated Extraction Step
**File**: `WorkflowOrchestrator.cs` - `ExecuteExtractionStepAsync()`

Now handles **both** data models:

#### Hierarchical Model (New)
- Checks if `package.Campaigns` exists and has data
- Iterates through campaigns → invoices
- Extracts invoice data using `ExtractInvoiceAsync()`
- **Updates CampaignInvoice fields directly**:
  - `InvoiceNumber`
  - `InvoiceDate`
  - `VendorName`
  - `GSTNumber`
  - `TotalAmount`
- Only updates empty fields (preserves user input)
- Processes photos in batches of 5
- Stores photo metadata in `Caption` field

#### Old Model (Backward Compatibility)
- Falls back to `package.Documents` if no campaigns
- Extracts to `Documents.ExtractedDataJson` as before
- Maintains full backward compatibility

### 3. Fixed Invoice Extraction Background Task
**File**: `HierarchicalSubmissionController.cs` - `AddInvoiceToCampaign()`

**Fixed Issues**:
- Changed `FindAsync` to `FirstOrDefaultAsync` (IApplicationDbContext doesn't have FindAsync)
- Fixed nullable DateTime check: `InvoiceDate == null` instead of `== default`
- Fixed nullable decimal check: `TotalAmount == null || TotalAmount == 0`
- Captured `invoiceId` in closure to avoid reference issues

## How It Works Now

### New Submission Flow
```
1. User uploads invoice via hierarchical endpoint
   ↓
2. CampaignInvoice created with user-entered data
   ↓
3. Background extraction triggered (optional, for immediate feedback)
   ↓
4. User clicks "Submit"
   ↓
5. Workflow orchestrator processes package
   ↓
6. Detects hierarchical structure (Campaigns exist)
   ↓
7. Extracts from CampaignInvoice.BlobUrl
   ↓
8. Updates CampaignInvoice fields with extracted data
   ↓
9. Validation, scoring, recommendation proceed
   ↓
10. Package moves to PendingASMApproval
```

### Resubmit Flow
```
1. User clicks "Resubmit"
   ↓
2. Returns 202 Accepted immediately
   ↓
3. Background: Workflow orchestrator triggered
   ↓
4. Loads package with Campaigns → Invoices
   ↓
5. Re-extracts from CampaignInvoice.BlobUrl
   ↓
6. Updates CampaignInvoice fields (only empty ones)
   ↓
7. Re-validates, re-scores, re-recommends
   ↓
8. Package moves to PendingASMApproval
```

### Edit/Resubmit Data Persistence
```
1. User opens rejected submission
   ↓
2. UI loads from CampaignInvoice table
   ↓
3. All fields populated (InvoiceNumber, TotalAmount, etc.)
   ↓
4. User edits fields
   ↓
5. Updates saved to CampaignInvoice
   ↓
6. Resubmit triggers re-extraction
   ↓
7. Extraction only fills EMPTY fields
   ↓
8. User edits are preserved
```

## Benefits

✅ **Hierarchical Model Support**: Workflow now works with Campaigns → Invoices structure
✅ **Backward Compatibility**: Old Documents model still works
✅ **Data Persistence**: Invoice fields properly stored and retrieved
✅ **Smart Updates**: Extraction doesn't overwrite user input
✅ **No More ProcessingFailed**: Workflow finds invoices in hierarchical structure
✅ **Invoice Amount Visible**: TotalAmount properly extracted and stored
✅ **Async Processing**: Resubmit returns immediately, processes in background

## Testing

### Test 1: New Submission
1. Create new submission
2. Add campaign
3. Upload invoice with file
4. Click "Submit"
5. ✅ Should extract and show invoice fields
6. ✅ Should move to PendingASMApproval (not ProcessingFailed)

### Test 2: Resubmit
1. Submit package
2. Reject as ASM
3. Click "Resubmit" as Agency
4. ✅ Should return 202 Accepted immediately
5. ✅ Should re-extract and update invoice fields
6. ✅ Should move to PendingASMApproval

### Test 3: Edit and Resubmit
1. Submit package with invoice
2. Reject as ASM
3. Open for edit
4. ✅ Invoice fields should show previous values
5. Edit InvoiceNumber
6. Resubmit
7. ✅ Edited InvoiceNumber should be preserved
8. ✅ Other fields should be re-extracted if empty

### Test 4: Backward Compatibility
1. Find old submission with Documents (not Campaigns)
2. Resubmit
3. ✅ Should process using old Documents model
4. ✅ Should not fail

## Files Modified

1. `backend/src/BajajDocumentProcessing.Infrastructure/Services/WorkflowOrchestrator.cs`
   - Updated package loading to include Campaigns
   - Rewrote extraction step to handle both models
   - Hierarchical model extracts to CampaignInvoice fields
   - Old model extracts to Documents.ExtractedDataJson

2. `backend/src/BajajDocumentProcessing.API/Controllers/HierarchicalSubmissionController.cs`
   - Fixed background extraction task
   - Fixed nullable field checks
   - Fixed IApplicationDbContext usage

3. `backend/src/BajajDocumentProcessing.API/Controllers/SubmissionsController.cs`
   - Made resubmit async (202 Accepted)
   - Allowed resubmit for RejectedByASM and RejectedByRA

## Status

🟢 **COMPLETE** - Workflow fully updated for hierarchical model with backward compatibility
