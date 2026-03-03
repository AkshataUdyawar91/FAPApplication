# Document Extraction and ASM Visibility Fix

## Issues Identified

### 1. Invoice Data Not Showing
**Problem**: Invoice number and amount are not displayed in the agency dashboard.

**Root Cause**: 
- Documents are uploaded but data extraction is not happening automatically
- The `ExtractedDataJson` field remains null because Azure OpenAI extraction isn't triggered
- The workflow orchestrator needs to be called to process documents

### 2. ASM Cannot See Submissions
**Problem**: Submissions are not visible to ASM users.

**Root Cause**:
- Submissions stay in `Uploaded` state after document upload
- ASM can only see submissions in `PendingApproval` state
- The workflow needs to move submissions to `PendingApproval` after processing

## Current Flow (What's Happening)

```
1. Agency uploads documents
   ↓
2. Documents saved to database with State = "Uploaded"
   ↓
3. ExtractedDataJson = null (no extraction happens)
   ↓
4. Submission stays in "Uploaded" state
   ↓
5. ASM filters only show "PendingApproval" submissions
   ↓
6. Result: ASM sees nothing, Agency sees no invoice data
```

## Expected Flow (What Should Happen)

```
1. Agency uploads documents
   ↓
2. Documents saved to database
   ↓
3. Workflow Orchestrator triggered
   ↓
4. Document Agent extracts data using Azure OpenAI
   ↓
5. ExtractedDataJson populated with invoice number, amount, etc.
   ↓
6. Validation Agent validates data
   ↓
7. Confidence Score calculated
   ↓
8. Recommendation generated
   ↓
9. State changed to "PendingApproval"
   ↓
10. ASM can now see and review the submission
```

## Solutions

### Solution 1: Manual Trigger (Quick Fix for Testing)

Use the helper endpoint to manually move submissions to pending approval:

```bash
# After uploading all documents, call this endpoint
PATCH /api/submissions/{packageId}/move-to-pending
Authorization: Bearer {your-token}
```

This will:
- Change state from "Uploaded" to "PendingApproval"
- Make submission visible to ASM
- **Note**: This doesn't extract data, just changes state

### Solution 2: Trigger Workflow After Upload (Recommended)

The workflow orchestrator should be called after document upload. Currently it's only called when creating a submission via `/api/submissions` POST endpoint.

#### Option A: Call Workflow After Each Document Upload

Modify `DocumentService.UploadDocumentAsync` to trigger extraction:

```csharp
// After saving document
await _context.SaveChangesAsync();

// Trigger extraction for this document
_ = Task.Run(async () =>
{
    try
    {
        await _documentAgent.ClassifyAsync(document.BlobUrl);
        // Extract data based on type
        // Save extracted data
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Error extracting document {DocumentId}", document.Id);
    }
});
```

#### Option B: Process Package After All Documents Uploaded

Add an endpoint to finalize and process the package:

```csharp
[HttpPost("{packageId}/submit")]
public async Task<IActionResult> SubmitPackage(Guid packageId)
{
    // Trigger workflow orchestrator
    await _orchestrator.ProcessSubmissionAsync(packageId);
    return Ok();
}
```

### Solution 3: Enable Azure Services (Production Solution)

Configure the required Azure services so the workflow can run:

1. **Azure OpenAI** - ✅ Already configured
2. **Azure Blob Storage** - ⏳ Not configured (documents stored locally)
3. **Azure Communication Services** - ⏳ Not configured (emails disabled)

## Immediate Workaround

Since Azure Blob Storage is not configured, documents are being stored locally. The extraction won't work until we either:

1. Configure Azure Blob Storage
2. Modify the code to work with local file paths
3. Use the manual trigger endpoint

### Quick Test Steps

1. **Upload Documents** (as Agency user)
   ```bash
   POST /api/documents/upload
   - Upload PO
   - Upload Invoice (note the packageId)
   - Upload Cost Summary
   - Upload Photos
   ```

2. **Manually Move to Pending** (as Agency or ASM user)
   ```bash
   PATCH /api/submissions/{packageId}/move-to-pending
   ```

3. **View as ASM** (as ASM user)
   ```bash
   GET /api/submissions
   # Should now see the submission
   ```

4. **Approve/Reject** (as ASM user)
   ```bash
   PATCH /api/submissions/{packageId}/approve
   # or
   PATCH /api/submissions/{packageId}/reject
   ```

## Code Changes Needed

### 1. Fix Document Extraction Flow

File: `backend/src/BajajDocumentProcessing.Infrastructure/Services/DocumentService.cs`

Add after document save:

```csharp
// Trigger extraction asynchronously
if (_documentAgent != null && !string.IsNullOrEmpty(document.BlobUrl))
{
    _ = Task.Run(async () =>
    {
        try
        {
            // Classify document
            var classification = await _documentAgent.ClassifyAsync(document.BlobUrl);
            
            // Extract data based on type
            object? extractedData = documentType switch
            {
                DocumentType.PO => await _documentAgent.ExtractPOAsync(document.BlobUrl),
                DocumentType.Invoice => await _documentAgent.ExtractInvoiceAsync(document.BlobUrl),
                DocumentType.CostSummary => await _documentAgent.ExtractCostSummaryAsync(document.BlobUrl),
                DocumentType.Photo => await _documentAgent.ExtractPhotoMetadataAsync(document.BlobUrl),
                _ => null
            };

            if (extractedData != null)
            {
                // Save extracted data
                document.ExtractedDataJson = System.Text.Json.JsonSerializer.Serialize(extractedData);
                document.ExtractionConfidence = classification.Confidence;
                await _context.SaveChangesAsync();
                
                _logger.LogInformation("Extracted data for document {DocumentId}", document.Id);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error extracting document {DocumentId}", document.Id);
        }
    });
}
```

### 2. Add Package Submission Endpoint

File: `backend/src/BajajDocumentProcessing.API/Controllers/SubmissionsController.cs`

Add new endpoint:

```csharp
[HttpPost("{packageId}/process")]
[Authorize(Roles = "Agency")]
public async Task<IActionResult> ProcessPackage(Guid packageId, CancellationToken cancellationToken)
{
    try
    {
        var package = await _context.DocumentPackages
            .Include(p => p.Documents)
            .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

        if (package == null)
        {
            return NotFound(new { error = "Package not found" });
        }

        // Verify minimum documents
        if (!package.Documents.Any(d => d.Type == DocumentType.PO))
        {
            return BadRequest(new { error = "PO document is required" });
        }

        if (!package.Documents.Any(d => d.Type == DocumentType.Invoice))
        {
            return BadRequest(new { error = "Invoice document is required" });
        }

        // Trigger workflow
        _ = Task.Run(async () =>
        {
            try
            {
                await _orchestrator.ProcessSubmissionAsync(packageId, CancellationToken.None);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing package {PackageId}", packageId);
            }
        });

        return Ok(new { message = "Package processing started", packageId });
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Error processing package {PackageId}", packageId);
        return StatusCode(500, new { error = "An error occurred while processing the package" });
    }
}
```

## Testing Checklist

- [ ] Upload PO document
- [ ] Upload Invoice document
- [ ] Upload Cost Summary
- [ ] Upload activity photos
- [ ] Check if ExtractedDataJson is populated
- [ ] Check if invoice number shows in list
- [ ] Check if invoice amount shows in list
- [ ] Move submission to PendingApproval
- [ ] Login as ASM
- [ ] Verify submission is visible
- [ ] Approve or reject submission

## Current Limitations

1. **Azure Blob Storage not configured** - Documents stored locally, may not be accessible for extraction
2. **Workflow orchestrator not triggered** - Manual intervention needed
3. **No automatic state transitions** - Submissions stay in "Uploaded" state

## Recommended Next Steps

1. Configure Azure Blob Storage for document storage
2. Implement automatic workflow triggering after document upload
3. Add a "Submit Package" button in the frontend
4. Test end-to-end flow with real documents
5. Add validation for required documents before submission

---

**Status**: Issues identified. Workaround available. Code changes recommended for production.
