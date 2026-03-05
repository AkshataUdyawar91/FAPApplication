# Testing Submission Fix

## Quick Test Steps

### 1. Restart Backend
```bash
cd backend/src/BajajDocumentProcessing.API
dotnet run
```

### 2. Test Login
```bash
# Login as Agency user
curl -X POST http://localhost:5000/api/Auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "agency@example.com",
    "password": "Agency@123"
  }'

# Save the token from response
```

### 3. Test Package Submission
```bash
# Replace {TOKEN} and {PACKAGE_ID} with actual values
curl -X POST http://localhost:5000/api/Submissions/{PACKAGE_ID}/submit \
  -H "Authorization: Bearer {TOKEN}" \
  -H "Content-Type: application/json"

# Expected: 200 OK with message "Package submitted for processing"
# NOT 403 Forbidden anymore!
```

### 4. Monitor Package Status
```bash
# Poll every 2-3 seconds
curl -X GET http://localhost:5000/api/Submissions/{PACKAGE_ID} \
  -H "Authorization: Bearer {TOKEN}"

# Watch state change:
# Uploaded → Extracting → Validating → Scoring → Recommending → PendingApproval
```

### 5. Check Backend Logs
Look for these messages in console:
```
[Information] User {UserId} submitting package {PackageId}
[Information] Submitting package {PackageId} for processing with {Count} documents
[Information] Starting background workflow for package {PackageId}
[Information] Starting workflow orchestration for package {PackageId}
[Information] Starting extraction step for package {PackageId}
[Information] PO extraction completed. PO Number: {PONumber}, Total Amount: {TotalAmount}
[Information] Scoring step completed for package {PackageId}, Score: {Score}
```

## Expected Results

### Before Fix
- ❌ 403 Forbidden error
- ❌ No extraction happening
- ❌ No confidence score

### After Fix
- ✅ 200 OK response
- ✅ Workflow starts in background
- ✅ Documents extracted (check logs)
- ✅ Confidence score calculated
- ✅ PO number and amount visible in API response

## Troubleshooting

### Still Getting 403?
1. Check token is valid (not expired)
2. Verify user role is "Agency" (decode JWT at jwt.io)
3. Check backend logs for authentication errors
4. Ensure Authorization header format: `Bearer {token}`

### Extraction Not Working?
1. Check Azure OpenAI endpoint is reachable
2. Verify API key is valid
3. Check document types are set correctly (PO, Invoice, CostSummary)
4. Look for errors in backend logs during extraction step

### No Confidence Score?
1. Wait for workflow to complete (can take 30-60 seconds)
2. Check package state is "PendingApproval"
3. Verify all documents were extracted successfully
4. Check backend logs for scoring step errors

## Frontend Testing

### Update Agency Dashboard
After backend is working, test in Flutter app:

1. Login as agency user
2. Upload documents (PO, Invoice, Cost Summary)
3. Submit package
4. **Wait 30-60 seconds** for processing
5. Refresh or navigate back to see results
6. Verify:
   - PO Number shows
   - PO Amount shows
   - Overall Confidence shows
   - State is "PendingApproval"

### Add Polling (Recommended)
```dart
// In agency dashboard after submission
Timer.periodic(Duration(seconds: 2), (timer) async {
  final submission = await getSubmission(packageId);
  
  if (submission.state == 'PendingApproval' || 
      submission.state == 'Rejected') {
    timer.cancel();
    // Refresh UI
    setState(() {});
  }
});
```

## What Was Fixed

1. **Authentication Re-enabled**
   - `app.UseAuthentication()` uncommented
   - `app.UseAuthorization()` uncommented
   - JWT validation now works properly

2. **Better Error Handling**
   - Added logging to track submission flow
   - Improved error messages
   - Added ownership verification

3. **Workflow Monitoring**
   - Added logs at each workflow step
   - Can now track extraction progress
   - Easier to debug issues

## Next Steps

1. ✅ Test backend with curl/Postman
2. ✅ Verify logs show extraction working
3. ⚠️ Update frontend to poll for results
4. ⚠️ Add loading indicators in UI
5. ⚠️ Display extracted data once available
