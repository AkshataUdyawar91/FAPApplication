# ASM Review Page - Real Data Integration Complete

## Summary
Updated the ASM FAP Review Detail Page to display real data from the API instead of mock data.

## Changes Made

### 1. Added JSON Import
```dart
import 'dart:convert';
```
Required for parsing extracted data JSON strings from the API.

### 2. Updated Header Section
**Now displays:**
- Real submission state (PendingApproval, Approved, Rejected)
- Dynamic status badge colors based on actual state
- Real submission date from API
- Total amount extracted from Invoice document's ExtractedDataJson
- Fallback to ₹0 if amount not available

### 3. Updated AI Quick Summary
**Now displays:**
- Real overall confidence score from `confidenceScore.overallConfidence`
- Dynamic confidence badge color:
  - Green (≥85%)
  - Amber (70-84%)
  - Red (<70%)
- Real AI recommendation type (APPROVE, REVIEW, REJECT)
- Real validation status from `validationResult.allValidationsPassed`
- Real evidence text from `recommendation.evidence`
- Splits evidence into bullet points automatically

### 4. Updated Document Sections
**New method: `_buildDocumentSectionFromData()`**

Dynamically builds document sections from real API data:

**For Purchase Order:**
- Extracts PONumber from ExtractedDataJson
- Displays real PO number as subtitle
- Shows actual total amount
- Generates analysis points from extracted data
- Uses real confidence score from `confidenceScore.poConfidence`

**For Invoice:**
- Extracts InvoiceNumber from ExtractedDataJson
- Displays real invoice number as subtitle
- Shows actual total amount
- Validates against PO amount
- Uses real confidence score from `confidenceScore.invoiceConfidence`

**For Cost Summary:**
- Extracts TotalAmount from ExtractedDataJson
- Displays real total as subtitle
- Parses LineItems array for cost breakdown
- Dynamically builds cost breakdown table from real data
- Uses real confidence score from `confidenceScore.costSummaryConfidence`

### 5. Updated Photos Section
**New method: `_buildPhotosSectionFromData()`**

- Displays actual number of photos from API
- Shows real photo filenames
- Handles any number of photos (not just 3)
- Responsive layout:
  - ≤3 photos: Row layout
  - >3 photos: Wrap layout with 120px width
- Uses real confidence score from `confidenceScore.photosConfidence`
- Dynamic confidence badge colors

### 6. Data Parsing Logic
**Handles multiple data formats:**
- String JSON (needs `jsonDecode`)
- Map objects (direct access)
- Fallbacks for missing data
- Error handling with try-catch
- Default values when data unavailable

**Field name variations handled:**
- `PONumber` or `poNumber`
- `InvoiceNumber` or `invoiceNumber`
- `TotalAmount` or `totalAmount`
- `Date` or `date`
- `Description` or `description`
- `Amount` or `amount`

### 7. Confidence Score Color Coding
All sections now use dynamic colors based on actual confidence:
- **Green** (≥85%): High confidence, check icon
- **Amber** (70-84%): Medium confidence, warning icon
- **Red** (<70%): Low confidence, warning icon

### 8. Analysis Points Generation
Generates contextual analysis points based on:
- Document type
- Extracted field values
- Confidence scores
- Validation results

## API Response Structure Used

```json
{
  "id": "guid",
  "state": "PendingApproval",
  "createdAt": "2026-03-01T...",
  "updatedAt": "2026-03-01T...",
  "documents": [
    {
      "id": "guid",
      "type": "PO|Invoice|CostSummary|Photo",
      "filename": "document.pdf",
      "blobUrl": "https://...",
      "extractionConfidence": 0.95,
      "extractedData": "{\"PONumber\":\"PO-123\",\"TotalAmount\":45000,...}"
    }
  ],
  "confidenceScore": {
    "overallConfidence": 0.94,
    "poConfidence": 0.95,
    "invoiceConfidence": 0.92,
    "costSummaryConfidence": 0.90,
    "photosConfidence": 0.92
  },
  "validationResult": {
    "allValidationsPassed": true,
    "failureReason": null
  },
  "recommendation": {
    "type": "APPROVE",
    "evidence": "All validations passed\nAmounts match\nDocuments complete"
  }
}
```

## Benefits

1. ✅ **Accurate Data**: Shows actual submission data, not hardcoded values
2. ✅ **Dynamic UI**: Adapts to different document types and counts
3. ✅ **Real Confidence Scores**: Uses actual AI-generated confidence percentages
4. ✅ **Flexible Parsing**: Handles various data formats and field names
5. ✅ **Error Resilient**: Graceful fallbacks when data is missing
6. ✅ **Visual Feedback**: Color-coded badges reflect actual confidence levels
7. ✅ **Contextual Analysis**: Generated points use real extracted values

## Testing

To test with real data:
1. Login as Agency user (agency@bajaj.com / Password123!)
2. Upload documents to create a submission
3. Wait for AI processing to complete
4. Login as ASM user (asm@bajaj.com / Password123!)
5. Navigate to the submission review page
6. Verify all data matches the uploaded documents

## Files Modified

1. ✅ `frontend/lib/features/approval/presentation/pages/asm_review_detail_page.dart`
   - Added `dart:convert` import
   - Updated `_buildHeader()` to use real data
   - Updated `_buildAIQuickSummary()` to use real data
   - Replaced `_buildDocumentSections()` with dynamic data parsing
   - Added `_buildDocumentSectionFromData()` method
   - Added `_buildPhotosSectionFromData()` method
   - Removed old `_buildPhotosSection()` method

## Status
✅ **COMPLETE** - ASM Review Page now displays 100% real data from API
