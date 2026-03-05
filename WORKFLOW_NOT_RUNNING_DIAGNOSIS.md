# Workflow Not Running - Diagnosis and Fix

## Current Situation

You successfully called `/submit` endpoint and got:
```json
{
  "message": "Package submitted for processing",
  "packageId": "7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8",
  "documentCount": 4,
  "status": "Processing started in background"
}
```

But the data is still empty:
```json
{
  "poNumber": "",
  "poAmount": 0,
  "overallConfidence": null
}
```

## Root Cause

The background task (`Task.Run`) in the `/submit` endpoint is likely not executing or failing silently.

### Why This Happens

1. **Fire-and-Forget Pattern**: The code uses `_ = Task.Run(...)` which starts a background task but doesn't wait for it
2. **Exception Swallowing**: If the workflow throws an exception, it's caught and logged, but the API returns success anyway
3. **No Visibility**: You can't see if the workflow actually started or failed

## Solution: Use the Synchronous Endpoint

There's already a `/process-now` endpoint in the code that runs the workflow synchronously, but it hasn't been compiled yet because the API is running.

### Step 1: Stop the API

**In the terminal where the API is running, press `Ctrl+C`**

You should see:
```
Application is shutting down...
```

### Step 2: Rebuild the API

```powershell
cd backend
dotnet build
```

This will compile the new `/process-now` endpoint.

### Step 3: Restart the API

```powershell
cd backend
dotnet run --project src/BajajDocumentProcessing.API
```

Wait for:
```
Now listening on: http://localhost:5000
Now listening on: https://localhost:5001
```

### Step 4: Call the Synchronous Endpoint

**Using curl:**
```bash
curl -X 'POST' \
  'http://localhost:5000/api/Submissions/7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8/process-now' \
  -H 'accept: */*' \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1laWQiOiIwNWIwNGRhZi04MWE3LTRjMDYtOTJkNS03NGUwZDFlMzVhNGQiLCJlbWFpbCI6ImFnZW5jeUBiYWphai5jb20iLCJyb2xlIjoiQWdlbmN5IiwianRpIjoiOGQ4OWViOWItOWY1Ni00ZDNiLTg0MTktZTc2NzcxMmQwZDVmIiwibmJmIjoxNzcyNjk0OTQ1LCJleHAiOjE3NzI2OTY3NDUsImlhdCI6MTc3MjY5NDk0NSwiaXNzIjoiQmFqYWpEb2N1bWVudFByb2Nlc3NpbmciLCJhdWQiOiJCYWphakRvY3VtZW50UHJvY2Vzc2luZyJ9.9f8ZuDTDInLyuqmhRMOL-9qcy3Kdhuzb78kSQfcIHQs' \
  -d ''
```

**Using PowerShell:**
```powershell
$token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1laWQiOiIwNWIwNGRhZi04MWE3LTRjMDYtOTJkNS03NGUwZDFlMzVhNGQiLCJlbWFpbCI6ImFnZW5jeUBiYWphai5jb20iLCJyb2xlIjoiQWdlbmN5IiwianRpIjoiOGQ4OWViOWItOWY1Ni00ZDNiLTg0MTktZTc2NzcxMmQwZDVmIiwibmJmIjoxNzcyNjk0OTQ1LCJleHAiOjE3NzI2OTY3NDUsImlhdCI6MTc3MjY5NDk0NSwiaXNzIjoiQmFqYWpEb2N1bWVudFByb2Nlc3NpbmciLCJhdWQiOiJCYWphakRvY3VtZW50UHJvY2Vzc2luZyJ9.9f8ZuDTDInLyuqmhRMOL-9qcy3Kdhuzb78kSQfcIHQs"

$headers = @{
    "Authorization" = "Bearer $token"
    "Accept" = "application/json"
}

Invoke-RestMethod -Uri "http://localhost:5000/api/Submissions/7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8/process-now" -Method Post -Headers $headers
```

### Step 5: Watch the API Console

**This is the key!** Watch the API console output. You'll see detailed logs:

```
[Information] Manual workflow trigger requested for package 7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8
[Information] Starting synchronous workflow for package 7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8
[Information] Starting workflow orchestration for package 7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8
[Information] Starting extraction step for package 7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8
```

**If you see errors here, that's the problem!**

Common errors:
- Azure OpenAI API key not configured
- Azure Document Intelligence not configured
- Network connectivity issues
- Document files not accessible

### Step 6: Check the Response

**Success Response:**
```json
{
  "success": true,
  "packageId": "7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8",
  "currentState": "PendingApproval",
  "message": "Workflow completed successfully"
}
```

**Failure Response:**
```json
{
  "success": false,
  "packageId": "7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8",
  "currentState": "Uploaded",
  "message": "Workflow failed - check logs"
}
```

### Step 7: Verify Data is Populated

```powershell
$token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1laWQiOiIwNWIwNGRhZi04MWE3LTRjMDYtOTJkNS03NGUwZDFlMzVhNGQiLCJlbWFpbCI6ImFnZW5jeUBiYWphai5jb20iLCJyb2xlIjoiQWdlbmN5IiwianRpIjoiOGQ4OWViOWItOWY1Ni00ZDNiLTg0MTktZTc2NzcxMmQwZDVmIiwibmJmIjoxNzcyNjk0OTQ1LCJleHAiOjE3NzI2OTY3NDUsImlhdCI6MTc3MjY5NDk0NSwiaXNzIjoiQmFqYWpEb2N1bWVudFByb2Nlc3NpbmciLCJhdWQiOiJCYWphakRvY3VtZW50UHJvY2Vzc2luZyJ9.9f8ZuDTDInLyuqmhRMOL-9qcy3Kdhuzb78kSQfcIHQs"

Invoke-RestMethod -Uri "http://localhost:5000/api/Submissions/7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8" -Method Get -Headers @{"Authorization"="Bearer $token"} | ConvertTo-Json -Depth 10
```

## Alternative: Check API Logs Without Stopping

If you don't want to stop the API, you can check what's happening by looking at the logs.

### Check if Workflow Started

Look for these log messages in the API console:

**Expected (if working):**
```
[Information] Starting background workflow for package 7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8
[Information] Starting workflow orchestration for package 7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8
```

**If you DON'T see these messages**, the background task never started.

**If you see error messages**, that's the root cause.

### Common Issues

#### Issue 1: Azure Services Not Configured

**Error:**
```
[Error] Azure OpenAI endpoint not configured
```

**Solution:**
Check `appsettings.Development.json`:
```json
{
  "AzureOpenAI": {
    "Endpoint": "https://your-resource.openai.azure.com/",
    "ApiKey": "your-api-key",
    "DeploymentName": "gpt-4"
  }
}
```

#### Issue 2: Document Files Not Found

**Error:**
```
[Error] Blob not found: https://...
```

**Solution:**
- Check if files were uploaded correctly
- Verify blob storage connection string
- Check file permissions

#### Issue 3: Workflow Already Ran

**Warning:**
```
[Warning] Package 7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8 is in state PendingApproval, skipping processing
```

**Solution:**
The workflow already completed! Check the package details - data should be there.

## Quick Test Script

Run this PowerShell script to test everything:

```powershell
# test-workflow.ps1
$packageId = "7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8"
$token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1laWQiOiIwNWIwNGRhZi04MWE3LTRjMDYtOTJkNS03NGUwZDFlMzVhNGQiLCJlbWFpbCI6ImFnZW5jeUBiYWphai5jb20iLCJyb2xlIjoiQWdlbmN5IiwianRpIjoiOGQ4OWViOWItOWY1Ni00ZDNiLTg0MTktZTc2NzcxMmQwZDVmIiwibmJmIjoxNzcyNjk0OTQ1LCJleHAiOjE3NzI2OTY3NDUsImlhdCI6MTc3MjY5NDk0NSwiaXNzIjoiQmFqYWpEb2N1bWVudFByb2Nlc3NpbmciLCJhdWQiOiJCYWphakRvY3VtZW50UHJvY2Vzc2luZyJ9.9f8ZuDTDInLyuqmhRMOL-9qcy3Kdhuzb78kSQfcIHQs"

Write-Host "Testing workflow execution..." -ForegroundColor Cyan

# Check current state
$response = Invoke-RestMethod -Uri "http://localhost:5000/api/Submissions/$packageId" -Method Get -Headers @{"Authorization"="Bearer $token"}

Write-Host "Current State: $($response.state)" -ForegroundColor Yellow

if ($response.state -eq "Uploaded") {
    Write-Host "Package is still in Uploaded state. Workflow has NOT run." -ForegroundColor Red
    Write-Host "Triggering workflow now..." -ForegroundColor Cyan
    
    try {
        $result = Invoke-RestMethod -Uri "http://localhost:5000/api/Submissions/$packageId/process-now" -Method Post -Headers @{"Authorization"="Bearer $token"}
        Write-Host "Workflow Result: $($result.message)" -ForegroundColor Green
        Write-Host "New State: $($result.currentState)" -ForegroundColor Yellow
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "Workflow has already run (State: $($response.state))" -ForegroundColor Green
}
```

## Summary

**The issue is that the background task isn't executing.** To fix:

1. Stop the API (Ctrl+C)
2. Rebuild: `dotnet build`
3. Restart: `dotnet run --project src/BajajDocumentProcessing.API`
4. Call `/process-now` endpoint (synchronous)
5. Watch API console for errors
6. Fix any configuration issues
7. Verify data is populated

The `/process-now` endpoint will show you exactly what's failing.
