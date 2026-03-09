# Enhanced Validation Report - Testing Guide

## Prerequisites

### Backend
- ✅ Backend API running on `http://localhost:5000`
- ✅ Database with test submissions
- ✅ Users created (ASM and HQ)

### Frontend
- ✅ Flutter dependencies installed (`flutter pub get`)
- ✅ App wrapped with `ProviderScope` in `main.dart`

## Step-by-Step Testing

### Step 1: Start the Backend

```bash
cd backend
dotnet run
```

**Expected Output**:
```
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: http://localhost:5000
      Now listening on: https://localhost:7001
```

### Step 2: Test Backend API

Run the PowerShell test script:

```powershell
.\test-validation-report.ps1
```

**What to Check**:
- ✅ ASM login successful
- ✅ Submissions retrieved
- ✅ Validation report API returns data
- ✅ Summary shows confidence score
- ✅ Categories list validation results
- ✅ Recommendation shows action
- ✅ No errors in console

**Expected Output**:
```
========================================
Enhanced Validation Report Test Script
========================================

Step 1: Testing with ASM User
==============================

Logging in as asm@bajaj.com...
✓ Login successful
Fetching submissions...
✓ Found 26 submissions

Testing validation reports for first 3 submissions...

Submission 1:
  ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890
  State: PendingASMApproval
  PO Number: PO-12345

Testing validation report for submission: a1b2c3d4-e5f6-7890-abcd-ef1234567890
----------------------------------------
✓ Validation report retrieved successfully

VALIDATION SUMMARY:
  Overall Confidence: 87.5%
  Recommendation: RequestResubmission
  Risk Level: Medium
  Total Validations: 10
  Passed: 8
  Failed: 2
  Critical Issues: 0
  High Priority: 2
  Medium Priority: 0

VALIDATION CATEGORIES:
  ✓ PO Number Validation [Low]
    PO number matches across all documents
  ✓ Invoice Amount Validation [Low]
    Invoice amount is within acceptable range
  ✗ Date Validation [High]
    Invoice date is after PO date
    Expected: After 2026-02-15
    Actual: 2026-02-10
  ...

AI RECOMMENDATION:
  Action: RequestResubmission
  Reasoning: The submission has 2 high-priority issues...

✓ Test passed for submission 1
```

### Step 3: Start the Frontend

```bash
cd frontend
flutter run -d chrome
```

**Expected Output**:
```
Launching lib/main.dart on Chrome in debug mode...
Building application for the web...
...
Application finished.
```

### Step 4: Manual UI Testing

#### Test 1: Login and Navigate
1. Open browser to `http://localhost:XXXX` (Flutter will show the port)
2. Login as ASM user:
   - Email: `asm@bajaj.com`
   - Password: `ASM@123`
3. Verify you see the ASM review dashboard

**Expected**:
- ✅ Login successful
- ✅ Dashboard shows submissions
- ✅ Each submission row has two buttons/icons

#### Test 2: View Validation Report (Mobile View)
1. Resize browser to mobile width (< 600px)
2. Find a submission card
3. Click "View AI Report" button

**Expected**:
- ✅ Dialog opens full-screen
- ✅ Loading spinner appears briefly
- ✅ Validation report displays with:
  - Header with package ID
  - Confidence score card (green/orange/red)
  - Risk level badge
  - Validation statistics
  - Validation categories (expandable)
  - AI recommendation section
  - Detailed evidence (expandable)

#### Test 3: View Validation Report (Desktop View)
1. Resize browser to desktop width (> 900px)
2. Find a submission row in the table
3. Click the 📊 icon button

**Expected**:
- ✅ Dialog opens (90% width/height)
- ✅ Same content as mobile view
- ✅ Better layout for wider screen

#### Test 4: Expand Validation Category
1. Click on any validation category card
2. Verify it expands to show details

**Expected**:
- ✅ Card expands smoothly
- ✅ Shows description
- ✅ Shows Expected vs Actual values (side-by-side)
- ✅ Shows impact
- ✅ Shows suggested action with lightbulb icon

#### Test 5: Refresh Report
1. Click the refresh button (🔄) in dialog header
2. Verify report reloads

**Expected**:
- ✅ Loading spinner appears
- ✅ Report reloads with fresh data
- ✅ No errors

#### Test 6: Close Dialog
1. Click the close button (✕) in dialog header
2. Verify dialog closes

**Expected**:
- ✅ Dialog closes smoothly
- ✅ Returns to review dashboard
- ✅ No errors in console

#### Test 7: Error Handling
1. Stop the backend API
2. Click "View AI Report" button
3. Verify error state displays

**Expected**:
- ✅ Error message displays
- ✅ Retry button appears
- ✅ No crash or blank screen

#### Test 8: HQ User Testing
1. Logout from ASM account
2. Login as HQ user:
   - Email: `hq@bajaj.com`
   - Password: `HQ@123`
3. Repeat tests 2-6

**Expected**:
- ✅ Same functionality as ASM user
- ✅ All features work correctly

## Visual Verification Checklist

### Color Coding
- [ ] Green confidence (≥85%) displays correctly
- [ ] Orange confidence (70-85%) displays correctly
- [ ] Red confidence (<70%) displays correctly
- [ ] Risk level badges show correct colors
- [ ] Severity badges (Critical/High/Medium/Low) show correct colors

### Layout
- [ ] Header section displays properly
- [ ] Summary cards are side-by-side on desktop
- [ ] Validation categories are expandable
- [ ] Expected vs Actual boxes are side-by-side
- [ ] Recommendation section is clearly visible
- [ ] Detailed evidence section is collapsible

### Icons
- [ ] ✅ Check icons for passed validations
- [ ] ❌ Cancel icons for failed validations
- [ ] ⚠️ Warning icons for issues
- [ ] 💡 Lightbulb icons for suggestions
- [ ] 📊 Assessment icon in header

### Responsive Design
- [ ] Mobile view (< 600px) displays correctly
- [ ] Tablet view (600-900px) displays correctly
- [ ] Desktop view (> 900px) displays correctly
- [ ] Dialog is scrollable on small screens
- [ ] Buttons are touch-friendly (≥48×48)

## Performance Testing

### Load Time
1. Click "View AI Report" button
2. Measure time to display

**Expected**: < 2 seconds for typical report

### Refresh Time
1. Click refresh button
2. Measure time to reload

**Expected**: < 1 second (data already cached)

### Memory Usage
1. Open multiple validation reports
2. Check browser memory usage

**Expected**: No memory leaks, stable usage

## Browser Compatibility

Test on:
- [ ] Chrome (latest)
- [ ] Firefox (latest)
- [ ] Safari (latest)
- [ ] Edge (latest)

## Common Issues and Solutions

### Issue 1: "No provider found" Error
**Solution**: Ensure `main.dart` wraps app with `ProviderScope`:
```dart
void main() {
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}
```

### Issue 2: "Failed to load validation report"
**Possible Causes**:
- Backend not running
- Invalid submission ID
- Token expired
- User doesn't have ASM/HQ role

**Solution**: Check backend logs and verify token

### Issue 3: Button not visible
**Possible Causes**:
- Import statement missing
- Widget not in tree
- CSS/styling issue

**Solution**: Verify import and widget placement

### Issue 4: Dialog doesn't open
**Possible Causes**:
- Context invalid
- Navigation error
- Provider error

**Solution**: Check console for errors

## Styling Fine-Tuning

### If Colors Need Adjustment

Edit `frontend/lib/features/approval/presentation/widgets/enhanced_validation_report_widget.dart`:

```dart
// Confidence colors
if (confidence >= 85) {
  confidenceColor = Colors.green;  // Change to your preferred green
} else if (confidence >= 70) {
  confidenceColor = Colors.orange;  // Change to your preferred orange
} else {
  confidenceColor = Colors.red;  // Change to your preferred red
}
```

### If Spacing Needs Adjustment

```dart
// Adjust padding
padding: const EdgeInsets.all(16),  // Change 16 to your preferred value

// Adjust spacing between elements
const SizedBox(height: 12),  // Change 12 to your preferred value
```

### If Font Sizes Need Adjustment

```dart
// Adjust text styles
style: Theme.of(context).textTheme.titleLarge?.copyWith(
  fontSize: 24,  // Change to your preferred size
  fontWeight: FontWeight.bold,
),
```

## Success Criteria

The feature is working correctly if:
- ✅ Button appears on all submission rows
- ✅ Dialog opens when button is clicked
- ✅ Validation report loads and displays
- ✅ All sections are visible and readable
- ✅ Expandable sections work
- ✅ Refresh button works
- ✅ Close button works
- ✅ Error handling works
- ✅ Works for both ASM and HQ users
- ✅ Responsive on all screen sizes
- ✅ No console errors
- ✅ Performance is acceptable

## Next Steps After Testing

1. **Gather Feedback**: Show to stakeholders and gather feedback
2. **Adjust Styling**: Make any necessary visual adjustments
3. **Add Analytics**: Track usage of validation reports
4. **Document**: Update user documentation
5. **Deploy**: Deploy to staging/production environment

## Support

If you encounter issues:
1. Check browser console for errors
2. Check backend logs for API errors
3. Verify database has test data
4. Verify users have correct roles
5. Check network tab for failed requests
