# Complete Fix Summary - Data Extraction Issue

## Problem Statement
After uploading documents, the dashboard shows:
```json
{
  "poNumber": "",
  "poAmount": 0,
  "overallConfidence": null
}
```

## Root Cause Analysis

### Issue #1: Invalid JWT Token ✅ FIXED
**Problem:** Your JWT token has `"role":"0"` which is invalid
**Why:** Database had `Role = 0` for users (invalid enum value)
**Fix Applied:** 
```sql
UPDATE Users SET Role = 1 WHERE Email = 'agency@bajaj.com';  -- Agency
UPDATE Users SET Role = 2 WHERE Email = 'asm@bajaj.com';      -- ASM
UPDATE Users SET Role = 3 WHERE Email = 'hq@bajaj.com';       -- HQ
```
**Status:** ✅ Database fixed, but you need to login again to get new token

### Issue #2: Workflow Not Triggered ⚠️ ACTION REQUIRED
**Problem:** The workflow orchestrator is never started
**Why:** The `/submit` endpoint hasn't been called
**What Happens:**
- Documents are uploaded ✅
- Documents are stored in database ✅
- Package state is `Uploaded` ✅
- **BUT workflow never starts** ❌
- No extraction happens ❌
- No confidence scoring ❌
- Data remains empty ❌

**Fix Required:** Call the submit endpoint (see Step 3 below)

## Complete Solution

### Step 1: Login Again (Get New Token)

**Why:** Your current token has invalid role. You need a fresh token.

**Request:**
```http
POST http://localhost:5000/api/auth/login
Content-Type: application/json

{
  "email": "agency@bajaj.com",
  "password": "Password123!"
}
```

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "email": "agency@bajaj.com",
  "fullName": "Agency User",
  "role": 1,  // Agency role
  "expiresAt": "2026-03-05T07:00:00Z"
}
```

**Verify Token at jwt.io:**
```json
{
  "nameid": "05b04daf-81a7-4c06-92d5-74e0d1e35a4d",
  "email": "agency@bajaj.com",
  "role": "Agency",  // ← Should be "Agency", not "0"
  "jti": "...",
  "exp": 1772695200,
  "iss": "BajajDocumentProcessing",
  "aud": "BajajDocumentProcessing"
}
```

### Step 2: Upload Documents (Already Done)

You've already uploaded documents. The package exists with documents attached.

**Current State:**
- Package ID: `72463bb1-db3f-4762-9c87-395c3f8209c3` (or similar)
- State: `Uploaded`
- Documents: PO, Invoice, Cost Summary uploaded ✅

### Step 3: Submit Package (CRITICAL - THIS TRIGGERS EXTRACTION)

**This is the missing step!**

**Request:**
```http
POST http://localhost:5000/api/Submissions/72463bb1-db3f-4762-9c87-395c3f8209c3/submit
Authorization: Bearer {NEW_TOKEN_FROM_STEP_1}
```

**What This Does:**
1. Validates required documents exist (PO, Invoice, Cost Summary)
2. Starts WorkflowOrchestrator in background
3. Workflow processes package through these steps:
   - **Extracting:** Extracts data from all documents using GPT-4 Vision or Document Intelligence
   - **Validating:** Cross-validates data (amounts match, line items match, etc.)
   - **Scoring:** Calculates weighted confidence score
   - **Recommending:** Generates AI recommendation (APPROVE/REVIEW/REJECT)
   - **PendingApproval:** Final state, ready for ASM review

**Expected Response:**
```json
{
  "message": "Package submitted for processing",
  "packageId": "72463bb1-db3f-4762-9c87-395c3f8209c3",
  "documentCount": 3,
  "status": "Processing started in background"
}
```

**API Logs (What You Should See):**
```
[Information] User 05b04daf-81a7-4c06-92d5-74e0d1e35a4d submitting package 72463bb1-db3f-4762-9c87-395c3f8209c3
[Information] Submitting package 72463bb1-db3f-4762-9c87-395c3f8209c3 for processing with 3 documents
[Information] Starting background workflow for package 72463bb1-db3f-4762-9c87-395c3f8209c3
[Information] Starting workflow orchestration for package 72463bb1-db3f-4762-9c87-395c3f8209c3
[Information] Starting extraction step for package 72463bb1-db3f-4762-9c87-395c3f8209c3
[Information] Starting PO extraction for URL: https://...
[Information] Received PO extraction response: {"poNumber":"PO-12345","totalAmount":10500.00,...}
[Information] PO extraction completed. PO Number: PO-12345, Total Amount: 10500.00
[Information] Starting validation step for package 72463bb1-db3f-4762-9c87-395c3f8209c3
[Information] Starting scoring step for package 72463bb1-db3f-4762-9c87-395c3f8209c3
[Information] Scoring step completed for package 72463bb1-db3f-4762-9c87-395c3f8209c3, Score: 85.5
[Information] Starting recommendation step for package 72463bb1-db3f-4762-9c87-395c3f8209c3
[Information] Recommendation step completed for package 72463bb1-db3f-4762-9c87-395c3f8209c3, Type: Approve
[Information] Workflow orchestration completed successfully for package 72463bb1-db3f-4762-9c87-395c3f8209c3
```

### Step 4: Wait for Processing

**Processing Time:** 30-60 seconds (depending on document complexity)

**Monitor Progress:**
Poll the package status every 5-10 seconds:

```http
GET http://localhost:5000/api/Submissions/72463bb1-db3f-4762-9c87-395c3f8209c3
Authorization: Bearer {NEW_TOKEN}
```

**State Progression:**
```
Uploaded → Extracting → Validating → Scoring → Recommending → PendingApproval
```

### Step 5: Verify Data is Populated

**Once state is `PendingApproval`, check the data:**

```http
GET http://localhost:5000/api/Submissions/72463bb1-db3f-4762-9c87-395c3f8209c3
Authorization: Bearer {NEW_TOKEN}
```

**Response (Data Now Populated):**
```json
{
  "id": "72463bb1-db3f-4762-9c87-395c3f8209c3",
  "state": "PendingApproval",
  "createdAt": "2026-03-05T06:00:00Z",
  "updatedAt": "2026-03-05T06:01:30Z",
  "documents": [
    {
      "id": "...",
      "type": "PO",
      "filename": "po.pdf",
      "extractionConfidence": 0.92,
      "extractedData": {
        "poNumber": "PO-12345",        // ← NOW POPULATED
        "vendorName": "ABC Corp",
        "poDate": "2026-03-01",
        "totalAmount": 10500.00,        // ← NOW POPULATED
        "lineItems": [...]
      }
    },
    {
      "id": "...",
      "type": "Invoice",
      "extractedData": {
        "invoiceNumber": "INV-67890",
        "totalAmount": 10500.00
      }
    }
  ],
  "confidenceScore": {
    "overallConfidence": 85.5,        // ← NOW POPULATED
    "poConfidence": 92.0,
    "invoiceConfidence": 88.0,
    "costSummaryConfidence": 80.0
  },
  "recommendation": {
    "type": "Approve",
    "evidence": "PO verified in SAP. Invoice total matches Cost Summary. High confidence across all documents."
  }
}
```

### Step 6: View in Dashboard

**List all submissions:**
```http
GET http://localhost:5000/api/submissions
Authorization: Bearer {NEW_TOKEN}
```

**Response:**
```json
{
  "total": 1,
  "page": 1,
  "pageSize": 20,
  "items": [
    {
      "id": "72463bb1-db3f-4762-9c87-395c3f8209c3",
      "state": "PendingApproval",
      "createdAt": "2026-03-05T06:00:00Z",
      "poNumber": "PO-12345",           // ← NOW POPULATED
      "poAmount": 10500.00,             // ← NOW POPULATED
      "invoiceNumber": "INV-67890",
      "invoiceAmount": 10500.00,
      "overallConfidence": 85.5         // ← NOW POPULATED
    }
  ]
}
```

## Why This Happens

### Two-Step Submission Process

The system uses a two-step process:

**Step 1: Upload Documents**
- Creates package in `Uploaded` state
- Stores documents in blob storage
- Records document metadata in database
- **Does NOT extract data yet**

**Step 2: Submit Package**
- Validates required documents exist
- Triggers workflow orchestrator
- **Extracts data from all documents**
- Validates cross-document consistency
- Calculates confidence scores
- Generates recommendations
- Moves to `PendingApproval`

**Why Two Steps?**
- Allows users to upload documents incrementally
- User can review uploaded documents before submission
- Prevents partial submissions
- Ensures all required documents are present before processing

## Troubleshooting

### Problem: 403 Forbidden on /submit
**Cause:** Invalid or expired JWT token
**Solution:** Login again (Step 1)

### Problem: Package stuck in "Uploaded"
**Cause:** `/submit` endpoint not called
**Solution:** Call the submit endpoint (Step 3)

### Problem: Package stuck in "Extracting"
**Cause:** Extraction failing (check API logs)
**Solutions:**
- If using PDFs: Ensure Azure Document Intelligence is configured
- Try using JPG/PNG images instead (GPT-4 Vision works immediately)
- Check document quality (clear, readable, high resolution)
- Check API logs for specific error messages

### Problem: Low confidence scores
**Cause:** Poor document quality or unclear text
**Solutions:**
- Use high-resolution images (at least 1024px width)
- Ensure text is clear and readable
- Avoid blurry or low-quality scans
- Use proper lighting for photos

### Problem: Extraction returns wrong data
**Cause:** Document format not recognized or ambiguous
**Solutions:**
- Use standard document formats
- Ensure labels are clear (e.g., "PO Number:", "Total Amount:")
- Check if document is rotated or skewed
- Try different file formats

## Summary

**What You Need to Do:**

1. ✅ **Login again** to get new JWT token with valid role
   ```
   POST /api/auth/login
   ```

2. ✅ **Call submit endpoint** to trigger workflow
   ```
   POST /api/Submissions/{packageId}/submit
   ```

3. ✅ **Wait 30-60 seconds** for processing to complete

4. ✅ **Check package status** - data will be populated
   ```
   GET /api/Submissions/{packageId}
   ```

**The code is working correctly!** You just need to:
- Use a valid JWT token (login again)
- Trigger the workflow (call /submit)

That's it! The extraction will work and your data will be populated.
