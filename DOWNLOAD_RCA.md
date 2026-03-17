# Download Functionality - Root Cause Analysis (RCA)

## Problem Statement
Document download functionality is not working in the ASM Review Detail page.

## Complete Flow Analysis

### 1. Frontend Flow (ASM Review Detail Page)

**Entry Point**: User clicks on a document name in the Invoice Documents Table or Campaign Details Table

**Flow**:
```
User Click → onDocumentTap callback → _downloadDocument(documentId, filename)
```

**Code Path**:
```dart
// Line ~280: InvoiceDocumentsTable
onDocumentTap: (doc) => _downloadDocument(doc.documentId, doc.documentName)

// Line ~620: _downloadDocument method
Future<void> _downloadDocument(String? documentId, String? filename) async {
  // 1. Validate documentId
  // 2. Call API: GET /documents/{documentId}/download
  // 3. Extract base64Content from response
  // 4. Create data URI and trigger download
}
```

### 2. Backend Flow (DocumentsController)

**Endpoint**: `GET /api/documents/{id}/download`

**Code Path**:
```csharp
// DocumentsController.cs Line ~127
[HttpGet("{id}/download")]
public async Task<IActionResult> DownloadDocument(Guid id, CancellationToken cancellationToken)
{
  // 1. Query document from database
  // 2. Get file bytes via _fileStorageService.GetFileBytesAsync(document.BlobUrl)
  // 3. Convert to base64
  // 4. Return { base64Content, filename, contentType }
}
```

### 3. File Storage Service Flow

**Method**: `GetFileBytesAsync(string blobUrl)`

**Logic**:
```csharp
if (blobUrl.StartsWith("file:///")) {
  // Local file system (development)
  var filePath = blobUrl.Replace("file:///", "").Replace("/", "\\");
  return await File.ReadAllBytesAsync(filePath);
}
else if (_blobServiceClient != null) {
  // Azure Blob Storage (production)
  // Parse container and blob name from URL
  // Download from Azure
}
else {
  throw new InvalidOperationException("Cannot retrieve file bytes - no storage configured");
}
```

---

## Potential Root Causes & Solutions

### **ISSUE 1: Document ID is NULL or Empty**

**Symptom**: User sees "Document not available for download" toast

**Root Cause**: 
- The `documentId` field in `InvoiceDocumentRow` or `CampaignDetailRow` is null/empty
- The transformer extracts `doc['id']` but the API response doesn't include it

**Verification**:
```dart
// Check what's in the submission response
print('Document ID: ${doc.documentId}');
print('Document data: ${_submission!['documents']}');
```

**Solution**:
```dart
// In SubmissionDataTransformer.transformToInvoiceDocuments
final docId = doc['id']?.toString() ?? '';
print('Extracted docId: $docId from doc: $doc'); // Debug log
```

**Fix**: Ensure the submissions API includes document `id` field in the response.

---

### **ISSUE 2: API Endpoint Not Reachable (404)**

**Symptom**: DioException with 404 status code

**Root Causes**:
1. **Wrong base URL**: Frontend uses `http://localhost:5000/api` but backend runs on different port
2. **Backend not running**: API server is not started
3. **Route mismatch**: Controller route doesn't match the request

**Verification**:
```bash
# Check if backend is running
curl http://localhost:5000/api/documents/{some-guid}/download \
  -H "Authorization: Bearer {token}"

# Check actual backend port
netstat -ano | findstr :5000
netstat -ano | findstr :7001
```

**Solutions**:
- **Solution A**: Update frontend baseUrl to match backend port
  ```dart
  baseUrl: 'http://localhost:7001/api',  // or whatever port backend uses
  ```

- **Solution B**: Configure backend to listen on port 5000
  ```csharp
  // Program.cs
  builder.WebHost.UseUrls("http://localhost:5000");
  ```

---

### **ISSUE 3: Authentication Failure (401)**

**Symptom**: 401 Unauthorized response

**Root Cause**: JWT token is invalid, expired, or not being sent correctly

**Verification**:
```dart
print('Token: ${widget.token}');
print('Request headers: ${response.requestOptions.headers}');
```

**Solution**:
- Verify token is valid and not expired
- Check Authorization header format: `Bearer {token}`
- Ensure `[Authorize]` attribute on controller allows the user's role

---

### **ISSUE 4: Document Not Found in Database (404)**

**Symptom**: Backend returns 404 with message "Document not found"

**Root Cause**: 
- Document ID doesn't exist in the database
- Document was soft-deleted (`IsDeleted = true`)

**Verification**:
```sql
SELECT Id, FileName, BlobUrl, IsDeleted 
FROM Documents 
WHERE Id = '{document-id}';
```

**Solution**:
- Check if document exists
- Verify the ID being passed from frontend matches database
- Check if `AsNoTracking()` query includes `IsDeleted` filter

---

### **ISSUE 5: BlobUrl is NULL or Empty (404)**

**Symptom**: Backend returns 404 with message "Document file not available"

**Root Cause**: Document record exists but `BlobUrl` field is null/empty

**Verification**:
```sql
SELECT Id, FileName, BlobUrl 
FROM Documents 
WHERE BlobUrl IS NULL OR BlobUrl = '';
```

**Solution**:
- Ensure file upload process correctly sets `BlobUrl`
- Check if document upload completed successfully
- Verify `DocumentService.UploadDocumentAsync` returns valid blob URL

---

### **ISSUE 6: File Not Found on Disk (Local Storage)**

**Symptom**: Backend throws `FileNotFoundException`

**Root Cause**: 
- BlobUrl points to `file:///C:/path/to/file` but file doesn't exist
- File was deleted or moved
- Path format is incorrect (Windows vs Unix paths)

**Verification**:
```csharp
// Add logging in GetFileBytesAsync
_logger.LogInformation("Attempting to read file: {FilePath}", filePath);
if (!File.Exists(filePath)) {
    _logger.LogError("File not found at: {FilePath}", filePath);
}
```

**Solutions**:
- **Solution A**: Check if LocalStorage folder exists
  ```bash
  dir backend\src\BajajDocumentProcessing.API\LocalStorage\documents
  ```

- **Solution B**: Fix path conversion logic
  ```csharp
  // Current: blobUrl.Replace("file:///", "").Replace("/", "\\")
  // Better:
  var uri = new Uri(blobUrl);
  var filePath = uri.LocalPath;  // Handles path conversion automatically
  ```

---

### **ISSUE 7: Azure Blob Storage Not Configured**

**Symptom**: Exception "Cannot retrieve file bytes - no storage configured"

**Root Cause**: 
- `_blobServiceClient` is null
- BlobUrl doesn't start with `file:///` (not local)
- Azure connection string not configured

**Verification**:
```csharp
// Check if BlobServiceClient is initialized
_logger.LogInformation("BlobServiceClient is null: {IsNull}", _blobServiceClient == null);
_logger.LogInformation("BlobUrl format: {BlobUrl}", blobUrl);
```

**Solution**:
```json
// appsettings.json
{
  "AzureBlobStorage": {
    "ConnectionString": "UseDevelopmentStorage=true"  // For Azurite
  }
}
```

---

### **ISSUE 8: Base64 Content is Empty**

**Symptom**: Frontend shows "File content not available" toast

**Root Cause**:
- Backend returns empty `base64Content` field
- File bytes are empty (0 bytes)
- Base64 encoding failed

**Verification**:
```csharp
// Add logging in DownloadDocument
_logger.LogInformation("File bytes length: {Length}", fileBytes.Length);
_logger.LogInformation("Base64 length: {Length}", base64Content.Length);
```

**Solution**:
- Check if file has content
- Verify `GetFileBytesAsync` returns non-empty byte array
- Add error handling for empty files

---

### **ISSUE 9: Data URI Too Large (Browser Limit)**

**Symptom**: Download doesn't trigger, no error shown

**Root Cause**: 
- Data URIs have size limits (~2MB in some browsers)
- Large files cause silent failures

**Verification**:
```dart
print('Base64 length: ${base64Content.length}');
print('Estimated file size: ${(base64Content.length * 0.75 / 1024 / 1024).toStringAsFixed(2)} MB');
```

**Solution**:
- **Solution A**: Use Blob API instead of data URI
  ```dart
  import 'dart:html' as html;
  import 'dart:convert';
  
  final bytes = base64Decode(base64Content);
  final blob = html.Blob([bytes], contentType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', name)
    ..click();
  
  html.Url.revokeObjectUrl(url);  // Clean up
  ```

- **Solution B**: Stream large files instead of base64
  ```csharp
  // Return file stream directly
  return File(fileBytes, contentType, fileName);
  ```

---

### **ISSUE 10: CORS Policy Blocking Request**

**Symptom**: CORS error in browser console

**Root Cause**: Backend doesn't allow requests from frontend origin

**Verification**:
```
Access to XMLHttpRequest at 'http://localhost:5000/api/documents/...' 
from origin 'http://localhost:3000' has been blocked by CORS policy
```

**Solution**:
```csharp
// Program.cs
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

### **ISSUE 11: Content-Type Mismatch**

**Symptom**: File downloads but can't be opened

**Root Cause**: Wrong `contentType` returned from backend

**Verification**:
```dart
print('Content-Type: $contentType');
print('Filename: $name');
```

**Solution**:
- Ensure `Document.ContentType` is set correctly during upload
- Fallback to `application/octet-stream` is correct
- Verify MIME type matches file extension

---

## Recommended Debugging Steps

### Step 1: Add Comprehensive Logging

**Frontend**:
```dart
Future<void> _downloadDocument(String? documentId, String? filename) async {
  print('=== DOWNLOAD DEBUG START ===');
  print('Document ID: $documentId');
  print('Filename: $filename');
  
  if (documentId == null || documentId.isEmpty) {
    print('ERROR: Document ID is null or empty');
    // ... show error
    return;
  }

  try {
    print('Making API request to: /documents/$documentId/download');
    final response = await _dio.get(
      '/documents/$documentId/download',
      options: Options(
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ),
    );

    print('Response status: ${response.statusCode}');
    print('Response data keys: ${response.data?.keys}');
    
    final base64Content = response.data['base64Content']?.toString() ?? '';
    print('Base64 content length: ${base64Content.length}');
    print('Estimated file size: ${(base64Content.length * 0.75 / 1024).toStringAsFixed(2)} KB');
    
    // ... rest of code
  } catch (e, stackTrace) {
    print('ERROR: $e');
    print('Stack trace: $stackTrace');
    // ... show error
  }
  
  print('=== DOWNLOAD DEBUG END ===');
}
```

**Backend**:
```csharp
[HttpGet("{id}/download")]
public async Task<IActionResult> DownloadDocument(Guid id, CancellationToken cancellationToken)
{
    _logger.LogInformation("=== DOWNLOAD REQUEST START ===");
    _logger.LogInformation("Document ID: {DocumentId}", id);
    
    try
    {
        var document = await _context.Documents
            .AsNoTracking()
            .FirstOrDefaultAsync(d => d.Id == id, cancellationToken);

        _logger.LogInformation("Document found: {Found}", document != null);
        
        if (document == null)
        {
            _logger.LogWarning("Document not found: {DocumentId}", id);
            return NotFound(new { message = "Document not found" });
        }

        _logger.LogInformation("Document details - FileName: {FileName}, BlobUrl: {BlobUrl}", 
            document.FileName, document.BlobUrl);

        if (string.IsNullOrEmpty(document.BlobUrl))
        {
            _logger.LogWarning("BlobUrl is empty for document: {DocumentId}", id);
            return NotFound(new { message = "Document file not available" });
        }

        _logger.LogInformation("Calling GetFileBytesAsync for: {BlobUrl}", document.BlobUrl);
        var fileBytes = await _fileStorageService.GetFileBytesAsync(document.BlobUrl);
        
        _logger.LogInformation("File bytes retrieved: {Size} bytes", fileBytes.Length);
        
        var base64Content = Convert.ToBase64String(fileBytes);
        _logger.LogInformation("Base64 encoded: {Length} characters", base64Content.Length);

        var contentType = !string.IsNullOrEmpty(document.ContentType)
            ? document.ContentType
            : "application/octet-stream";

        _logger.LogInformation("Returning download response - ContentType: {ContentType}, Filename: {Filename}", 
            contentType, document.FileName);
        _logger.LogInformation("=== DOWNLOAD REQUEST END ===");

        return Ok(new
        {
            base64Content,
            filename = document.FileName,
            contentType,
        });
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Error downloading document {DocumentId}", id);
        _logger.LogInformation("=== DOWNLOAD REQUEST END (ERROR) ===");
        return StatusCode(500, new { message = "An error occurred while preparing the download" });
    }
}
```

### Step 2: Test API Directly

```bash
# Test with curl
curl -X GET "http://localhost:5000/api/documents/{document-id}/download" \
  -H "Authorization: Bearer {your-token}" \
  -v

# Expected response:
# {
#   "base64Content": "JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PC...",
#   "filename": "invoice.pdf",
#   "contentType": "application/pdf"
# }
```

### Step 3: Verify Database State

```sql
-- Check if documents exist
SELECT TOP 10 
    Id, 
    FileName, 
    BlobUrl, 
    ContentType,
    FileSizeBytes,
    IsDeleted,
    CreatedAt
FROM Documents
ORDER BY CreatedAt DESC;

-- Check specific document
SELECT * FROM Documents WHERE Id = '{document-id}';

-- Check for documents with missing BlobUrl
SELECT COUNT(*) FROM Documents WHERE BlobUrl IS NULL OR BlobUrl = '';
```

### Step 4: Verify File System

```bash
# Check if LocalStorage folder exists
dir backend\src\BajajDocumentProcessing.API\LocalStorage\documents

# Check file permissions
icacls backend\src\BajajDocumentProcessing.API\LocalStorage\documents
```

---

## Quick Fix Checklist

- [ ] Backend API is running
- [ ] Frontend baseUrl matches backend port
- [ ] Document ID is not null in frontend
- [ ] Document exists in database
- [ ] Document.BlobUrl is not null/empty
- [ ] File exists at BlobUrl path (for local storage)
- [ ] JWT token is valid and being sent
- [ ] CORS is configured correctly
- [ ] File size is reasonable (<2MB for data URI)
- [ ] Browser console shows no errors
- [ ] Backend logs show no exceptions

---

## Most Likely Root Causes (Ranked)

1. **Backend API not running or wrong port** (90% probability)
2. **Document ID is null/empty** (80% probability)
3. **File not found on disk** (70% probability)
4. **BlobUrl is null in database** (60% probability)
5. **Authentication failure** (40% probability)
6. **CORS issue** (30% probability)
7. **File too large for data URI** (20% probability)
8. **Azure Blob Storage misconfiguration** (10% probability)

---

## Next Steps

1. Add logging to both frontend and backend
2. Run the application and attempt a download
3. Check browser console for errors
4. Check backend logs for exceptions
5. Verify database state
6. Test API endpoint directly with curl
7. Apply fixes based on identified root cause
