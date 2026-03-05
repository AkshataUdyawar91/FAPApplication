# Trigger Workflow for Existing Submissions

## Problem
Submissions are created and documents are uploaded, but the workflow orchestrator is never triggered because the `/api/submissions/{packageId}/submit` endpoint is not being called.

## Solution Options

### Option 1: Manual API Calls (Quick Fix)
Call the submit endpoint for each existing package:

```bash
# Get all package IDs in Uploaded state
curl -X GET "http://localhost:5000/api/submissions" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"

# For each package ID, call submit:
curl -X POST "http://localhost:5000/api/submissions/{PACKAGE_ID}/submit" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

### Option 2: SQL Script to Reset State (For Testing)
If you want to manually trigger the workflow, you can call the API endpoint or use the backend directly.

### Option 3: Fix the Frontend (Permanent Solution)
The Agency upload page needs to call the submit endpoint after all documents are uploaded.

## Current Workflow Issue

**What's happening:**
1. ✅ Agency uploads documents → Creates DocumentPackage in "Uploaded" state
2. ❌ **MISSING STEP**: Call `/api/submissions/{packageId}/submit`
3. ❌ Workflow never runs → No extraction, validation, scoring, or recommendations

**What should happen:**
1. ✅ Agency uploads documents → Creates DocumentPackage
2. ✅ **Call submit endpoint** → Triggers WorkflowOrchestrator
3. ✅ Workflow runs:
   - Extracting → Extracts PO/Invoice data
   - Validating → Cross-document validation
   - Scoring → Calculates confidence scores
   - Recommending → Generates AI recommendation
   - PendingApproval → Ready for ASM review

## Quick Test

To test if the workflow works, you can manually call the submit endpoint using Swagger:

1. Go to http://localhost:5000/swagger
2. Login as Agency user to get token
3. Find POST `/api/submissions/{packageId}/submit`
4. Enter a package ID from your database
5. Execute

This should trigger the workflow and populate:
- ExtractedDataJson in Documents table
- ConfidenceScores table
- ValidationResults table
- Recommendations table
- Package state changes to PendingApproval

## Permanent Fix Needed

The Agency upload page needs to be updated to call the submit endpoint after all documents are uploaded. This is a frontend issue that needs to be fixed.
