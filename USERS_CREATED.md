# Users Created Successfully ✅

## Login Credentials

All users have been created with the password: `Password123!`

### Agency User
- **Email**: `agency@bajaj.com`
- **Password**: `Password123!`
- **Role**: Agency
- **Permissions**: 
  - Upload documents
  - View own submissions
  - Submit packages for review

### ASM User (Area Sales Manager)
- **Email**: `asm@bajaj.com`
- **Password**: `Password123!`
- **Role**: ASM
- **Permissions**:
  - View all submissions in PendingApproval state
  - Approve or reject submissions
  - Request re-upload
  - View analytics

### HQ User (Headquarters)
- **Email**: `hq@bajaj.com`
- **Password**: `Password123!`
- **Role**: HQ
- **Permissions**:
  - View all submissions (all states)
  - View comprehensive analytics
  - Access chat assistant (when Azure AI Search is configured)
  - Export reports

## Quick Start Testing

### 1. Test Login (All Users)

Open Swagger: `http://localhost:5000/swagger`

1. Expand `/api/auth/login`
2. Click "Try it out"
3. Enter credentials:
   ```json
   {
     "email": "agency@bajaj.com",
     "password": "Password123!"
   }
   ```
4. Click "Execute"
5. Copy the `token` from response
6. Click "Authorize" button at top
7. Enter: `Bearer {your-token}`
8. Click "Authorize"

### 2. Test Document Upload (Agency User)

1. Login as `agency@bajaj.com`
2. Authorize with the token
3. Expand `/api/documents/upload`
4. Click "Try it out"
5. Upload a document:
   - **file**: Choose your PO document
   - **documentType**: Select `PO` (0)
   - **packageId**: Leave empty for first upload
6. Click "Execute"
7. Note the `packageId` in the response
8. Repeat for Invoice, Cost Summary, and Photos using the same `packageId`

### 3. Submit Package (Agency User)

After uploading all documents:

1. Expand `/api/submissions/{packageId}/submit`
2. Click "Try it out"
3. Enter the `packageId` from step 2
4. Click "Execute"
5. System will:
   - Extract data using Azure OpenAI
   - Validate documents
   - Calculate confidence scores
   - Generate recommendations
   - Move to PendingApproval state

### 4. Review Submission (ASM User)

1. Logout and login as `asm@bajaj.com`
2. Authorize with the new token
3. Expand `/api/submissions`
4. Click "Try it out"
5. Set `state` parameter to `PendingApproval`
6. Click "Execute"
7. You should see the submission with invoice data

### 5. Approve/Reject (ASM User)

To approve:
1. Expand `/api/submissions/{id}/approve`
2. Enter the submission ID
3. Click "Execute"

To reject:
1. Expand `/api/submissions/{id}/reject`
2. Enter the submission ID
3. Enter rejection reason in body:
   ```json
   {
     "reason": "Missing required information"
   }
   ```
4. Click "Execute"

### 6. View Analytics (HQ User)

1. Login as `hq@bajaj.com`
2. Authorize with the token
3. Expand `/api/analytics/kpis`
4. Set date range
5. Click "Execute"
6. View KPI dashboard data

## Complete Workflow Example

### Agency Workflow
```
1. Login → Get token
2. Upload PO → Get packageId
3. Upload Invoice → Use same packageId
4. Upload Cost Summary → Use same packageId
5. Upload Photos (up to 20) → Use same packageId
6. Submit Package → POST /api/submissions/{packageId}/submit
7. View Submissions → GET /api/submissions
   (Should show invoice number and amount)
```

### ASM Workflow
```
1. Login → Get token
2. List Pending Submissions → GET /api/submissions?state=PendingApproval
3. View Submission Details → GET /api/submissions/{id}
   (See extracted data, confidence scores, recommendations)
4. Make Decision:
   - Approve → PATCH /api/submissions/{id}/approve
   - Reject → PATCH /api/submissions/{id}/reject
   - Request Reupload → PATCH /api/submissions/{id}/request-reupload
```

### HQ Workflow
```
1. Login → Get token
2. View All Submissions → GET /api/submissions
3. View Analytics → GET /api/analytics/kpis
4. View State ROI → GET /api/analytics/state-roi
5. View Campaign Breakdown → GET /api/analytics/campaign-breakdown
6. Chat (if Azure AI Search configured) → POST /api/chat/message
```

## API Endpoints by Role

### Agency Endpoints
- `POST /api/auth/login` - Login
- `POST /api/documents/upload` - Upload documents
- `GET /api/documents/{id}` - Get document details
- `GET /api/submissions` - View own submissions
- `GET /api/submissions/{id}` - View submission details
- `POST /api/submissions/{packageId}/submit` - Submit package
- `GET /api/notifications` - View notifications

### ASM Endpoints
All Agency endpoints plus:
- `GET /api/submissions?state=PendingApproval` - View pending submissions
- `PATCH /api/submissions/{id}/approve` - Approve submission
- `PATCH /api/submissions/{id}/reject` - Reject submission
- `PATCH /api/submissions/{id}/request-reupload` - Request reupload
- `GET /api/analytics/kpis` - View KPIs

### HQ Endpoints
All ASM endpoints plus:
- `GET /api/analytics/state-roi` - State-wise ROI
- `GET /api/analytics/campaign-breakdown` - Campaign breakdown
- `POST /api/chat/message` - Chat with AI (requires Azure AI Search)
- `GET /api/chat/history` - Chat history

## Troubleshooting

### Login Fails
- Verify email and password are correct
- Check if user exists: Run `SELECT * FROM Users WHERE Email = 'agency@bajaj.com'`
- Verify backend is running on port 5000

### Token Expired
- Tokens expire after 30 minutes
- Login again to get a new token
- Or use `/api/auth/refresh` endpoint

### Can't See Submissions (ASM)
- Verify submission state is `PendingApproval`
- Check if package was submitted: `POST /api/submissions/{packageId}/submit`
- If still in `Uploaded` state, use: `PATCH /api/submissions/{id}/move-to-pending`

### Invoice Data Not Showing
- Wait 10-15 seconds after upload for extraction to complete
- Check backend logs for extraction errors
- Verify Azure OpenAI credentials are correct

## Database Verification

To verify users in database:

```sql
USE BajajDocumentProcessing;

SELECT 
    Email,
    FullName,
    CASE Role
        WHEN 0 THEN 'Agency'
        WHEN 1 THEN 'ASM'
        WHEN 2 THEN 'HQ'
    END as RoleName,
    IsActive,
    CreatedAt
FROM Users
WHERE IsDeleted = 0;
```

## Security Notes

### Production Recommendations
1. **Change passwords** - Use strong, unique passwords for each user
2. **Use Azure Key Vault** - Store JWT secret securely
3. **Enable MFA** - Add multi-factor authentication
4. **Audit logging** - Monitor all user actions
5. **Password policy** - Enforce strong password requirements
6. **Session management** - Implement proper session timeout

### Current Setup (Development)
- ⚠️ All users have the same password
- ⚠️ JWT secret is in appsettings.json
- ⚠️ No MFA enabled
- ⚠️ No password expiration
- ✅ Passwords are hashed with BCrypt
- ✅ JWT tokens expire after 30 minutes
- ✅ Role-based authorization enabled

---

## Summary

✅ **3 users created** - Agency, ASM, HQ
✅ **All roles configured** - Proper permissions set
✅ **Ready for testing** - Login via Swagger
✅ **Database clean** - No old/mock data

**Next Step**: Test login at `http://localhost:5000/swagger` with `agency@bajaj.com` / `Password123!`
