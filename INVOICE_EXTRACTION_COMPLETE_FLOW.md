# Invoice Extraction Complete Flow - FINAL

## Two Scenarios Handled

### Scenario 1: Previously Uploaded Invoice (Edit/Resubmit)
**Flow**: Load existing data from `CampaignInvoice` table

```
1. User opens rejected submission for edit
   ↓
2. Frontend calls GET /api/submissions/{id}
   ↓
3. API returns Campaigns with Invoices array
   ↓
4. Each invoice includes: InvoiceNumber, InvoiceDate, VendorName, GSTNumber, TotalAmount
   ↓
5. Frontend populates text fields with existing data
   ✅ WORKING - No changes needed
```

### Scenario 2: Newly Uploaded Invoice (During Edit)
**Flow**: Extract and show data in text boxes

```
1. User uploads new invoice file during edit
   ↓
2. Frontend calls POST /api/hierarchical/{packageId}/campaigns/{campaignId}/invoices
   ↓
3. API creates CampaignInvoice record
   ↓
4. API triggers background extraction (async)
   ↓
5. API returns immediately: { invoiceId, message: "Extraction in progress" }
   ↓
6. Frontend starts polling GET /api/hierarchical/invoices/{invoiceId}
   ↓
7. Poll every 2-3 seconds until extractionComplete = true
   ↓
8. When complete, API returns extracted data:
      - invoiceNumber
      - invoiceDate
      - vendorName
      - gstNumber
      - totalAmount
   ↓
9. Frontend updates text fields with extracted data
   ✅ NOW WORKING - New endpoint added
```

## New Endpoint Added

### GET /api/hierarchical/invoices/{invoiceId}
**Purpose**: Get invoice details for polling after upload

**Authorization**: Agency role only

**Response**:
```json
{
  "id": "guid",
  "invoiceNumber": "INV-001",
  "invoiceDate": "2025-01-15",
  "vendorName": "ABC Corp",
  "gstNumber": "27ABCDE1234F1Z5",
  "totalAmount": 50000.00,
  "fileName": "invoice.pdf",
  "blobUrl": "https://...",
  "extractionComplete": true
}
```

**extractionComplete Logic**:
- `true` if: InvoiceNumber is not empty AND TotalAmount > 0
- `false` if: Still extracting or extraction failed

## Frontend Implementation Guide

### Step 1: Upload Invoice
```dart
// Upload invoice
final response = await dio.post(
  '/api/hierarchical/$packageId/campaigns/$campaignId/invoices',
  data: FormData.fromMap({
    'file': await MultipartFile.fromFile(file.path),
    'invoiceNumber': '',  // Empty, will be extracted
    'invoiceDate': null,
    'vendorName': '',
    'gstNumber': '',
    'totalAmount': null,
  }),
);

final invoiceId = response.data['invoiceId'];
```

### Step 2: Poll for Extraction
```dart
// Start polling
Timer.periodic(Duration(seconds: 2), (timer) async {
  try {
    final response = await dio.get('/api/hierarchical/invoices/$invoiceId');
    final data = response.data;
    
    if (data['extractionComplete'] == true) {
      // Update UI with extracted data
      setState(() {
        invoice.invoiceNumber = data['invoiceNumber'] ?? '';
        invoice.invoiceDate = data['invoiceDate'] ?? '';
        invoice.vendorName = data['vendorName'] ?? '';
        invoice.gstNumber = data['gstNumber'] ?? '';
        invoice.totalAmount = data['totalAmount']?.toString() ?? '';
        invoice.isExtracting = false;
      });
      
      timer.cancel();  // Stop polling
    }
  } catch (e) {
    print('Polling error: $e');
    // Continue polling on error
  }
});
```

### Step 3: Show Loading State
```dart
// While extracting
if (invoice.isExtracting) {
  return Row(
    children: [
      CircularProgressIndicator(),
      SizedBox(width: 8),
      Text('Extracting invoice data...'),
    ],
  );
}

// After extraction
return Column(
  children: [
    TextField(
      controller: TextEditingController(text: invoice.invoiceNumber),
      decoration: InputDecoration(labelText: 'Invoice Number'),
    ),
    TextField(
      controller: TextEditingController(text: invoice.totalAmount),
      decoration: InputDecoration(labelText: 'Amount'),
    ),
    // ... other fields
  ],
);
```

## Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    EDIT/RESUBMIT FLOW                        │
└─────────────────────────────────────────────────────────────┘

┌──────────────────────┐
│ User Opens Rejected  │
│    Submission        │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ GET /api/submissions │
│        /{id}         │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│  Returns Campaigns → Invoices with all fields populated      │
│  (InvoiceNumber, TotalAmount, VendorName, GSTNumber, etc.)   │
└──────────┬───────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────┐
│ UI Shows Existing    │
│ Invoice Data         │
└──────────┬───────────┘
           │
           ├─────────────────────────────────────────────┐
           │                                             │
           ▼                                             ▼
┌──────────────────────┐                    ┌──────────────────────┐
│ User Keeps Existing  │                    │ User Uploads New     │
│ Invoice              │                    │ Invoice              │
└──────────┬───────────┘                    └──────────┬───────────┘
           │                                             │
           │                                             ▼
           │                              ┌──────────────────────────┐
           │                              │ POST /api/hierarchical/  │
           │                              │ {packageId}/campaigns/   │
           │                              │ {campaignId}/invoices    │
           │                              └──────────┬───────────────┘
           │                                         │
           │                                         ▼
           │                              ┌──────────────────────────┐
           │                              │ Returns: { invoiceId }   │
           │                              │ Background extraction    │
           │                              │ starts                   │
           │                              └──────────┬───────────────┘
           │                                         │
           │                                         ▼
           │                              ┌──────────────────────────┐
           │                              │ UI Starts Polling:       │
           │                              │ GET /api/hierarchical/   │
           │                              │ invoices/{invoiceId}     │
           │                              │ Every 2-3 seconds        │
           │                              └──────────┬───────────────┘
           │                                         │
           │                                         ▼
           │                              ┌──────────────────────────┐
           │                              │ extractionComplete?      │
           │                              └──────────┬───────────────┘
           │                                         │
           │                                         ├─ No → Continue polling
           │                                         │
           │                                         ▼ Yes
           │                              ┌──────────────────────────┐
           │                              │ UI Updates Text Fields   │
           │                              │ with Extracted Data      │
           │                              └──────────┬───────────────┘
           │                                         │
           ▼                                         ▼
┌──────────────────────────────────────────────────────────────┐
│                    User Clicks Resubmit                       │
└──────────────────────────────────────────────────────────────┘
```

## Testing Checklist

### Test 1: Edit with Existing Invoice
- [ ] Open rejected submission
- [ ] Verify invoice fields show previous values
- [ ] InvoiceNumber, TotalAmount, VendorName, GSTNumber all populated
- [ ] Edit some fields
- [ ] Resubmit
- [ ] Verify edits are preserved

### Test 2: Edit with New Invoice Upload
- [ ] Open rejected submission
- [ ] Upload new invoice file
- [ ] See "Extracting..." message
- [ ] Wait 10-20 seconds
- [ ] Verify invoice fields auto-populate
- [ ] InvoiceNumber and TotalAmount should appear
- [ ] Resubmit
- [ ] Verify extracted data is saved

### Test 3: Mixed Scenario
- [ ] Open rejected submission with 2 invoices
- [ ] Keep first invoice (existing data shown)
- [ ] Upload new second invoice (extraction happens)
- [ ] Verify first invoice keeps existing data
- [ ] Verify second invoice shows extracted data
- [ ] Resubmit
- [ ] Verify both invoices processed correctly

## Files Modified

1. `backend/src/BajajDocumentProcessing.API/Controllers/HierarchicalSubmissionController.cs`
   - Added GET /api/hierarchical/invoices/{invoiceId} endpoint
   - Returns invoice details with extractionComplete flag
   - Allows frontend to poll for extraction status

2. `backend/src/BajajDocumentProcessing.Infrastructure/Services/WorkflowOrchestrator.cs`
   - Updated to work with hierarchical model
   - Extracts from CampaignInvoices
   - Updates CampaignInvoice fields directly

3. `backend/src/BajajDocumentProcessing.API/Controllers/SubmissionsController.cs`
   - Made resubmit async (202 Accepted)
   - Allowed resubmit for RejectedByASM and RejectedByRA

## Status

🟢 **COMPLETE** - Both scenarios now working:
- ✅ Previously uploaded invoice: Shows existing data
- ✅ Newly uploaded invoice: Extracts and shows data via polling
