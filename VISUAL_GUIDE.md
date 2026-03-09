# Enhanced Validation Report - Visual Guide

## Button Locations

### ASM Review Page - Mobile View

```
┌─────────────────────────────────────────┐
│  ← Back to Login          [Logout]      │
├─────────────────────────────────────────┤
│                                         │
│  📊 Pending Review: 5                   │
│  ✅ Approved: 12                        │
│  ❌ Rejected: 3                         │
│                                         │
├─────────────────────────────────────────┤
│  🔍 Search...                           │
│  Filter: [All Status ▼]                 │
│  Sort: [Date ▼]                         │
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────────────────────────┐ │
│  │ FAP-A1B2C3D4        [Pending]     │ │
│  │                                   │ │
│  │ PO Number: PO-12345               │ │
│  │ PO Amount: ₹50,000.00             │ │
│  │ Invoice: INV-67890                │ │
│  │ Invoice Amount: ₹48,500.00        │ │
│  │ Submitted: 08/03/2026             │ │
│  │ AI Score: 87%                     │ │
│  │                                   │ │
│  │ ┌──────────┐  ┌─────────────┐    │ │
│  │ │ 📊 View  │  │ 👁 View     │    │ │  ← NEW BUTTON!
│  │ │ AI Report│  │ Details     │    │ │
│  │ └──────────┘  └─────────────┘    │ │
│  └───────────────────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

### ASM Review Page - Desktop View

```
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│  ← Back to Login                                              Logged in as: John Doe [Logout] │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                                      │
│  │ 📊 Pending   │  │ ✅ Approved  │  │ ❌ Rejected  │                                      │
│  │    Review    │  │              │  │              │                                      │
│  │      5       │  │     12       │  │      3       │                                      │
│  └──────────────┘  └──────────────┘  └──────────────┘                                      │
│                                                                                              │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│  🔍 Search...                                                                                │
│  Filter: [All Status ▼]              Sort: [Date ▼]                                         │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────────────────────┐ │
│  │ FAP NO.  │ PO NO.  │ PO AMT    │ INVOICE  │ INV AMT   │ DATE     │ SCORE │ STATUS │ │ │
│  ├────────────────────────────────────────────────────────────────────────────────────────┤ │
│  │ FAP-A1B2 │ PO-123  │ ₹50,000   │ INV-678  │ ₹48,500   │ 08/03/26 │ 87%   │[Badge] │📊👁│ │
│  │          │         │           │          │           │          │       │        │ │ │ │
│  │ FAP-C3D4 │ PO-456  │ ₹75,000   │ INV-901  │ ₹73,200   │ 07/03/26 │ 92%   │[Badge] │📊👁│ │
│  └────────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                    ↑         │
│                                                                              NEW BUTTONS!    │
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```

## Dialog View

### When User Clicks "View AI Report" Button

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│  📊 Enhanced Validation Report                                    🔄 Refresh  ✕    │
│  Package ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890                                  │
├────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────────────┐ │
│  │  📊 AI Validation Report                                                     │ │
│  │  Detailed analysis with actionable insights                                  │ │
│  ├──────────────────────────────────────────────────────────────────────────────┤ │
│  │                                                                              │ │
│  │  Validation Summary                                                          │ │
│  │                                                                              │ │
│  │  ┌─────────────────────┐  ┌─────────────────────────────────────────────┐  │ │
│  │  │   ✅                │  │  Total Validations:        10              │  │ │
│  │  │   87.5%             │  │  Passed:                   8               │  │ │
│  │  │   Overall Confidence│  │  Failed:                   2               │  │ │
│  │  │   [Low Risk]        │  │  ─────────────────────────────────────────  │  │ │
│  │  └─────────────────────┘  │  Critical Issues:          0               │  │ │
│  │                            │  High Priority:            2               │  │ │
│  │                            └─────────────────────────────────────────────┘  │ │
│  │                                                                              │ │
│  ├──────────────────────────────────────────────────────────────────────────────┤ │
│  │                                                                              │ │
│  │  Validation Details                                                          │ │
│  │                                                                              │ │
│  │  ✅ PO Number Validation                                    [Low]      ▼    │ │
│  │     PO number matches across all documents                                   │ │
│  │                                                                              │ │
│  │  ✅ Invoice Amount Validation                               [Low]      ▼    │ │
│  │     Invoice amount is within acceptable range of PO amount                   │ │
│  │                                                                              │ │
│  │  ❌ Date Validation                                         [High]     ▼    │ │
│  │     Invoice date is after PO date                                            │ │
│  │     ┌────────────────────────────────────────────────────────────────────┐  │ │
│  │     │ Description: Invoice date must be after PO date                    │  │ │
│  │     │                                                                     │  │ │
│  │     │ Expected: After 2026-02-15    Actual: 2026-02-10                   │  │ │
│  │     │                                                                     │  │ │
│  │     │ Impact: May indicate backdated invoice or data entry error         │  │ │
│  │     │                                                                     │  │ │
│  │     │ 💡 Suggested Action: Verify invoice date with agency and correct   │  │ │
│  │     └────────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                              │ │
│  │  ❌ Vendor Validation                                       [High]     ▼    │ │
│  │     Vendor name mismatch between PO and Invoice                              │ │
│  │                                                                              │ │
│  ├──────────────────────────────────────────────────────────────────────────────┤ │
│  │                                                                              │ │
│  │  ✅ AI Recommendation                                                        │ │
│  │     [REQUEST RESUBMISSION]                                                   │ │
│  │                                                                              │ │
│  │  Reasoning:                                                                  │ │
│  │  The submission has 2 high-priority issues that need to be addressed.       │ │
│  │  While the overall confidence is good (87.5%), the date and vendor          │ │
│  │  discrepancies require clarification before approval.                       │ │
│  │                                                                              │ │
│  │  High Priority Issues:                                                       │ │
│  │  ⚠️ Date Validation                                                          │ │
│  │     Invoice date (2026-02-10) is before PO date (2026-02-15)                │ │
│  │     → Verify invoice date with agency and request correction                │ │
│  │                                                                              │ │
│  │  ⚠️ Vendor Validation                                                        │ │
│  │     Vendor name mismatch: "ABC Corp" (PO) vs "ABC Corporation" (Invoice)    │ │
│  │     → Confirm vendor name consistency or update master data                 │ │
│  │                                                                              │ │
│  ├──────────────────────────────────────────────────────────────────────────────┤ │
│  │                                                                              │ │
│  │  📄 Detailed AI Analysis                                              ▼     │ │
│  │     (Click to expand full AI-generated report)                               │ │
│  │                                                                              │ │
│  └──────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                    │
└────────────────────────────────────────────────────────────────────────────────────┘
```

## Color Coding

### Confidence Scores
- **Green (≥85%)**: ✅ Ready for approval
- **Orange (70-85%)**: ⚠️ Request resubmission
- **Red (<70%)**: ❌ Reject

### Risk Levels
- **Low Risk**: Green badge
- **Medium Risk**: Orange badge
- **High Risk**: Red badge
- **Critical Risk**: Dark red badge

### Severity Levels
- **Critical**: Red with ❌ icon
- **High**: Orange with ⚠️ icon
- **Medium**: Amber with ⚠️ icon
- **Low**: Blue with ℹ️ icon

## User Interactions

### 1. Click "View AI Report" Button
- Opens full-screen dialog
- Shows loading spinner while fetching data
- Displays validation report when loaded

### 2. Expand Validation Category
- Click on any validation category card
- Shows detailed information:
  - Description
  - Expected vs Actual values
  - Impact
  - Suggested action

### 3. Refresh Report
- Click refresh button in dialog header
- Reloads validation report from API
- Shows loading state during refresh

### 4. View Detailed Evidence
- Click "Detailed AI Analysis" section
- Expands to show full AI-generated text
- Text is selectable for copying

### 5. Close Dialog
- Click ✕ button in header
- Click outside dialog (optional)
- Returns to review dashboard

## Mobile Responsiveness

### Portrait Mode
- Full-width dialog (90% of screen)
- Stacked layout for all sections
- Scrollable content
- Touch-friendly buttons (48×48 minimum)

### Landscape Mode
- Wider dialog
- Side-by-side layout where appropriate
- Optimized for tablet viewing

## Accessibility

- ✅ Semantic labels for screen readers
- ✅ Keyboard navigation support
- ✅ High contrast colors (WCAG AA)
- ✅ Touch targets ≥48×48 pixels
- ✅ Clear visual hierarchy
- ✅ Descriptive button labels

## Performance

- ✅ Lazy loading of validation report
- ✅ Caching with Riverpod
- ✅ Optimized rendering
- ✅ Smooth animations
- ✅ Fast dialog open/close

## Summary

The Enhanced Validation Report button is now prominently displayed on both ASM and HQ review pages, providing easy access to detailed AI-generated validation reports. The visual design is clean, professional, and follows Bajaj's brand colors.
