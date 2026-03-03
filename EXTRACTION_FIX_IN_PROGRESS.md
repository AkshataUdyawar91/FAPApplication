# Document Extraction Fix - In Progress

## Problem Identified

Invoice numbers and amounts are showing as NULL because:

1. **Azure Blob Storage not configured** - Connection string is empty in appsettings.json
2. **Local file storage** - Files are saved locally but DocumentAgent can't access them
3. **Azure OpenAI Vision API** - Requires either public URLs or base64-encoded images

## Root Cause

When Azure Blob Storage is not configured:
- FileStorageService returns simulated URLs like `https://localhost/storage/documents/file.pdf`
- DocumentAgent tries to send these URLs to Azure OpenAI Vision API
- Azure OpenAI can't access these fake URLs
- Extraction fails silently
- ExtractedDataJson remains NULL in database

## Solution Implemented

I've updated the code to:

1. **Store files locally** when Azure Blob Storage is not configured
   - Files saved to `LocalStorage/documents/` folder
   - Returns `file:///` URLs instead of fake https URLs

2. **Convert local files to base64** for Azure OpenAI
   - Added `GetFileBytesAsync()` method to IFileStorageService
   - Added `PrepareImageDataAsync()` method to DocumentAgent
   - Converts local files to base64 data URIs before sending to Azure OpenAI

3. **Updated DocumentAgent** to inject IFileStorageService
   - Can now read local files
   - Converts to base64 for Vision API

## Files Modified

1. `backend/src/BajajDocumentProcessing.Infrastructure/Services/FileStorageService.cs`
   - Updated `SimulateLocalStorageAsync()` to actually save files locally
   - Added `GetFileBytesAsync()` method

2. `backend/src/BajajDocumentProcessing.Application/Common/Interfaces/IFileStorageService.cs`
   - Added `GetFileBytesAsync()` method signature

3. `backend/src/BajajDocumentProcessing.Infrastructure/Services/DocumentAgent.cs`
   - Injected `IFileStorageService` in constructor
   - Added `PrepareImageDataAsync()` method
   - Updated `ClassifyAsync()` to use base64 for local files

## Next Steps

### To Apply the Fix:

1. **Stop the running backend**:
   ```powershell
   # Find the process
   Get-Process | Where-Object {$_.ProcessName -like "*BajajDocument*"}
   
   # Stop it (replace PID with actual process ID)
   Stop-Process -Id 33540 -Force
   ```

2. **Rebuild the solution**:
   ```powershell
   dotnet build backend/BajajDocumentProcessing.sln
   ```

3. **Restart the backend**:
   ```powershell
   cd backend
   dotnet run --project src/BajajDocumentProcessing.API
   ```

4. **Test document upload**:
   - Upload documents via Swagger
   - Wait 10-15 seconds for extraction
   - Check `GET /api/submissions` - should show invoice data

### Alternative: Use Azure Blob Storage

If you want to use Azure Blob Storage instead:

1. Create Azure Storage Account
2. Get connection string
3. Update `appsettings.json`:
   ```json
   "AzureBlobStorage": {
     "ConnectionString": "DefaultEndpointsProtocol=https;AccountName=...",
     "ContainerName": "documents"
   }
   ```
4. Restart backend

## Current Status

- ✅ Code changes completed
- ⏳ Build failed (backend still running)
- ⏳ Need to stop backend and rebuild
- ⏳ Need to test extraction

## Why Build Failed

The build failed with error:
```
The file is locked by: "BajajDocumentProcessing.API (33540)"
```

This means the backend is still running (process ID 33540) and holding locks on the DLL files. We need to stop it before rebuilding.

## Testing After Fix

1. Stop and restart backend
2. Login as agency user
3. Upload PO, Invoice, Cost Summary
4. Wait 15 seconds
5. Call `GET /api/submissions`
6. Should see:
   ```json
   {
     "invoiceNumber": "INV-2024-001",
     "invoiceAmount": 50000.00
   }
   ```

## Technical Details

### How Base64 Conversion Works

```csharp
// For local files (file:/// URLs)
var fileBytes = await _fileStorageService.GetFileBytesAsync(blobUrl);
var base64 = Convert.ToBase64String(fileBytes);
var dataUri = $"data:image/jpeg;base64,{base64}";

// Send to Azure OpenAI Vision API
// API can now "see" the image content
```

### How Local Storage Works

```csharp
// Save file locally
var localPath = Path.Combine(Directory.GetCurrentDirectory(), "LocalStorage", "documents");
Directory.CreateDirectory(localPath);
var filePath = Path.Combine(localPath, fileName);
await file.CopyToAsync(new FileStream(filePath, FileMode.Create));

// Return file:/// URL
return $"file:///{filePath.Replace("\\", "/")}";
```

---

## Summary

The fix is ready but needs the backend to be stopped and restarted to apply the changes. Once restarted, document extraction will work with local file storage and base64 encoding for Azure OpenAI Vision API.

**Action Required**: Stop backend process 33540, rebuild, and restart.
