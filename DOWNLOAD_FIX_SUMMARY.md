# Download Functionality - Fix Summary

## Changes Made

### 1. Backend Changes (DocumentsController.cs)

**Added comprehensive logging** to track the entire download flow:
- Document ID received
- Document lookup result
- BlobUrl and file metadata
- File bytes retrieval
- Base64 encoding
- Response construction

**Benefits**:
- Easy to identify where the flow breaks
- Can see exact file sizes and paths
- Tracks success/failure at each step

### 2. Frontend Changes (asm_review_detail_page.dart)

**Improved download implementation**:
- Added comprehensive debug logging
- Changed from data URI to Blob API (handles larger files better)
- Added proper error handling with stack traces
- Added file size estimation logging

**Key improvements**:
```dart
// OLD: Data URI approach (limited to ~2MB)
final dataUri = 'data:$contentType;base64,$base64Content';
anchor.href = dataUri;

// NEW: Blob API approach (no size limit)
final bytes = base64.decode(base64Content);
final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: contentType));
final url = web.URL.createObjectURL(blob);
anchor.href = url;
// Clean up after download
web.URL.revokeObjectURL(url);
```

### 3. Documentation

Created comprehensive RCA document (`DOWNLOAD_RCA.md`) covering:
- Complete flow analysis
- 11 potential root causes with solutions
- Debugging steps
- Quick fix checklist
- Ranked probability of each issue

---

## Testing Instructions

### Step 1: Start Backend API

```bash
cd backend/src/BajajDocumentProcessing.API
dotnet run
```

**Expected output**:
```
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: http://localhost:5000
```

**Note the port number** - if it's different from 5000, update the frontend baseUrl.

### Step 2: Start Frontend

```bash
cd frontend
flutter run -d chrome
```

### Step 3: Attempt Download

1. Navigate to ASM Review Detail page
2. Click on any document name in the tables
3. **Check browser console** (F12) for debug logs

**Expected console output**:
```
=== DOWNLOAD DEBUG START ===
Document ID: abc123...
Filename: invoice.pdf
Making API request to: /documents/abc123.../download
Base URL: http://localhost:5000/api
Token: eyJhbGciOiJIUzI1NiIs...
Response status: 200
Response data type: _Map<String, dynamic>
Response data keys: (base64Content, filename, contentType)
Base64 content length: 45678
Estimated file size: 34.26 KB
Content type: application/pdf
Filename: invoice.pdf
Creating blob and triggering download...
Decoded bytes length: 34260
Download triggered successfully
=== DOWNLOAD DEBUG END ===
```

### Step 4: Check Backend Logs

**Expected backend logs**:
```
info: BajajDocumentProcessing.API.Controllers.DocumentsController[0]
      === DOWNLOAD REQUEST START ===
info: BajajDocumentProcessing.API.Controllers.DocumentsController[0]
      Document ID: abc123-def456-...
info: BajajDocumentProcessing.API.Controllers.DocumentsController[0]
      Document found: True
info: BajajDocumentProcessing.API.Controllers.DocumentsController[0]
      Document details - FileName: invoice.pdf, BlobUrl: file:///C:/path/to/file, ContentType: application/pdf, Size: 34260
info: BajajDocumentProcessing.API.Controllers.DocumentsController[0]
      Calling GetFileBytesAsync for: file:///C:/path/to/file
info: BajajDocumentProcessing.Infrastructure.Services.FileStorageService[0]
      Reading local file: C:\path\to\file
info: BajajDocumentProcessing.API.Controllers.DocumentsController[0]
      File bytes retrieved: 34260 bytes
info: BajajDocumentProcessing.API.Controllers.DocumentsController[0]
      Base64 encoded: 45680 characters
info: BajajDocumentProcessing.API.Controllers.DocumentsController[0]
      Returning download response - ContentType: application/pdf, Filename: invoice.pdf
info: BajajDocumentProcessing.API.Controllers.DocumentsController[0]
      === DOWNLOAD REQUEST END (SUCCESS) ===
```

---

## Troubleshooting Guide

### Issue: "Document not available for download"

**Cause**: Document ID is null or empty

**Check**:
```dart
// In browser console, look for:
Document ID: null  // or empty string
```

**Fix**: Verify the submission API includes document `id` field:
```sql
SELECT Id, FileName FROM Documents WHERE PackageId = '{submission-id}';
```

---

### Issue: 404 Error in Console

**Cause**: Backend not running or wrong port

**Check**:
```
Failed to download: DioException [bad response]: This exception was thrown because the response has a status code of 404
```

**Fix**:
1. Verify backend is running: `netstat -ano | findstr :5000`
2. Update frontend baseUrl if needed
3. Test API directly: `curl http://localhost:5000/api/documents/{id}/download`

---

### Issue: "Document not found" from Backend

**Cause**: Document doesn't exist in database

**Check backend logs**:
```
Document found: False
```

**Fix**: Verify document exists:
```sql
SELECT * FROM Documents WHERE Id = '{document-id}';
```

---

### Issue: "Document file not available"

**Cause**: BlobUrl is null or empty

**Check backend logs**:
```
BlobUrl is empty for document: {document-id}
```

**Fix**: Check database:
```sql
SELECT Id, FileName, BlobUrl FROM Documents WHERE BlobUrl IS NULL OR BlobUrl = '';
```

---

### Issue: FileNotFoundException

**Cause**: File doesn't exist at the path specified in BlobUrl

**Check backend logs**:
```
Error getting file bytes from: file:///C:/path/to/file
System.IO.FileNotFoundException: Local file not found: C:\path\to\file
```

**Fix**:
1. Check if file exists: `dir C:\path\to\file`
2. Check LocalStorage folder: `dir backend\src\BajajDocumentProcessing.API\LocalStorage\documents`
3. Verify file was uploaded successfully

---

### Issue: 401 Unauthorized

**Cause**: Invalid or expired JWT token

**Check console**:
```
Failed to download: DioException [bad response]: This exception was thrown because the response has a status code of 401
```

**Fix**:
1. Verify token is valid
2. Check token expiration
3. Re-login to get fresh token

---

### Issue: CORS Error

**Cause**: Backend doesn't allow frontend origin

**Check console**:
```
Access to XMLHttpRequest at 'http://localhost:5000/api/documents/...' 
from origin 'http://localhost:3000' has been blocked by CORS policy
```

**Fix**: Add CORS policy in `Program.cs`:
```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend", policy =>
    {
        policy.WithOrigins("http://localhost:3000")
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

app.UseCors("AllowFrontend");
```

---

### Issue: Download Doesn't Trigger (No Error)

**Cause**: File too large or browser blocking

**Check console**:
```
Base64 content length: 5000000  // Very large
Estimated file size: 3750.00 KB  // >2MB
```

**Fix**: The Blob API approach should handle this, but if issues persist:
1. Check browser download settings
2. Check if popup blocker is active
3. Try in incognito mode
4. Check browser console for silent errors

---

## Quick Diagnostic Commands

### Check Backend Status
```bash
# Windows
netstat -ano | findstr :5000
netstat -ano | findstr :7001

# Check if API responds
curl http://localhost:5000/api/documents/{document-id}/download -H "Authorization: Bearer {token}" -v
```

### Check Database
```sql
-- List recent documents
SELECT TOP 10 Id, FileName, BlobUrl, ContentType, FileSizeBytes, CreatedAt
FROM Documents
ORDER BY CreatedAt DESC;

-- Check specific document
SELECT * FROM Documents WHERE Id = '{document-id}';

-- Find documents with missing files
SELECT COUNT(*) FROM Documents WHERE BlobUrl IS NULL OR BlobUrl = '';
```

### Check File System
```bash
# List uploaded files
dir backend\src\BajajDocumentProcessing.API\LocalStorage\documents

# Check specific file
dir "C:\path\to\file"
```

---

## Success Indicators

✅ **Frontend Console**:
- No errors
- Shows "Download triggered successfully"
- Shows correct file size

✅ **Backend Logs**:
- Shows "=== DOWNLOAD REQUEST END (SUCCESS) ==="
- No exceptions
- Shows correct file size

✅ **Browser**:
- File downloads automatically
- File opens correctly
- Correct filename and extension

---

## Next Steps if Still Not Working

1. **Capture full logs**: Run both frontend and backend with logging enabled
2. **Test API directly**: Use curl or Postman to isolate frontend vs backend issues
3. **Check database state**: Verify document exists with valid BlobUrl
4. **Verify file exists**: Check if file is actually on disk
5. **Test with small file**: Try downloading a tiny test file first
6. **Check browser**: Try different browser or incognito mode
7. **Review RCA document**: See `DOWNLOAD_RCA.md` for comprehensive analysis

---

## Files Modified

1. `backend/src/BajajDocumentProcessing.API/Controllers/DocumentsController.cs`
   - Added comprehensive logging
   - Improved error messages

2. `frontend/lib/features/approval/presentation/pages/asm_review_detail_page.dart`
   - Added debug logging
   - Changed to Blob API
   - Added proper error handling
   - Added `dart:js_interop` import

3. `DOWNLOAD_RCA.md` (new)
   - Comprehensive root cause analysis
   - 11 potential issues with solutions

4. `DOWNLOAD_FIX_SUMMARY.md` (this file)
   - Summary of changes
   - Testing instructions
   - Troubleshooting guide
