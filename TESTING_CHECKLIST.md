# Testing Checklist - Download & Chat Features

## Prerequisites
1. Ensure backend API is running on `http://localhost:5000`
2. Ensure database has test data with documents
3. Run Flutter app: `flutter run -d chrome` (from frontend directory)

## Test Scenarios

### 1. Agency User - Download Documents

**Login as Agency User**
- Email: `agency@bajaj.com`
- Password: `Password123!`

**Steps:**
1. ✅ Login to agency dashboard
2. ✅ Click "View" button on any submission
3. ✅ Verify submission detail page loads with all documents
4. ✅ Click download icon next to PO document
   - Expected: Document opens in new browser tab
   - Expected: Success message appears
5. ✅ Click download icon next to Invoice document
   - Expected: Document opens in new browser tab
6. ✅ Click download icon next to Cost Summary document
   - Expected: Document opens in new browser tab
7. ✅ Expand Photos section and verify photos are displayed
8. ✅ Test with submission that has no documents
   - Expected: Error message "Document URL not available"

**Chat Bot Test:**
1. ✅ Verify chat panel toggle button exists on dashboard
2. ✅ Click chat toggle button
3. ✅ Verify chat panel opens
4. ✅ Send a test message
5. ✅ Verify AI responds

---

### 2. ASM User - Download Documents & Chat

**Login as ASM User**
- Email: `asm@bajaj.com`
- Password: `Password123!`

**Steps:**
1. ✅ Login to ASM review page
2. ✅ Verify floating chat button (FAB) appears in bottom-right corner
3. ✅ Click on any submission to open detail page
4. ✅ Verify all documents are displayed with download buttons
5. ✅ Click "Download" button next to PO document
   - Expected: Document opens in new tab
   - Expected: Success message appears
6. ✅ Click "Download" button next to Invoice document
7. ✅ Click "Download" button next to Cost Summary document
8. ✅ Scroll to Photos section
9. ✅ Click "Download All" button for photos (if available)
10. ✅ Go back to review list page
11. ✅ Click floating chat button (FAB)
    - Expected: Navigates to chat page
12. ✅ Send a test message in chat
    - Expected: AI responds
13. ✅ Navigate back to review page
    - Expected: Chat FAB still visible

---

### 3. HQ User - Download Documents & Chat

**Login as HQ User**
- Email: `hq@bajaj.com`
- Password: `Password123!`

**Steps:**
1. ✅ Login to HQ review page
2. ✅ Verify floating chat button (FAB) appears in bottom-right corner
3. ✅ Click on any submission to open detail page
4. ✅ Verify all documents are displayed with download buttons
5. ✅ Click "Download" button next to PO document
   - Expected: Document opens in new tab
   - Expected: Success message appears
6. ✅ Click "Download" button next to Invoice document
7. ✅ Click "Download" button next to Cost Summary document
8. ✅ Verify ASM review notes section is displayed (if ASM approved)
9. ✅ Go back to review list page
10. ✅ Click floating chat button (FAB)
    - Expected: Navigates to chat page
11. ✅ Send a test message in chat
    - Expected: AI responds
12. ✅ Navigate back to review page
    - Expected: Chat FAB still visible

---

## Error Handling Tests

### Download Errors
1. ✅ Test with document that has null/empty blobUrl
   - Expected: Orange snackbar with "Document URL not available"
2. ✅ Test with invalid blobUrl
   - Expected: Red snackbar with error message
3. ✅ Test network failure during download
   - Expected: Appropriate error message

### Chat Errors
1. ✅ Test chat without network connection
   - Expected: Error message displayed
2. ✅ Test chat with invalid token
   - Expected: Authentication error
3. ✅ Test sending empty message
   - Expected: Message not sent

---

## Cross-Browser Testing

### Chrome
- ✅ Download functionality works
- ✅ Chat FAB appears correctly
- ✅ Documents open in new tab

### Firefox
- ✅ Download functionality works
- ✅ Chat FAB appears correctly
- ✅ Documents open in new tab

### Edge
- ✅ Download functionality works
- ✅ Chat FAB appears correctly
- ✅ Documents open in new tab

---

## UI/UX Verification

### Download Buttons
- ✅ Download icon is visible and clear
- ✅ Tooltip shows "Download" on hover
- ✅ Button is properly aligned with document info
- ✅ Success message is clear and visible
- ✅ Error messages are clear and actionable

### Chat FAB
- ✅ FAB is visible in bottom-right corner
- ✅ FAB doesn't overlap with other UI elements
- ✅ FAB icon is clear (chat bubble)
- ✅ FAB label says "AI Assistant"
- ✅ FAB color matches app theme (primary blue)
- ✅ FAB has proper elevation/shadow
- ✅ Clicking FAB navigates to chat page smoothly

### Chat Page
- ✅ Chat page loads correctly
- ✅ Previous messages are displayed (if any)
- ✅ Input field is functional
- ✅ Send button works
- ✅ Messages are displayed in correct order
- ✅ Loading indicator shows while AI is responding
- ✅ Back button returns to previous page

---

## Performance Tests

1. ✅ Download large PDF (>5MB)
   - Expected: Opens without freezing UI
2. ✅ Download multiple documents quickly
   - Expected: All open successfully
3. ✅ Chat with long conversation history
   - Expected: Loads and scrolls smoothly
4. ✅ Send multiple chat messages rapidly
   - Expected: All messages processed correctly

---

## Accessibility Tests

1. ✅ Download buttons are keyboard accessible (Tab + Enter)
2. ✅ Chat FAB is keyboard accessible
3. ✅ Screen reader announces download actions
4. ✅ Screen reader announces chat FAB
5. ✅ Color contrast is sufficient for all buttons
6. ✅ Focus indicators are visible

---

## Known Limitations

1. **Web Only**: `dart:html` import only works for web platform
   - For mobile apps, would need to use `url_launcher` package
2. **Download Behavior**: Opens in new tab rather than forcing download
   - Browser settings control actual download behavior
3. **Chat Context**: Chat page doesn't maintain context when navigating away
   - This is expected behavior based on current implementation

---

## Success Criteria

✅ All personas can download documents from their respective pages
✅ All personas can access chat bot functionality
✅ Download buttons are functional and provide user feedback
✅ Chat FAB is visible and accessible on ASM and HQ pages
✅ Error handling works correctly for edge cases
✅ UI is consistent across all pages
✅ No console errors or warnings

---

## Rollback Plan

If issues are found:
1. Revert changes to the 6 modified files
2. Remove chat route from main.dart
3. Remove ChatFAB imports from ASM and HQ pages
4. Remove download method implementations
5. Test that app still functions without new features
