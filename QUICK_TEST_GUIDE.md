# Quick Test Guide - Draft Submission Workflow

## 🚀 Quick Start

### 1. Start Backend
```bash
cd backend/src/BajajDocumentProcessing.API
dotnet run
```
Wait for: `Now listening on: http://localhost:5000`

### 2. Start Frontend
```bash
cd frontend
flutter run -d chrome
```

### 3. Login as Agency User
- Navigate to login page
- Use agency credentials
- Get JWT token

---

## 🧪 Test Sequence

### Test 1: Create Draft Submission ✅

**Action**: Click "New Submission" button

**Check Network Tab**:
```
POST http://localhost:5000/api/submissions/draft
Status: 201 Created
Response: { "submissionId": "0608f7dc-..." }
```

**Verify in Database**:
```sql
SELECT TOP 1 * FROM DocumentPackages 
WHERE State = 'Draft' 
ORDER BY CreatedAt DESC
```

**Expected**:
- New row with `State = 'Draft'`
- `SelectedPOId = NULL`
- `SubmittedByUserId` = your user ID

---

### Test 2: Select PO from Dropdown ✅

**Action**: Click PO dropdown, select a PO

**Check Network Tab**:
```
PATCH http://localhost:5000/api/submissions/0608f7dc-...
Status: 204 No Content
Body: { "selectedPOId": "a1b2c3d4-..." }
```

**Verify in Database**:
```sql
SELECT Id, SelectedPOId, UpdatedAt 
FROM DocumentPackages 
WHERE Id = '0608f7dc-...'
```

**Expected**:
- `SelectedPOId` now has a value
- `UpdatedAt` timestamp updated

---

### Test 3: Upload Invoice ✅

**Action**: Click "Upload Invoice", select a PDF file

**Check Network Tab**:
```
POST http://localhost:5000/api/documents/extract
Status: 200 OK
Response: {
  "extractedData": { ... },
  "documentId": "f1e2d3c4-...",
  "packageId": "0608f7dc-..."
}
```

**Verify in Database**:
```sql
SELECT 
    i.Id,
    i.PackageId,
    i.POId,
    i.InvoiceNumber,
    i.TotalAmount,
    i.ExtractionConfidence
FROM Invoices i
WHERE i.PackageId = '0608f7dc-...'
```

**Expected**:
- New invoice row created
- `PackageId` = draft submission ID
- `POId` = selected PO ID
- Extracted fields populated
- Form fields auto-filled in UI

---

## ❌ Error Tests

### Error Test 1: Upload Invoice Without PO

**Action**: 
1. Create draft submission
2. Upload invoice WITHOUT selecting PO first

**Expected**:
```
POST /api/documents/extract
Status: 400 Bad Request
Error: "Cannot upload invoice: no Purchase Order is linked to this submission. Please select a PO first."
```

**Verify**: No invoice created in database

---

### Error Test 2: Select Invalid PO

**Action**: 
1. Manually call PATCH with fake PO ID
```bash
curl -X PATCH http://localhost:5000/api/submissions/0608f7dc-... \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"selectedPOId": "00000000-0000-0000-0000-000000000000"}'
```

**Expected**:
```
Status: 400 Bad Request
Error: "Selected PO not found"
```

---

## 🔍 Database Verification Queries

### Check Draft Submission
```sql
SELECT 
    dp.Id,
    dp.State,
    dp.SelectedPOId,
    dp.VersionNumber,
    dp.CreatedAt,
    dp.UpdatedAt,
    po.PONumber
FROM DocumentPackages dp
LEFT JOIN POs po ON po.Id = dp.SelectedPOId
WHERE dp.State = 'Draft'
ORDER BY dp.CreatedAt DESC
```

### Check Invoices for Draft
```sql
SELECT 
    i.Id,
    i.InvoiceNumber,
    i.PackageId,
    i.POId,
    i.VersionNumber,
    i.TotalAmount,
    i.CreatedAt,
    po.PONumber
FROM Invoices i
INNER JOIN POs po ON po.Id = i.POId
WHERE i.PackageId = '0608f7dc-...'  -- Replace with your draft ID
ORDER BY i.CreatedAt
```

### Check for Data Integrity Issues
```sql
-- Invoices without valid PO (should be 0)
SELECT COUNT(*) AS OrphanedInvoices
FROM Invoices i
LEFT JOIN POs po ON po.Id = i.POId
WHERE po.Id IS NULL

-- Invoices without valid Package (should be 0)
SELECT COUNT(*) AS OrphanedInvoices
FROM Invoices i
LEFT JOIN DocumentPackages dp ON dp.Id = i.PackageId
WHERE dp.Id IS NULL
```

---

## 📊 Success Indicators

### UI Indicators
- ✅ Draft submission ID appears in URL or console
- ✅ PO dropdown shows available POs
- ✅ Selected PO displays in UI
- ✅ Invoice upload shows progress
- ✅ Form fields auto-populate after upload
- ✅ Success message appears
- ✅ Invoice appears in list

### Network Indicators
- ✅ POST /submissions/draft returns 201
- ✅ PATCH /submissions/{id} returns 204
- ✅ POST /documents/extract returns 200
- ✅ No 400/500 errors
- ✅ Response times < 5 seconds

### Database Indicators
- ✅ Draft submission exists with State='Draft'
- ✅ SelectedPOId populated after PO selection
- ✅ Invoice exists with correct PackageId
- ✅ Invoice POId matches SelectedPOId
- ✅ Invoice VersionNumber matches package
- ✅ No orphaned records

---

## 🐛 Common Issues & Solutions

### Issue: "Cannot upload invoice: no Purchase Order is linked"
**Cause**: PO not selected before invoice upload  
**Solution**: Select PO from dropdown first

### Issue: Draft ID changes during session
**Cause**: Bug in frontend (overwriting _currentPackageId)  
**Solution**: Verify _currentPackageId is set once and never overwritten

### Issue: Invoice saved with wrong PackageId
**Cause**: Frontend sending wrong packageId to extract API  
**Solution**: Verify widget.packageId is passed correctly

### Issue: Invoice POId is NULL
**Cause**: SelectedPOId not set before invoice upload  
**Solution**: Ensure PATCH call completes before invoice upload

### Issue: Extraction takes too long
**Cause**: Azure OpenAI API slow or rate limited  
**Solution**: Check Azure OpenAI service status, verify API key

---

## 📝 Test Checklist

- [ ] Backend API running on port 5000
- [ ] Frontend running and accessible
- [ ] Logged in as Agency user
- [ ] Can create draft submission
- [ ] Draft ID appears in console/network
- [ ] Can see PO dropdown
- [ ] Can select PO from dropdown
- [ ] PATCH call succeeds (204)
- [ ] SelectedPOId updated in database
- [ ] Can upload invoice file
- [ ] Extract API returns 200
- [ ] Form fields auto-populate
- [ ] Invoice saved in database
- [ ] Invoice has correct PackageId
- [ ] Invoice has correct POId
- [ ] Can upload multiple invoices
- [ ] All invoices have same PackageId
- [ ] Error shown if upload without PO
- [ ] No orphaned records in database

---

## 🎯 Quick SQL Checks

```sql
-- Last 5 draft submissions
SELECT TOP 5 Id, State, SelectedPOId, CreatedAt 
FROM DocumentPackages 
WHERE State = 'Draft' 
ORDER BY CreatedAt DESC

-- Last 5 invoices
SELECT TOP 5 Id, PackageId, POId, InvoiceNumber, CreatedAt 
FROM Invoices 
ORDER BY CreatedAt DESC

-- Count by state
SELECT State, COUNT(*) AS Count 
FROM DocumentPackages 
GROUP BY State

-- Invoices per draft
SELECT 
    dp.Id AS DraftId,
    COUNT(i.Id) AS InvoiceCount
FROM DocumentPackages dp
LEFT JOIN Invoices i ON i.PackageId = dp.Id
WHERE dp.State = 'Draft'
GROUP BY dp.Id
```

---

## ✅ Test Complete When...

1. Draft submission created successfully
2. PO selected and linked to draft
3. Invoice uploaded and extracted
4. Invoice saved with correct relationships
5. Form fields auto-populated
6. No errors in console or network tab
7. Database records correct and complete
8. Can repeat process for multiple invoices
9. Error handling works correctly
10. No orphaned or duplicate records

**Status**: Implementation Complete ✅  
**Ready for**: User Acceptance Testing
