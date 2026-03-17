# Campaign Details - Quick Reference

## 🎯 What Changed

### Step 3 Renamed
**Before**: "Photos & Cost Summary" 📷  
**After**: "Campaign Details" 📅

### Step 3 Structure
```
┌─────────────────────────────────────────┐
│  Campaign Details Section (NEW)        │
│  ┌───────────────────────────────────┐ │
│  │ 📅 Start Date:  [dd-mm-yyyy]     │ │
│  │ 📅 End Date:    [dd-mm-yyyy]     │ │
│  │ 📊 Working Days: [Auto-calculated]│ │
│  └───────────────────────────────────┘ │
│                                         │
│  Photos Upload Section                 │
│  ┌───────────────────────────────────┐ │
│  │ 📷 Upload team photos             │ │
│  └───────────────────────────────────┘ │
│                                         │
│  Cost Summary Upload                   │
│  ┌───────────────────────────────────┐ │
│  │ 📄 Upload cost summary (PDF)      │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

## 📊 Database Schema

### New Columns in `DocumentPackages` Table

| Column Name | Type | Nullable | Description |
|------------|------|----------|-------------|
| `CampaignStartDate` | DATETIME2 | Yes | Campaign start date |
| `CampaignEndDate` | DATETIME2 | Yes | Campaign end date |
| `CampaignWorkingDays` | INT | Yes | Working days (excluding weekends) |

## 🚀 Quick Start

### 1. Run Database Migration
```bash
add-campaign-fields.bat
```

### 2. Rebuild & Run
```bash
# Backend
cd backend
dotnet build
dotnet run --project src/BajajDocumentProcessing.API

# Frontend
cd frontend
flutter pub get
flutter run -d chrome
```

## 📝 Usage Example

### User Flow:
1. Navigate to Step 3 "Campaign Details"
2. Click "Start Date" → Select **01-03-2024**
3. Click "End Date" → Select **15-03-2024**
4. Working Days automatically shows **"11 days"** ✅
5. Upload photos and cost summary
6. Click "Next Step" → Proceeds to Step 4
7. Submit → Campaign data saved to database

### Working Days Calculation:
```
Start: March 1, 2024 (Friday)
End: March 15, 2024 (Friday)

Total Days: 15 days
Weekends: 4 days (2 Saturdays + 2 Sundays)
Working Days: 11 days ✅
```

## 🔍 Verify Installation

### Check Database:
```sql
SELECT TOP 1
  CampaignStartDate,
  CampaignEndDate,
  CampaignWorkingDays
FROM DocumentPackages
WHERE CampaignStartDate IS NOT NULL
ORDER BY CreatedAt DESC;
```

### Expected Result:
```
CampaignStartDate    | CampaignEndDate      | CampaignWorkingDays
---------------------|----------------------|--------------------
2024-03-01 00:00:00 | 2024-03-15 00:00:00 | 11
```

## ✅ Validation Rules

- ✅ Start Date is **required**
- ✅ End Date is **required**
- ✅ End Date must be **>= Start Date**
- ✅ Working Days **auto-calculated** (read-only)
- ✅ Weekends (Sat/Sun) **excluded** from count

## 📱 Responsive Design

### Desktop (≥ 600px):
```
┌──────────────┬──────────────┬──────────────┐
│  Start Date  │   End Date   │ Working Days │
└──────────────┴──────────────┴──────────────┘
```

### Mobile (< 600px):
```
┌──────────────┐
│  Start Date  │
├──────────────┤
│   End Date   │
├──────────────┤
│ Working Days │
└──────────────┘
```

## 🎨 UI Features

- 📅 Date picker with calendar widget
- 🎨 Bajaj primary blue (#003087) theme
- 📊 Gray background for read-only working days
- ✅ Real-time calculation on date change
- 📱 Fully responsive layout
- ♿ Accessible with semantic labels

## 📦 Files Changed

### Created:
- ✅ `frontend/lib/features/submission/presentation/widgets/campaign_details_section.dart`
- ✅ `ADD_CAMPAIGN_FIELDS.sql`
- ✅ `add-campaign-fields.bat`

### Modified:
- ✅ `frontend/lib/features/submission/presentation/pages/agency_upload_page.dart`
- ✅ `backend/src/BajajDocumentProcessing.Domain/Entities/DocumentPackage.cs`
- ✅ `backend/src/BajajDocumentProcessing.API/Controllers/DocumentsController.cs`
- ✅ `backend/src/BajajDocumentProcessing.API/Controllers/SubmissionsController.cs`

## 🐛 Troubleshooting

### Issue: "Column already exists" error
**Solution**: Migration is idempotent, safe to re-run

### Issue: Working days shows "Invalid range"
**Solution**: End date is before start date, select valid range

### Issue: Cannot proceed to Step 4
**Solution**: Fill both start and end dates

### Issue: Campaign data not saved
**Solution**: Check backend logs, verify database connection

## 📞 Support

For issues or questions, check:
- `CAMPAIGN_DETAILS_IMPLEMENTATION_COMPLETE.md` - Full documentation
- Backend logs: `backend/src/BajajDocumentProcessing.API/logs/`
- Frontend console: Browser DevTools

---

**Status**: ✅ Ready for Testing  
**Version**: 1.0  
**Date**: March 8, 2026
