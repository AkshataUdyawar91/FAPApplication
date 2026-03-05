# User Role Fix Complete ✅

## Problem
403 Forbidden error when submitting package because JWT token had invalid role.

**JWT Token showed:**
```json
{
  "role": "0"  // ← Invalid! Should be 1, 2, or 3
}
```

**Valid Role Values:**
- `Agency = 1`
- `ASM = 2`
- `HQ = 3`

## Root Cause
Users in the database had `Role = 0` which is not a valid enum value.

## Fix Applied
✅ Updated all users in database with correct roles:
```sql
UPDATE Users SET Role = 1 WHERE Email = 'agency@bajaj.com';  -- Agency
UPDATE Users SET Role = 2 WHERE Email = 'asm@bajaj.com';     -- ASM
UPDATE Users SET Role = 3 WHERE Email = 'hq@bajaj.com';      -- HQ
```

## Next Steps

### 1. Login Again to Get New Token
Your old token is invalid. Login again:

```bash
POST http://localhost:5000/api/Auth/login
Content-Type: application/json

{
  "email": "agency@bajaj.com",
  "password": "Agency@123"
}
```

**New token will have:**
```json
{
  "role": "Agency"  // ← Correct!
}
```

### 2. Test Package Submission
Use the NEW token:

```bash
POST http://localhost:5000/api/Submissions/72463bb1-db3f-4762-9c87-395c3f8209c3/submit
Authorization: Bearer {NEW_TOKEN_HERE}
```

**Expected: 200 OK** (not 403 anymore!)

### 3. Monitor Workflow
Watch the backend logs for:
```
[Information] User {UserId} submitting package {PackageId}
[Information] Starting workflow orchestration for package {PackageId}
[Information] Starting extraction step...
[Information] PO extraction completed. PO Number: X, Total Amount: Y
[Information] Scoring step completed, Score: X
```

### 4. Check Results
Poll the submission:
```bash
GET http://localhost:5000/api/Submissions/72463bb1-db3f-4762-9c87-395c3f8209c3
Authorization: Bearer {NEW_TOKEN}
```

After 30-60 seconds, you should see:
```json
{
  "state": "PendingApproval",
  "poNumber": "PO-12345",
  "poAmount": 50000,
  "overallConfidence": 85.5
}
```

## About PDF Extraction

You mentioned using PDFs. The logs show:
```
warn: PDF file detected - returning placeholder data
```

**For PDFs to work properly:**
1. Azure Document Intelligence must be configured
2. OR use image files (JPG/PNG) which work with GPT-4 Vision

**Current Status:**
- ✅ GPT-4 Vision configured (works with images)
- ⚠️ Document Intelligence may need configuration (for PDFs)

**Recommendation:**
- Test with image files first to verify the workflow works
- Then configure Document Intelligence for PDF support

## Summary

✅ **User roles fixed in database**
✅ **Login again to get new token**
✅ **Submit endpoint should work now**
⚠️ **Use image files for immediate testing**
⚠️ **Configure Document Intelligence for PDF support**

The 403 error was caused by invalid role in the JWT token. Now that roles are fixed, login again and the submission should work!
