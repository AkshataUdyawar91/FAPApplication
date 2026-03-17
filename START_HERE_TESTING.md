# 🚀 START HERE - Complete Validation Testing Guide

## 📋 Quick Overview

You have **33 validations** to test across 5 document types:
1. **Invoice**: 15 validations (12 field presence + 6 cross-document)
2. **Cost Summary**: 9 validations (5 field presence + 4 cross-document)
3. **Activity Summary**: 3 validations (2 field presence + 1 cross-document)
4. **Photo Proofs**: 6 validations (4 field presence + 2 cross-document)
5. **Enquiry Dump**: 0 validations (all marked as "No" - not required)

---

## 🎯 Your Current Status

You've uploaded a PO document and received:
```json
{
  "documentId": "6e125421-0222-458d-9119-ce3c5e40f9d4",
  "packageId": "ae879107-ba25-48dc-8347-e9bc4cab332e",
  "fileName": "PO_Vendor_Code_missing.pdf"
}
```

**Next Steps:**
1. Upload remaining documents (Invoice, Cost Summary, Activity, Photos)
2. Submit the package for validation
3. Review validation results

---

## 📝 Step-by-Step Testing Process

### Step 1: Upload All Required Documents

You need to upload to package `ae879107-ba25-48dc-8347-e9bc4cab332e`:

1. **Invoice** (with test scenarios)
2. **Cost Summary**
3. **Activity Summary**
4. **Photo Proofs** (5 photos to match man-days)

### Step 2: Submit Package for Validation

```bash
POST /api/submissions/ae879107-ba25-48dc-8347-e9bc4cab332e/submit
```

### Step 3: Review Validation Results

The response will show all 33 validation results.

---

## 🧪 Complete Test Scenarios

### Scenario 1: ALL VALIDATIONS PASS ✅

Upload documents with this data to see all validations pass.

### Scenario 2: INVOICE FIELD MISSING ❌

Upload invoice missing Agency Name to see field presence validation fail.

### Scenario 3: GST STATE MISMATCH ❌

Upload invoice with GST number from Karnataka (29) but state code Maharashtra (27).

### Scenario 4: COST EXCEEDS INVOICE ❌

Upload cost summary with total > invoice amount.

### Scenario 5: PHOTO COUNT MISMATCH ❌

Upload 3 photos when activity shows 5 man-days.

---

## 📊 What You'll See in Results

```json
{
  "packageId": "ae879107-ba25-48dc-8347-e9bc4cab332e",
  "allPassed": false,
  "invoiceFieldPresence": {
    "allFieldsPresent": false,
    "missingFields": ["Agency Name", "GST Number"]
  },
  "invoiceCrossDocument": {
    "allChecksPass": false,
    "gstStateMatches": false,
    "issues": ["GST Number '29AAAAA...' does not match State Code '27'"]
  },
  "issues": [
    {
      "field": "Invoice Fields",
      "issue": "Missing required fields: Agency Name, GST Number",
      "severity": "Error"
    }
  ]
}
```

---

## 🎯 Quick Test Commands

### Using Swagger UI (Easiest)

1. Open: http://localhost:5000/swagger
2. Login: agency@bajaj.com / Password123!
3. Authorize with token
4. Upload documents to your package
5. Submit package
6. Review results

### Using PowerShell

```powershell
# Submit package for validation
$token = "YOUR_JWT_TOKEN"
$packageId = "ae879107-ba25-48dc-8347-e9bc4cab332e"

$headers = @{
    Authorization = "Bearer $token"
}

Invoke-RestMethod -Uri "http://localhost:5000/api/submissions/$packageId/submit" `
    -Method Post -Headers $headers
```

---

## 📚 Detailed Documentation

- **COMPLETE_VALIDATION_TEST_DATA.md** - All test data with JSON
- **QUICK_TEST_REFERENCE.md** - Quick reference for each validation
- **VALIDATION_TEST_CASES.md** - Detailed test case specifications

---

## ✅ Success Checklist

- [ ] All documents uploaded to package
- [ ] Package submitted for validation
- [ ] Validation results received
- [ ] All 33 validations show in results
- [ ] Can identify which validations passed/failed
- [ ] Error messages are clear

**Continue to COMPLETE_VALIDATION_TEST_DATA.md for detailed test data →**
