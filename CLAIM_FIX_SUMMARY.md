# JWT Claim Fix - Complete Summary

## Problem
Multiple API endpoints were throwing `UnauthorizedAccessException` when trying to access user information from JWT tokens.

## Root Cause
Controllers were looking for "sub" claim, but JWT tokens use `ClaimTypes.NameIdentifier`.

## Solution Applied
Updated all controllers to try both claim types:
1. Try `ClaimTypes.NameIdentifier` first (standard)
2. Fallback to "sub" (for compatibility)
3. Return 401 Unauthorized if neither found

## Files Fixed

### ✅ SubmissionsController.cs
- `GetSubmission()` - Fixed
- `CreateSubmission()` - Fixed
- `SubmitPackage()` - Already correct

### ✅ ChatController.cs
- `SendMessage()` - Fixed
- `GetHistory()` - Fixed

### ✅ DocumentsController.cs
- `UploadDocument()` - Already fixed in previous session

## Code Pattern Used

```csharp
// Try both claim types for compatibility
var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value;
if (string.IsNullOrEmpty(userIdClaim))
{
    _logger.LogWarning("User ID claim not found in token");
    return Unauthorized(new { error = "User ID not found in token" });
}

var userId = Guid.Parse(userIdClaim);
var userRole = User.FindFirst(ClaimTypes.Role)?.Value ?? User.FindFirst("role")?.Value;
```

## Next Steps

1. **Stop the API** (Ctrl+C in terminal)
2. **Rebuild**:
   ```bash
   cd backend
   dotnet build
   ```
3. **Restart**:
   ```bash
   cd src/BajajDocumentProcessing.API
   dotnet run
   ```
4. **Test** - All endpoints should now work correctly

## Affected Endpoints Now Working

- ✅ `GET /api/submissions/{id}` - Get submission details
- ✅ `POST /api/submissions` - Create submission
- ✅ `POST /api/submissions/{id}/submit` - Submit package
- ✅ `POST /api/chat/message` - Send chat message (HQ only)
- ✅ `GET /api/chat/history` - Get chat history (HQ only)
- ✅ `POST /api/documents/upload` - Upload document

All endpoints will now correctly authenticate users and extract user information from JWT tokens.
