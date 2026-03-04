# Quick Start Guide - Bajaj Document Processing System

## 🚀 System is Ready!

**Backend**: ✅ Running on http://localhost:5000
**Swagger UI**: http://localhost:5000/swagger
**Database**: ✅ Connected to SQL Server Express

---

## 📋 Test Credentials

All users have password: `Password123!`

| Email | Role | Can Do |
|-------|------|--------|
| agency@bajaj.com | Agency | Upload documents, submit packages |
| asm@bajaj.com | ASM | Review and approve/reject submissions |
| hq@bajaj.com | HQ | View analytics and all submissions |

---

## 🎯 Complete Test Flow (5 Minutes)

### Step 1: Login as Agency (1 min)

1. Open http://localhost:5000/swagger
2. Find `POST /api/auth/login`
3. Click "Try it out"
4. Enter:
   ```json
   {
     "email": "agency@bajaj.com",
     "password": "Password123!"
   }
   ```
5. Click "Execute"
6. **Copy the token** from response
7. Click "Authorize" button (top right, green lock icon)
8. Paste: `Bearer {your-token}`
9. Click "Authorize"

### Step 2: Upload Documents (2 min)

**Upload PO Document:**
1. Find `POST /api/documents/upload`
2. Click "Try it out"
3. Fill in:
   - **file**: Choose your PO PDF
   - **documentType**: Select `0` (PO)
   - **packageId**: Leave empty
4. Click "Execute"
5. **IMPORTANT**: Copy the `packageId` from response!

**Upload Invoice:**
1. Same endpoint `POST /api/documents/upload`
2. Fill in:
   - **file**: Choose your Invoice PDF
   - **documentType**: Select `1` (Invoice)
   - **packageId**: Paste the packageId from PO upload
3. Click "Execute"

**Upload Cost Summary:**
1. Same endpoint
2. Fill in:
   - **file**: Choose your Cost Summary Excel/PDF
   - **documentType**: Select `2` (CostSummary)
   - **packageId**: Same packageId
3. Click "Execute"

**Upload Photos (Optional):**
1. Same endpoint
2. Fill in:
   - **file**: Choose photo
   - **documentType**: Select `3` (Photo)
   - **packageId**: Same packageId
3. Can upload up to 20 photos

### Step 3: Submit Package (30 sec)

1. Find `POST /api/submissions/{packageId}/submit`
2. Click "Try it out"
3. Enter your **packageId**
4. Click "Execute"
5. Wait 10-15 seconds for processing

### Step 4: View Your Submission (30 sec)

1. Find `GET /api/submissions`
2. Click "Try it out"
3. Click "Execute"
4. You should see:
   - Invoice number
   - Invoice amount
   - Document count
   - State: "PendingApproval"

### Step 5: Review as ASM (1 min)

1. **Logout**: Click "Authorize" → "Logout"
2. **Login as ASM**:
   - Go back to `POST /api/auth/login`
   - Enter:
     ```json
     {
       "email": "asm@bajaj.com",
       "password": "Password123!"
     }
     ```
   - Copy new token
   - Authorize with new token

3. **View Pending Submissions**:
   - Find `GET /api/submissions`
   - Click "Try it out"
   - Set **state**: `PendingApproval`
   - Click "Execute"
   - You should see the submission!

4. **View Details**:
   - Find `GET /api/submissions/{id}`
   - Enter the submission ID
   - Click "Execute"
   - See extracted data, confidence scores, recommendations

5. **Approve**:
   - Find `PATCH /api/submissions/{id}/approve`
   - Enter submission ID
   - Click "Execute"
   - Done! ✅

---

## 🔍 What Gets Extracted

The system automatically extracts:

### From Invoice
- Invoice Number
- Vendor Name
- Invoice Date
- Total Amount
- Tax Amount
- Line Items

### From PO
- PO Number
- Vendor Name
- PO Date
- Total Amount
- Line Items

### From Cost Summary
- Campaign Name
- State
- Campaign Dates
- Total Cost
- Cost Breakdowns

### From Photos
- Timestamp (EXIF)
- GPS Location
- Device Info
- Dimensions

---

## 📊 Key Endpoints

### Authentication
```
POST /api/auth/login          - Get JWT token
POST /api/auth/refresh        - Refresh token
```

### Documents (Agency)
```
POST /api/documents/upload    - Upload document
GET  /api/documents/{id}      - Get document details
```

### Submissions
```
GET    /api/submissions                      - List submissions
GET    /api/submissions/{id}                 - Get details
POST   /api/submissions/{packageId}/submit   - Submit package (Agency)
PATCH  /api/submissions/{id}/approve         - Approve (ASM)
PATCH  /api/submissions/{id}/reject          - Reject (ASM)
```

### Analytics (ASM, HQ)
```
GET /api/analytics/kpis                - KPI dashboard
GET /api/analytics/state-roi           - State-wise ROI
GET /api/analytics/campaign-breakdown  - Campaign breakdown
```

---

## 🐛 Troubleshooting

### "Unauthorized" Error
- Token expired (30 min lifetime)
- Login again to get new token
- Make sure you clicked "Authorize" after login

### Invoice Data Not Showing
- Wait 10-15 seconds after upload
- Data extraction happens in background
- Check backend console for errors

### ASM Can't See Submission
- Make sure you called `/submit` endpoint
- Check state is "PendingApproval"
- If stuck in "Uploaded", use manual endpoint:
  ```
  PATCH /api/submissions/{id}/move-to-pending
  ```

### Upload Fails
- Check file size (max 10MB for docs, 5MB for photos)
- Verify file extension is allowed
- Check backend logs for details

---

## 📁 Document Types & Limits

| Type | Code | Max Size | Extensions |
|------|------|----------|------------|
| PO | 0 | 10MB | .pdf, .jpg, .png, .tiff |
| Invoice | 1 | 10MB | .pdf, .jpg, .png, .tiff |
| Cost Summary | 2 | 10MB | .pdf, .xls, .xlsx, .csv |
| Photo | 3 | 5MB | .jpg, .jpeg, .png, .heic |
| Additional | 4 | 10MB | .pdf, .doc, .docx, .xls, .xlsx |

**Photo Limit**: Maximum 20 photos per package

---

## 🔐 Security Notes

### Current Setup (Development)
- ⚠️ All users have same password
- ⚠️ JWT secret in config file
- ✅ Passwords hashed with BCrypt
- ✅ Tokens expire after 30 minutes
- ✅ Role-based access control

### For Production
- Use Azure Key Vault for secrets
- Implement MFA
- Use strong passwords
- Enable HTTPS only
- Set up monitoring

---

## 📈 Performance

- **Upload**: < 1 second
- **Extraction**: 5-15 seconds (background)
- **Submit**: < 1 second
- **Processing**: 30-60 seconds
- **API Response**: < 500ms

---

## 🎓 Tips

1. **Always copy the packageId** from first upload
2. **Wait 10-15 seconds** after upload for extraction
3. **Use same packageId** for all documents in a submission
4. **Submit package** when all documents uploaded
5. **Check backend logs** if something fails

---

## 📞 Need Help?

### Check These Files
- `CURRENT_STATUS.md` - Detailed system status
- `FIXES_IMPLEMENTED.md` - Recent changes
- `USERS_CREATED.md` - User credentials and workflows
- `AZURE_END_TO_END_FLOW.md` - Azure services flow

### Backend Logs
Look at the console where you ran `dotnet run` for detailed logs.

### Database Queries
```sql
-- View all packages
SELECT * FROM DocumentPackages ORDER BY CreatedAt DESC;

-- View documents in a package
SELECT * FROM Documents WHERE PackageId = '{your-package-id}';

-- View extracted data
SELECT Id, Type, FileName, ExtractionConfidence, 
       LEFT(ExtractedDataJson, 200) as ExtractedData
FROM Documents WHERE PackageId = '{your-package-id}';
```

---

## ✅ System Status

- ✅ Backend running on port 5000
- ✅ Database connected
- ✅ Azure OpenAI configured
- ✅ 3 test users created
- ✅ All core features working
- ✅ Swagger UI available
- ✅ Ready for testing!

**Start Testing Now**: http://localhost:5000/swagger

---

**Last Updated**: March 3, 2026
**Backend Process ID**: 33540
**Database**: BajajDocumentProcessing on localhost\SQLEXPRESS
