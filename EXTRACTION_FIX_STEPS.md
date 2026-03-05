# Steps to Fix Data Extraction Issue

## Problem
PO number, PO amount, and overall confidence are showing as empty/null:
```json
{
  "poNumber": "",
  "poAmount": 0,
  "overallConfidence": null
}
```

## Root Cause
The workflow orchestrator is NOT being triggered. The data is empty because:
1. You're using an old JWT token with invalid role (role: "0")
2. The `/submit` endpoint requires a valid token with role "Agency" (role: "1")
3. Without calling `/submit`, the workflow never starts, so no extraction happens

## Solution Steps

### Step 1: Login Again to Get New Token

**Why:** Your current JWT token has `"role":"0"` which is invalid. After fixing the database, you need a fresh token with `"role":"1"` (Agency).

**API Call:**
```bash
POST http://localhost:5000/api/auth/login
Content-Type: application/json

{
  "email": "agency@bajaj.com",
  "password": "Password123!"
}
```

**Expected Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "...",
    "email": "agency@bajaj.com",
    "role": "Agency"  // ← Should be "Agency", not "0"
  }
}
```

**Verify Token:**
Decode the JWT token at https://jwt.io and check:
- `"role"` should be `"1"` or `"Agency"` (NOT "0")
- `"nameid"` should be your user ID

### Step 2: Upload Documents (You've Already Done This)

Upload your documents to create a package:
```bash
POST http://localhost:5000/api/documents/upload
Authorization: Bearer {NEW_TOKEN}
Content-Type: multipart/form-data

# Upload PO, Invoice, Cost Summary, etc.
```

This creates documents but does NOT trigger extraction yet.

### Step 3: Submit the Package (THIS IS THE MISSING STEP)

**This is the critical step that triggers the workflow!**

```bash
POST http://localhost:5000/api/Submissions/{packageId}/submit
Authorization: Bearer {NEW_TOKEN}
```

**What This Does:**
1. Validates you have required documents (PO, Invoice, Cost Summary)
2. Starts the workflow orchestrator in the background
3. Workflow extracts data from ALL documents
4. Calculates confidence scores
5. Generates recommendations
6. Moves package to `PendingApproval` state

**Expected Response:**
```json
{
  "message": "Package submitted for processing",
  "packageId": "...",
  "documentCount": 3,
  "status": "Processing started in background"
}
```

### Step 4: Wait for Processing (30-60 seconds)

The workflow runs in the background. Check the API logs for:

```
[Information] Starting workflow orchestration for package {PackageId}
[Information] Starting extraction step for package {PackageId}
[Information] Starting PO extraction for URL: ...
[Information] PO extraction completed. PO Number: XXX, Total Amount: YYY
[Information] Scoring step completed for package {PackageId}, Score: 85
```

### Step 5: Check Package Status

Poll the package status to see when it's complete:

```bash
GET http://localhost:5000/api/Submissions/{packageId}
Authorization: Bearer {NEW_TOKEN}
```

**State Progression:**
- `Uploaded` → Initial state (after document upload)
- `Extracting` → Workflow started, extracting documents
- `Validating` → Validating extracted data
- `Scoring` → Calculating confidence scores
- `Recommending` → Generating AI recommendation
- `PendingApproval` → ✅ Complete! Data is now available

**When Complete, You'll See:**
```json
{
  "id": "...",
  "state": "PendingApproval",
  "documents": [
    {
      "type": "PO",
      "extractedData": {
        "poNumber": "PO-12345",  // ← NOW POPULATED
        "totalAmount": 10500.00   // ← NOW POPULATED
      }
    }
  ],
  "confidenceScore": {
    "overallConfidence": 85.5  // ← NOW POPULATED
  }
}
```

### Step 6: View in Dashboard

Now when you call the submissions list endpoint:

```bash
GET http://localhost:5000/api/submissions
Authorization: Bearer {NEW_TOKEN}
```

You'll see:
```json
{
  "items": [
    {
      "id": "...",
      "poNumber": "PO-12345",      // ← NOW POPULATED
      "poAmount": 10500.00,         // ← NOW POPULATED
      "overallConfidence": 85.5     // ← NOW POPULATED
    }
  ]
}
```

## Quick Test Script

Here's a complete test flow:

```bash
# 1. Login
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"agency@bajaj.com","password":"Password123!"}'

# Save the token from response

# 2. Create submission (returns packageId)
curl -X POST http://localhost:5000/api/submissions \
  -H "Authorization: Bearer {TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{}'

# 3. Upload documents (use the packageId)
curl -X POST http://localhost:5000/api/documents/upload \
  -H "Authorization: Bearer {TOKEN}" \
  -F "file=@po.pdf" \
  -F "packageId={PACKAGE_ID}" \
  -F "documentType=PO"

# Repeat for Invoice and Cost Summary

# 4. Submit package (THIS TRIGGERS EXTRACTION)
curl -X POST http://localhost:5000/api/Submissions/{PACKAGE_ID}/submit \
  -H "Authorization: Bearer {TOKEN}"

# 5. Wait 30-60 seconds, then check status
curl -X GET http://localhost:5000/api/Submissions/{PACKAGE_ID} \
  -H "Authorization: Bearer {TOKEN}"
```

## Common Issues

### Issue: 403 Forbidden on /submit
**Cause:** Invalid JWT token (role is "0")
**Fix:** Login again to get new token with role "1"

### Issue: Package stuck in "Uploaded" state
**Cause:** `/submit` endpoint was never called
**Fix:** Call the submit endpoint

### Issue: Package stuck in "Extracting" state
**Cause:** Extraction is failing (check API logs)
**Fix:** 
- Check if using PDF files (may need Azure Document Intelligence configured)
- Try using JPG/PNG images instead (GPT-4 Vision works immediately)
- Check API logs for specific error messages

### Issue: Extraction returns empty data
**Cause:** Document quality is poor or format is unsupported
**Fix:**
- Ensure documents are clear and readable
- Use high-resolution images (at least 1024px width)
- Try different file formats (JPG works best)

## Summary

**The fix is simple:**
1. ✅ Login again to get new JWT token
2. ✅ Upload documents (you've done this)
3. ✅ **Call `/submit` endpoint** ← THIS IS THE MISSING STEP
4. ✅ Wait 30-60 seconds for processing
5. ✅ Check package status - data will be populated

The code is working correctly. You just need to trigger the workflow by calling the submit endpoint with a valid token!
