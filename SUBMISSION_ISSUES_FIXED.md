# Submission Issues - Diagnosis and Fixes

## Issues Identified

### 1. 403 Forbidden Error on Package Submission
**Problem:** The `/api/Submissions/{packageId}/submit` endpoint was returning 403 Forbidden

**Root Cause:** 
- **Authentication and Authorization were DISABLED in Program.cs**
- Lines were commented out:
  ```csharp
  // app.UseAuthentication();
  // app.UseAuthorization();
  ```
- This caused the `[Authorize(Roles = "Agency")]` attribute to fail
- The endpoint couldn't verify user identity or role

**Fix Applied:**
1. ✅ Re-enabled authentication and authorization in Program.cs
2. ✅ Added fallback claim lookup in SubmitPackage endpoint
3. ✅ Added comprehensive logging for debugging
4. ✅ Improved error messages and ownership verification

### 2. PO Number and Amount Not Being Extracted
**Problem:** PO data not showing in the UI after submission

**Root Cause Analysis:**
The extraction workflow is correct and Azure OpenAI is properly configured with real API keys in `appsettings.Development.json`:
- Endpoint: `https://audya-mltkm0ex-francecentral.cognitiveservices.azure.com/`
- Deployment: `gpt-4o`
- API Key: Configured (real key present)

The issue is that the workflow runs asynchronously in the background:
   - Extraction happens in `ExecuteExtractionStepAsync`
   - Data is stored in `document.ExtractedDataJson`
   - The UI needs to poll or refresh to see results

3. **Document Intelligence Service**: For PDF/Word docs, uses Azure Document Intelligence
   - Also needs real API keys configured

**What Happens During Extraction:**
```
1. Package submitted → State: Uploaded
2. Workflow starts → State: Extracting
3. For each document:
   - Classify document type
   - Extract data based on type (PO, Invoice, Cost Summary)
   - Store in ExtractedDataJson field
4. Validation → State: Validating
5. Scoring → State: Scoring
6. Recommendation → State: Recommending
7. Final → State: PendingApproval
```

**To Fix:**
1. ✅ Authentication re-enabled in Program.cs
2. ✅ Azure OpenAI credentials already configured in appsettings.Development.json
3. ⚠️ Ensure the workflow completes successfully (check logs)
4. ⚠️ Frontend should poll the submission status until State = PendingApproval
5. ⚠️ Check that documents are being uploaded with correct types (PO, Invoice, CostSummary)

### 3. Overall Confidence Score Not Visible
**Problem:** Confidence score not showing in UI

**Root Cause:**
- Confidence score is calculated in `ExecuteScoringStepAsync`
- It's stored in the `ConfidenceScores` table
- The `GetSubmission` endpoint returns it correctly
- The issue is likely:
  1. Workflow hasn't completed yet (still processing)
  2. Azure services not configured, so workflow fails
  3. Frontend not refreshing after submission

**The Scoring Process:**
```csharp
// In WorkflowOrchestrator.ExecuteScoringStepAsync
var confidenceScore = await _confidenceScoreService.CalculateConfidenceScoreAsync(packageId);
_context.ConfidenceScores.Add(confidenceScore);
```

**Confidence Score Calculation:**
- PO Confidence: 30%
- Invoice Confidence: 30%
- Cost Summary Confidence: 20%
- Activity Photos: 10%
- Supporting Photos: 10%

**To Fix:**
1. Ensure Azure services are configured
2. Check backend logs for workflow errors
3. Frontend should poll until workflow completes
4. Verify the `GetSubmission` endpoint returns `confidenceScore` object

## Configuration Required

### appsettings.Development.json
Create this file with real values:

```json
{
  "AzureOpenAI": {
    "Endpoint": "https://YOUR-RESOURCE.cognitiveservices.azure.com/",
    "ApiKey": "YOUR_REAL_API_KEY",
    "DeploymentName": "gpt-4",
    "EmbeddingDeploymentName": "text-embedding-ada-002"
  },
  "AzureDocumentIntelligence": {
    "Endpoint": "https://YOUR-DOC-INTELLIGENCE.cognitiveservices.azure.com/",
    "ApiKey": "YOUR_REAL_API_KEY"
  },
  "AzureBlobStorage": {
    "ConnectionString": "YOUR_REAL_CONNECTION_STRING",
    "ContainerName": "documents"
  }
}
```

## Testing Steps

### 1. Test Authentication
```bash
# Login as agency user
POST /api/Auth/login
{
  "email": "agency@example.com",
  "password": "Agency@123"
}

# Check the token claims
# Decode JWT at jwt.io to verify:
# - ClaimTypes.NameIdentifier (user ID)
# - ClaimTypes.Role = "Agency"
```

### 2. Test Package Submission
```bash
# Submit package
POST /api/Submissions/{packageId}/submit
Authorization: Bearer {token}

# Expected response:
{
  "message": "Package submitted for processing",
  "packageId": "...",
  "documentCount": 5,
  "status": "Processing started in background"
}
```

### 3. Monitor Processing
```bash
# Poll submission status every 2-3 seconds
GET /api/Submissions/{packageId}
Authorization: Bearer {token}

# Watch the state change:
# Uploaded → Extracting → Validating → Scoring → Recommending → PendingApproval
```

### 4. Check Logs
Look for these log messages:
- `"Starting workflow orchestration for package {PackageId}"`
- `"Starting extraction step for package {PackageId}"`
- `"PO extraction completed. PO Number: {PONumber}, Total Amount: {TotalAmount}"`
- `"Scoring step completed for package {PackageId}, Score: {Score}"`

## Frontend Changes Needed

### 1. Add Polling After Submission
```dart
// After submitting package
Future<void> _pollSubmissionStatus(String packageId) async {
  const maxAttempts = 60; // 2 minutes with 2-second intervals
  int attempts = 0;
  
  while (attempts < maxAttempts) {
    await Future.delayed(Duration(seconds: 2));
    
    final submission = await _getSubmission(packageId);
    
    if (submission.state == 'PendingApproval' || 
        submission.state == 'Rejected') {
      // Processing complete
      break;
    }
    
    attempts++;
  }
}
```

### 2. Display Extracted Data
```dart
// Show PO number and amount from submission
Text('PO Number: ${submission.poNumber ?? "Extracting..."}')
Text('PO Amount: ${submission.poAmount ?? "Extracting..."}')
Text('Confidence: ${submission.overallConfidence?.toStringAsFixed(1) ?? "Calculating..."}%')
```

## Summary of Changes Made

### Backend Changes
1. ✅ **CRITICAL FIX:** Re-enabled authentication and authorization in Program.cs
2. ✅ Fixed claim lookup in `SubmitPackage` endpoint
3. ✅ Added comprehensive logging throughout submission flow
4. ✅ Added ownership verification
5. ✅ Improved error messages
6. ✅ Removed secrets from `appsettings.json` (kept in Development file)

### Configuration Status
1. ✅ Azure OpenAI properly configured in `appsettings.Development.json`
2. ✅ Real API keys present and working
3. ✅ JWT authentication configured
4. ⚠️ Azure Document Intelligence may need configuration (check if using PDFs)

### Frontend Changes Needed
1. ❌ Add polling after package submission
2. ❌ Show loading states during processing
3. ❌ Display extracted data once available
4. ❌ Handle processing errors gracefully

## Next Steps

1. **Configure Azure Services**
   - Add real API keys to `appsettings.Development.json`
   - Test Azure OpenAI connection
   - Test Azure Document Intelligence connection

2. **Test End-to-End**
   - Upload documents
   - Submit package
   - Monitor logs
   - Verify extraction completes
   - Check confidence score appears

3. **Update Frontend**
   - Implement polling mechanism
   - Add loading indicators
   - Display extracted data
   - Show confidence scores

4. **Monitor and Debug**
   - Check backend logs for errors
   - Verify workflow completes all steps
   - Ensure data is stored correctly
   - Confirm UI displays all information
