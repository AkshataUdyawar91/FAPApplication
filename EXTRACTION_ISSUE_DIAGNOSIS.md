# Extraction Issue Diagnosis

## Problem
PO number, amount, and confidence score are showing as empty/null:
```json
{
  "poNumber": "",
  "poAmount": 0,
  "overallConfidence": null
}
```

## Root Causes Identified

### 1. PDF Files Returning Placeholder Data ⚠️
**Log Evidence:**
```
warn: PDF file detected - returning placeholder data. Implement Document Intelligence for production.
```

**Issue:** The system detects PDF files but the Azure Document Intelligence service is returning placeholder data instead of actually extracting.

**Location:** `DocumentAgent.cs` - The extraction methods for PDFs

**Why:** Azure Document Intelligence may not be properly configured or the service is using a fallback/mock implementation.

### 2. Workflow Not Triggered ⚠️
**Missing Log:** No "Starting workflow orchestration" message in logs

**Issue:** The workflow orchestrator is NOT running, which means:
- No extraction happening for the full package
- No validation step
- No confidence scoring
- No recommendation generation

**Why:** The `/api/Submissions/{packageId}/submit` endpoint hasn't been called yet.

### 3. Individual Document Extraction vs Package Workflow
**What's Happening:**
- Documents are being uploaded one by one ✅
- Each document is extracted individually ✅
- BUT the full package workflow hasn't started ❌

**What Should Happen:**
1. Upload documents (PO, Invoice, Cost Summary, Photos)
2. **Call `/submit` endpoint** ← THIS IS MISSING
3. Workflow starts:
   - Extracts all documents
   - Validates cross-document consistency
   - Calculates confidence scores
   - Generates recommendation
4. Package state changes to `PendingApproval`

## Solutions

### Solution 1: Fix Azure Document Intelligence (For PDF Extraction)

The `AzureDocumentIntelligenceService` needs to be properly implemented. Currently it's returning placeholder data.

**Check Configuration:**
```json
// appsettings.Development.json
{
  "AzureDocumentIntelligence": {
    "Endpoint": "https://bajajdocumentinelligence.cognitiveservices.azure.com/",
    "ApiKey": "YOUR_REAL_API_KEY"  // ← Verify this is correct
  }
}
```

**Verify Service Implementation:**
The service at `backend/src/BajajDocumentProcessing.Infrastructure/Services/AzureDocumentIntelligenceService.cs` should be making real API calls, not returning mock data.

### Solution 2: Ensure Package Submission is Called

**Frontend Must Call:**
```dart
// After uploading all documents
await _submissionRepository.submitPackage(packageId);
```

**API Endpoint:**
```
POST /api/Submissions/{packageId}/submit
Authorization: Bearer {token}
```

**This triggers the workflow which:**
- Re-extracts all documents
- Validates data
- Calculates confidence scores
- Generates recommendations

### Solution 3: Use Image Files Instead of PDFs (Temporary Workaround)

If Azure Document Intelligence isn't configured, use image files (JPG/PNG) instead of PDFs. The system will use GPT-4 Vision which IS configured.

**Supported Formats:**
- ✅ JPG/JPEG - Uses GPT-4 Vision (working)
- ✅ PNG - Uses GPT-4 Vision (working)
- ⚠️ PDF - Uses Document Intelligence (needs configuration)
- ⚠️ DOCX - Uses Document Intelligence (needs configuration)

## Testing Steps

### Step 1: Check if Submission Was Called

Look for this log message:
```
[Information] User {UserId} submitting package {PackageId}
[Information] Starting workflow orchestration for package {PackageId}
```

**If NOT present:** The submit endpoint wasn't called. Frontend needs to call it.

**If present:** Continue to Step 2.

### Step 2: Check Workflow Progress

Look for these log messages in sequence:
```
[Information] Starting extraction step for package {PackageId}
[Information] PO extraction completed. PO Number: X, Total Amount: Y
[Information] Invoice extraction completed...
[Information] Starting validation step...
[Information] Starting scoring step...
[Information] Scoring step completed, Score: X
```

**If extraction fails:** Azure Document Intelligence issue (see Solution 1)

**If workflow doesn't start:** Submission not called (see Solution 2)

### Step 3: Verify Package State

Query the package:
```
GET /api/Submissions/{packageId}
```

**Expected state progression:**
- `Uploaded` → Initial state after document upload
- `Extracting` → Workflow started, extracting documents
- `Validating` → Validating extracted data
- `Scoring` → Calculating confidence scores
- `Recommending` → Generating AI recommendation
- `PendingApproval` → Complete, ready for review

**If stuck in `Uploaded`:** Submit endpoint not called

**If stuck in `Extracting`:** Extraction failing (check logs for errors)

## Quick Fix: Use Image Files

**Immediate workaround to test the system:**

1. Convert PDFs to images (JPG/PNG)
2. Upload image files instead
3. Submit the package
4. GPT-4 Vision will extract the data successfully

**Why this works:**
- GPT-4 Vision is configured and working
- Azure Document Intelligence needs additional setup
- Images work immediately, PDFs need Document Intelligence

## Recommended Actions

### Immediate (To Test System):
1. ✅ Use image files (JPG/PNG) instead of PDFs
2. ✅ Ensure frontend calls `/submit` endpoint after uploading
3. ✅ Monitor logs for workflow progress
4. ✅ Poll package status until `PendingApproval`

### Short Term (For PDF Support):
1. ⚠️ Configure Azure Document Intelligence properly
2. ⚠️ Verify API key and endpoint
3. ⚠️ Test Document Intelligence service independently
4. ⚠️ Implement proper error handling

### Long Term (Production Ready):
1. 📋 Implement robust Azure Document Intelligence integration
2. 📋 Add fallback to GPT-4 Vision if Document Intelligence fails
3. 📋 Add better error messages for extraction failures
4. 📋 Implement retry logic for failed extractions

## Summary

**The data is empty because:**
1. Package submission endpoint hasn't been called (workflow not started)
2. OR Azure Document Intelligence isn't configured (PDFs return placeholder data)

**To fix:**
1. Ensure frontend calls `/api/Submissions/{packageId}/submit`
2. Use image files (JPG/PNG) instead of PDFs temporarily
3. Configure Azure Document Intelligence for PDF support

**Check logs for:**
- "Starting workflow orchestration" - confirms submission was called
- "PO extraction completed" - confirms extraction is working
- "Scoring step completed" - confirms confidence score calculated
