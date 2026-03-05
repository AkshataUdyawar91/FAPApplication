# Fix Data Extraction - Step by Step

## Current Problem

You called `/submit` successfully, but data is still empty:
- `poNumber`: ""
- `poAmount`: 0
- `overallConfidence`: null

## Root Cause

The background task (`Task.Run`) in the `/submit` endpoint is not executing properly. This is a common issue with fire-and-forget background tasks in ASP.NET Core.

## Quick Fix (3 Steps)

### Step 1: Stop the API

In the terminal where the API is running:
```
Press Ctrl+C
```

Wait for:
```
Application is shutting down...
```

### Step 2: Rebuild and Restart

```powershell
cd backend
dotnet build
dotnet run --project src/BajajDocumentProcessing.API
```

Wait for:
```
Now listening on: http://localhost:5000
Now listening on: https://localhost:5001
```

### Step 3: Trigger Workflow Synchronously

Use the new `/process-now` endpoint that runs synchronously (so you can see errors):

**PowerShell:**
```powershell
$token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1laWQiOiIwNWIwNGRhZi04MWE3LTRjMDYtOTJkNS03NGUwZDFlMzVhNGQiLCJlbWFpbCI6ImFnZW5jeUBiYWphai5jb20iLCJyb2xlIjoiQWdlbmN5IiwianRpIjoiOGQ4OWViOWItOWY1Ni00ZDNiLTg0MTktZTc2NzcxMmQwZDVmIiwibmJmIjoxNzcyNjk0OTQ1LCJleHAiOjE3NzI2OTY3NDUsImlhdCI6MTc3MjY5NDk0NSwiaXNzIjoiQmFqYWpEb2N1bWVudFByb2Nlc3NpbmciLCJhdWQiOiJCYWphakRvY3VtZW50UHJvY2Vzc2luZyJ9.9f8ZuDTDInLyuqmhRMOL-9qcy3Kdhuzb78kSQfcIHQs"

Invoke-RestMethod -Uri "http://localhost:5000/api/Submissions/7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8/process-now" -Method Post -Headers @{"Authorization"="Bearer $token"}
```

**Curl:**
```bash
curl -X 'POST' \
  'http://localhost:5000/api/Submissions/7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8/process-now' \
  -H 'accept: */*' \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1laWQiOiIwNWIwNGRhZi04MWE3LTRjMDYtOTJkNS03NGUwZDFlMzVhNGQiLCJlbWFpbCI6ImFnZW5jeUBiYWphai5jb20iLCJyb2xlIjoiQWdlbmN5IiwianRpIjoiOGQ4OWViOWItOWY1Ni00ZDNiLTg0MTktZTc2NzcxMmQwZDVmIiwibmJmIjoxNzcyNjk0OTQ1LCJleHAiOjE3NzI2OTY3NDUsImlhdCI6MTc3MjY5NDk0NSwiaXNzIjoiQmFqYWpEb2N1bWVudFByb2Nlc3NpbmciLCJhdWQiOiJCYWphakRvY3VtZW50UHJvY2Vzc2luZyJ9.9f8ZuDTDInLyuqmhRMOL-9qcy3Kdhuzb78kSQfcIHQs'
```

## What to Watch For

### In the API Console

You'll see detailed logs showing exactly what's happening:

**Success:**
```
[Information] Manual workflow trigger requested for package 7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8
[Information] Starting synchronous workflow for package 7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8
[Information] Starting workflow orchestration for package 7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8
[Information] Starting extraction step for package 7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8
[Information] Starting PO extraction for URL: https://...
[Information] Received PO extraction response: {"poNumber":"PO-12345",...}
[Information] PO extraction completed. PO Number: PO-12345, Total Amount: 10500.00
[Information] Starting validation step for package 7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8
[Information] Starting scoring step for package 7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8
[Information] Scoring step completed for package 7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8, Score: 85.5
[Information] Workflow orchestration completed successfully for package 7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8
```

**Failure (with error details):**
```
[Error] Error during extraction step for package 7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8
System.Exception: Azure OpenAI request failed: 401 Unauthorized
```

### In the Response

**Success:**
```json
{
  "success": true,
  "packageId": "7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8",
  "currentState": "PendingApproval",
  "message": "Workflow completed successfully"
}
```

**Failure:**
```json
{
  "success": false,
  "packageId": "7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8",
  "currentState": "Uploaded",
  "message": "Workflow failed - check logs"
}
```

## Verify Data is Populated

After successful workflow execution:

```powershell
$token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1laWQiOiIwNWIwNGRhZi04MWE3LTRjMDYtOTJkNS03NGUwZDFlMzVhNGQiLCJlbWFpbCI6ImFnZW5jeUBiYWphai5jb20iLCJyb2xlIjoiQWdlbmN5IiwianRpIjoiOGQ4OWViOWItOWY1Ni00ZDNiLTg0MTktZTc2NzcxMmQwZDVmIiwibmJmIjoxNzcyNjk0OTQ1LCJleHAiOjE3NzI2OTY3NDUsImlhdCI6MTc3MjY5NDk0NSwiaXNzIjoiQmFqYWpEb2N1bWVudFByb2Nlc3NpbmciLCJhdWQiOiJCYWphakRvY3VtZW50UHJvY2Vzc2luZyJ9.9f8ZuDTDInLyuqmhRMOL-9qcy3Kdhuzb78kSQfcIHQs"

Invoke-RestMethod -Uri "http://localhost:5000/api/Submissions/7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8" -Method Get -Headers @{"Authorization"="Bearer $token"} | ConvertTo-Json -Depth 10
```

You should now see:
```json
{
  "id": "7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8",
  "state": "PendingApproval",
  "documents": [
    {
      "type": "PO",
      "extractedData": {
        "poNumber": "PO-12345",        // ← NOW POPULATED
        "totalAmount": 10500.00         // ← NOW POPULATED
      }
    }
  ],
  "confidenceScore": {
    "overallConfidence": 85.5          // ← NOW POPULATED
  }
}
```

## Common Errors and Solutions

### Error: "Azure OpenAI request failed: 401 Unauthorized"

**Cause:** Invalid API key or endpoint

**Solution:** Check `appsettings.Development.json`:
```json
{
  "AzureOpenAI": {
    "Endpoint": "https://your-resource.openai.azure.com/",
    "ApiKey": "your-valid-api-key",
    "DeploymentName": "gpt-4o"
  }
}
```

### Error: "Blob not found"

**Cause:** Document files not accessible

**Solution:** 
1. Check if files exist in `C:\BajajDocuments`
2. Verify file paths in database match actual files
3. Check file permissions

### Error: "Package is in state PendingApproval, skipping processing"

**Cause:** Workflow already completed!

**Solution:** This is actually success! Check the package details - data should be populated.

### Error: "Azure Document Intelligence endpoint not configured"

**Cause:** Missing Document Intelligence configuration

**Solution:** Add to `appsettings.Development.json`:
```json
{
  "AzureDocumentIntelligence": {
    "Endpoint": "https://your-resource.cognitiveservices.azure.com/",
    "ApiKey": "your-api-key"
  }
}
```

## Alternative: Use Test Script

I've created a test script for you. Run it:

```powershell
.\test-workflow.ps1
```

This will:
1. Check current package state
2. Show if workflow has run
3. Display extracted data
4. Show confidence scores

## Why This Happens

### Background Task Issue

The original `/submit` endpoint uses:
```csharp
_ = Task.Run(async () => {
    await _orchestrator.ProcessSubmissionAsync(packageId, CancellationToken.None);
});
```

This is "fire-and-forget" - the API returns immediately, but:
- If the task fails, you don't see the error
- If the task doesn't start, you don't know
- No way to debug what's happening

### Synchronous Endpoint Solution

The `/process-now` endpoint uses:
```csharp
var result = await _orchestrator.ProcessSubmissionAsync(packageId, cancellationToken);
```

This waits for completion, so:
- You see all errors immediately
- You can debug in real-time
- You know exactly what's happening

## Next Steps

1. **Stop API** (Ctrl+C)
2. **Rebuild** (`dotnet build`)
3. **Restart** (`dotnet run --project src/BajajDocumentProcessing.API`)
4. **Call `/process-now`** endpoint
5. **Watch console** for errors
6. **Fix any errors** (API keys, file paths, etc.)
7. **Verify data** is populated

Once it works, the regular `/submit` endpoint will also work (it uses the same workflow).

## Summary

The code is correct, but background tasks can fail silently. Use the synchronous `/process-now` endpoint to see what's actually happening, fix any errors, and then the regular workflow will work.

**Do this now:**
1. Stop API
2. Rebuild
3. Call `/process-now`
4. Check console logs
5. Report any errors you see
