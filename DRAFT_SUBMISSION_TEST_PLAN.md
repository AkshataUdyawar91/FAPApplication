# Draft Submission Workflow - Test Plan

## Test Scenario: Complete Draft Submission Flow

### Prerequisites
- Backend API running on `http://localhost:5000`
- Frontend running on `http://localhost:3000` (or appropriate port)
- Valid JWT token for Agency user
- At least one PO available in the system

### Test Steps

#### Step 1: Create Draft Submission
**Action**: Click "New Submission" button on Agency Dashboard

**Expected Backend Call**:
```http
POST /api/submissions/draft
Authorization: Bearer {token}
Content-Type: application/json

{}  // Empty body or optional {poId, agencyId}
```

**Expected Response**:
```json
{
  "submissionId": "0608f7dc-d95d-47dd-be7f-9f30d5b26e06",
  "submissionNumber": null
}
```

**Verification**:
- ✅ Draft submission created in `DocumentPackages` table
- ✅ `State` = "Draft"
- ✅ `SubmittedByUserId` = current user ID
- ✅ `AgencyId` = user's agency ID
- ✅ `SelectedPOId` = NULL (not set yet)

**SQL Query**:
```sql
SELECT Id, State, SubmittedByUserId, AgencyId, SelectedPOId, CreatedAt
FROM DocumentPackages
WHERE Id = '0608f7dc-d95d-47dd-be7f-9f30d5b26e06'
```

---

#### Step 2: Select PO from Dropdown
**Action**: User selects a PO from the dropdown (e.g., PO Number "PO-2024-001")

**Expected Backend Call**:
```http
PATCH /api/submissions/0608f7dc-d95d-47dd-be7f-9f30d5b26e06
Authorization: Bearer {token}
Content-Type: application/json

{
  "selectedPOId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
}
```

**Expected Response**:
```http
204 No Content
```

**Verification**:
- ✅ Draft submission updated with `SelectedPOId`
- ✅ `UpdatedAt` timestamp updated

**SQL Query**:
```sql
SELECT Id, SelectedPOId, UpdatedAt
FROM DocumentPackages
WHERE Id = '0608f7dc-d95d-47dd-be7f-9f30d5b26e06'

-- Verify PO exists
SELECT Id, PONumber, VendorName, TotalAmount
FROM POs
WHERE Id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
```

---

#### Step 3: Upload Invoice File
**Action**: User selects an invoice PDF file

**Expected Backend Call**:
```http
POST /api/documents/extract
Authorization: Bearer {token}
Content-Type: multipart/form-data

file: [invoice.pdf binary data]
documentType: invoice
packageId: 0608f7dc-d95d-47dd-be7f-9f30d5b26e06
```

**Expected Response**:
```json
{
  "extractedData": {
    "invoiceNumber": "INV-2024-001",
    "invoiceDate": "2024-03-15T00:00:00Z",
    "vendorName": "ABC Suppliers",
    "gstNumber": "29ABCDE1234F1Z5",
    "subTotal": 10000.00,
    "taxAmount": 1800.00,
    "totalAmount": 11800.00,
    "fieldConfidences": {
      "Overall": 0.95
    }
  },
  "documentId": "f1e2d3c4-b5a6-7890-cdef-123456789abc",
  "packageId": "0608f7dc-d95d-47dd-be7f-9f30d5b26e06",
  "blobUrl": "https://storage.blob.core.windows.net/documents/..."
}
```

**Verification**:
- ✅ Invoice saved to `Invoices` table
- ✅ `PackageId` = draft submission ID (0608f7dc...)
- ✅ `POId` = selected PO ID (a1b2c3d4...)
- ✅ `VersionNumber` matches package version
- ✅ Extracted data populated in invoice fields
- ✅ `CreatedBy` and `UpdatedBy` = current user ID

**SQL Query**:
```sql
SELECT 
    i.Id,
    i.PackageId,
    i.POId,
    i.VersionNumber,
    i.InvoiceNumber,
    i.InvoiceDate,
    i.VendorName,
    i.GSTNumber,
    i.TotalAmount,
    i.ExtractionConfidence,
    i.CreatedBy,
    i.UpdatedBy,
    i.CreatedAt
FROM Invoices i
WHERE i.PackageId = '0608f7dc-d95d-47dd-be7f-9f30d5b26e06'
AND i.IsDeleted = 0

-- Verify PO link
SELECT 
    p.Id AS POId,
    p.PONumber,
    i.Id AS InvoiceId,
    i.InvoiceNumber
FROM POs p
INNER JOIN Invoices i ON i.POId = p.Id
WHERE i.PackageId = '0608f7dc-d95d-47dd-be7f-9f30d5b26e06'
```

---

## Error Scenarios to Test

### Scenario A: Upload Invoice Without Selecting PO
**Action**: Upload invoice before selecting PO from dropdown

**Expected Behavior**:
- ❌ Extract API returns 400 Bad Request
- Error message: "Cannot upload invoice: no Purchase Order is linked to this submission. Please select a PO first."

**Verification**:
```sql
-- No invoice should be created
SELECT COUNT(*) FROM Invoices 
WHERE PackageId = '0608f7dc-d95d-47dd-be7f-9f30d5b26e06'
-- Expected: 0
```

---

### Scenario B: Select Invalid PO
**Action**: Attempt to PATCH with non-existent PO ID

**Expected Behavior**:
- ❌ PATCH API returns 400 Bad Request
- Error message: "Selected PO not found"

---

### Scenario C: Multiple Invoice Uploads
**Action**: Upload 3 different invoices to the same draft submission

**Expected Behavior**:
- ✅ All 3 invoices saved with same `PackageId`
- ✅ All 3 invoices linked to same `POId`
- ✅ All 3 invoices have same `VersionNumber`

**Verification**:
```sql
SELECT 
    InvoiceNumber,
    PackageId,
    POId,
    VersionNumber,
    TotalAmount
FROM Invoices
WHERE PackageId = '0608f7dc-d95d-47dd-be7f-9f30d5b26e06'
AND IsDeleted = 0
ORDER BY CreatedAt
-- Expected: 3 rows, all with same PackageId and POId
```

---

## Key Validation Points

### ✅ Draft ID Consistency
- `_currentPackageId` set once on page load
- Never overwritten during PO selection
- Same ID used for all invoice uploads

### ✅ PO Linking
- PATCH call updates `SelectedPOId` immediately
- Extract API validates PO exists before creating invoice
- Invoice `POId` field correctly populated

### ✅ Data Integrity
- Invoice `PackageId` matches draft submission ID
- Invoice `POId` matches selected PO ID
- Invoice `VersionNumber` matches package version
- `CreatedBy` and `UpdatedBy` fields populated

### ✅ No Duplicate Processing
- Extract API does both extraction AND saving
- No separate upload API call needed
- No polling required (data returned immediately)

---

## Database Verification Queries

### Check Draft Submission
```sql
SELECT 
    dp.Id AS SubmissionId,
    dp.State,
    dp.SelectedPOId,
    dp.VersionNumber,
    dp.SubmittedByUserId,
    dp.AgencyId,
    dp.CreatedAt,
    dp.UpdatedAt,
    po.PONumber AS SelectedPONumber
FROM DocumentPackages dp
LEFT JOIN POs po ON po.Id = dp.SelectedPOId
WHERE dp.Id = '0608f7dc-d95d-47dd-be7f-9f30d5b26e06'
```

### Check Invoices Linked to Draft
```sql
SELECT 
    i.Id AS InvoiceId,
    i.InvoiceNumber,
    i.PackageId,
    i.POId,
    i.VersionNumber,
    i.TotalAmount,
    i.ExtractionConfidence,
    i.CreatedAt,
    po.PONumber
FROM Invoices i
INNER JOIN POs po ON po.Id = i.POId
WHERE i.PackageId = '0608f7dc-d95d-47dd-be7f-9f30d5b26e06'
AND i.IsDeleted = 0
ORDER BY i.CreatedAt
```

### Check for Orphaned Invoices (Should be 0)
```sql
-- Invoices without valid PO link
SELECT 
    i.Id,
    i.InvoiceNumber,
    i.POId,
    i.PackageId
FROM Invoices i
LEFT JOIN POs po ON po.Id = i.POId
WHERE i.PackageId = '0608f7dc-d95d-47dd-be7f-9f30d5b26e06'
AND po.Id IS NULL
-- Expected: 0 rows
```

---

## Success Criteria

✅ Draft submission created with unique ID  
✅ PO selection updates `SelectedPOId` immediately  
✅ Invoice upload validates PO exists  
✅ Invoice saved with correct `PackageId`, `POId`, `VersionNumber`  
✅ Extracted data auto-populates form fields  
✅ No duplicate processing (extract API handles everything)  
✅ No polling required (data returned immediately)  
✅ Multiple invoices can be uploaded to same draft  
✅ Error handling prevents invoice creation without PO  

---

## Next Steps After Testing

1. Test with real invoice PDFs
2. Verify extraction accuracy for different invoice formats
3. Test with multiple POs and multiple invoices
4. Test error scenarios (network failures, invalid files)
5. Verify UI updates correctly after each step
6. Test complete submission flow (draft → submit → approval)
