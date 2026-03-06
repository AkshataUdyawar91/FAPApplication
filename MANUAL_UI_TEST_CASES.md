# Manual UI Test Cases - Approval/Rejection Flow

## Test Environment Setup

### Prerequisites
- ✅ Backend API running on `http://localhost:5000`
- ✅ Frontend Flutter app running on Chrome
- ✅ Test users created in database:
  - Agency: `agency@bajaj.com` / `Password123!`
  - ASM: `asm@bajaj.com` / `Password123!`
  - HQ: `hq@bajaj.com` / `Password123!`
- ✅ Test documents ready (PO, Invoice, Cost Summary, Photos)

---

## Test Scenario 1: Happy Path - Full Approval Flow

### Objective
Verify that a submission can go through the complete approval process from Agency → ASM → HQ → Final Approved.

### Test Steps

#### Part 1: Agency Uploads Documents

1. **Login as Agency**
   - Navigate to login page
   - Enter: `agency@bajaj.com` / `Password123!`
   - Click "Login"
   - **Expected**: Redirected to Agency Dashboard

2. **Navigate to Upload Page**
   - Click "Upload" in sidebar or "Create New Request" button
   - **Expected**: Upload page displayed

3. **Upload Documents**
   - Click "Select PO Document" → Choose PO PDF
   - Click "Select Invoice Document" → Choose Invoice PDF
   - Click "Select Cost Summary Document" → Choose Cost Summary PDF
   - Click "Add Photos" → Choose 3-5 photos
   - **Expected**: All documents show as uploaded with green checkmarks

4. **Submit Package**
   - Click "Submit for Review" button
   - **Expected**: 
     - Success message displayed
     - Redirected to dashboard
     - New submission appears with "Processing" status

5. **Wait for AI Processing**
   - Refresh dashboard after 30-60 seconds
   - **Expected**: Status changes to "Pending ASM Approval"

6. **Verify Submission Details**
   - Click on the submission row
   - **Expected**: 
     - Detail dialog shows submission info
     - Status: "Pending ASM Approval"
     - Document count: 4+ files
     - No rejection notes visible

7. **Logout**
   - Click logout button
   - **Expected**: Redirected to login page

---

#### Part 2: ASM Reviews and Approves

8. **Login as ASM**
   - Enter: `asm@bajaj.com` / `Password123!`
   - Click "Login"
   - **Expected**: Redirected to ASM Review Page

9. **Verify Pending List**
   - Check "Pending ASM Review" count
   - **Expected**: Count shows at least 1
   - **Expected**: Submission from Agency appears in list

10. **Open Submission Detail**
    - Click on the submission row
    - **Expected**: Navigated to ASM Review Detail Page

11. **Review AI Analysis**
    - Scroll through the page
    - **Expected**: See the following sections:
      - AI Quick Summary with confidence score
      - PO details (number, amount)
      - Invoice details (number, amount)
      - Cost Summary details
      - Activity photos with metadata
      - Document-level confidence scores

12. **Approve Submission**
    - Scroll to bottom
    - Enter notes: "All documents verified. Approved for HQ review."
    - Click "Approve" button
    - **Expected**: 
      - Success message: "Approved by ASM, pending HQ approval"
      - Redirected back to ASM Review Page
      - Submission removed from pending list

13. **Logout**
    - Click logout button

---

#### Part 3: HQ Reviews and Gives Final Approval

14. **Login as HQ**
    - Enter: `hq@bajaj.com` / `Password123!`
    - Click "Login"
    - **Expected**: Redirected to HQ Review Page

15. **Verify Pending List**
    - Check "Pending HQ Review" count
    - **Expected**: Count shows at least 1
    - **Expected**: Submission from ASM appears in list

16. **Open Submission Detail**
    - Click on the submission row
    - **Expected**: Navigated to HQ Review Detail Page

17. **Review ASM Decision**
    - Check ASM Review section at top
    - **Expected**: 
      - Shows "Approved by ASM"
      - Shows ASM notes: "All documents verified. Approved for HQ review."
      - Shows ASM review timestamp

18. **Review Complete Package**
    - Scroll through all sections
    - **Expected**: See all document details and AI analysis

19. **Give Final Approval**
    - Scroll to bottom
    - Enter notes: "Final approval granted. All requirements met."
    - Click "Approve" button
    - **Expected**: 
      - Success message: "Final approval by HQ"
      - Redirected back to HQ Review Page
      - Submission removed from pending list

20. **Logout**
    - Click logout button

---

#### Part 4: Agency Sees Final Approval

21. **Login as Agency**
    - Enter: `agency@bajaj.com` / `Password123!`
    - **Expected**: Redirected to Agency Dashboard

22. **Verify Approved Status**
    - Find the submission in dashboard
    - **Expected**: 
      - Status badge shows "Approved" (green)
      - "Approved This Month" count increased by 1

23. **View Approved Details**
    - Click on the submission
    - **Expected**: 
      - Status shows "Approved"
      - No rejection notes
      - Shows submission and approval dates

### Test Result: ✅ PASS / ❌ FAIL

---

## Test Scenario 2: ASM Rejection Flow

### Objective
Verify that ASM can reject a submission and Agency can see the rejection notes.

### Test Steps

#### Part 1: Agency Uploads Documents

1. **Login as Agency** (`agency@bajaj.com`)
2. **Navigate to Upload Page**
3. **Upload Documents** (PO, Invoice, Cost Summary, Photos)
4. **Submit Package**
5. **Wait for AI Processing** (Status → "Pending ASM Approval")
6. **Logout**

---

#### Part 2: ASM Rejects Submission

7. **Login as ASM** (`asm@bajaj.com`)
8. **Open Submission Detail** from pending list
9. **Review Documents**
10. **Reject Submission**
    - Scroll to bottom
    - Enter reason: "Invoice amount does not match PO amount. PO shows ₹50,000 but Invoice shows ₹55,000. Please correct and resubmit."
    - Click "Reject" button
    - **Expected**: 
      - Success message: "Rejected by ASM"
      - Redirected back to ASM Review Page
      - Submission removed from pending list
11. **Logout**

---

#### Part 3: Agency Sees Rejection

12. **Login as Agency** (`agency@bajaj.com`)
13. **Verify Rejected Status**
    - Find the submission in dashboard
    - **Expected**: 
      - Status badge shows "Rejected by ASM" (red)
      - "Rejected" count increased

14. **View Rejection Details**
    - Click on the submission row
    - **Expected**: 
      - Detail dialog opens
      - Red alert box visible with title "Rejected by ASM"
      - Rejection reason displayed: "Invoice amount does not match PO amount..."
      - Shows rejection timestamp

15. **Verify Cannot Resubmit** (Known Limitation)
    - Check for resubmit button
    - **Expected**: No resubmit button available (this is a known missing feature)

### Test Result: ✅ PASS / ❌ FAIL

---

## Test Scenario 3: HQ Rejection Flow

### Objective
Verify that HQ can reject a submission and ASM can see the rejection notes.

### Test Steps

#### Part 1: Agency Uploads and ASM Approves

1. **Login as Agency** (`agency@bajaj.com`)
2. **Upload Documents** and **Submit**
3. **Wait for AI Processing**
4. **Logout**
5. **Login as ASM** (`asm@bajaj.com`)
6. **Approve Submission** with notes: "Approved by ASM"
7. **Logout**

---

#### Part 2: HQ Rejects Submission

8. **Login as HQ** (`hq@bajaj.com`)
9. **Open Submission Detail** from pending list
10. **Review ASM Approval**
    - **Expected**: See ASM approval section with notes
11. **Reject Submission**
    - Scroll to bottom
    - Enter reason: "Cost summary is missing required signatures from department head. Please have ASM verify signatures and resubmit."
    - Click "Reject" button
    - **Expected**: 
      - Success message: "Rejected by HQ, sent back to ASM"
      - Redirected back to HQ Review Page
12. **Logout**

---

#### Part 3: ASM Sees HQ Rejection

13. **Login as ASM** (`asm@bajaj.com`)
14. **Verify Submission in Pending List**
    - **Expected**: Rejected submission appears in pending list
    - **Expected**: "Pending ASM Review" count includes this submission

15. **Open Submission Detail**
    - Click on the submission
    - **Expected**: Navigated to detail page

16. **View HQ Rejection Section**
    - Scroll to find HQ rejection section
    - **Expected**: 
      - Red alert box visible with title "Rejected by HQ"
      - Rejection reason displayed: "Cost summary is missing required signatures..."
      - Shows HQ rejection timestamp
      - Message: "Please review HQ feedback and resubmit if appropriate"

17. **Verify Cannot Resubmit to HQ** (Known Limitation)
    - Check for "Resubmit to HQ" button
    - **Expected**: No resubmit button available (this is a known missing feature)

### Test Result: ✅ PASS / ❌ FAIL

---

## Test Scenario 4: Status Filtering and Search

### Objective
Verify that users can filter and search submissions by status.

### Test Steps

#### Agency Dashboard Filtering

1. **Login as Agency** (`agency@bajaj.com`)
2. **Test Status Filter**
   - Select "All Statuses" → **Expected**: All submissions visible
   - Select "Pending" → **Expected**: Only processing submissions visible
   - Select "Under Review" → **Expected**: Only ASM/HQ pending submissions visible
   - Select "Approved" → **Expected**: Only approved submissions visible
   - Select "Rejected" → **Expected**: Only rejected submissions visible

3. **Test Search**
   - Enter partial submission ID in search box
   - **Expected**: Matching submissions displayed
   - Clear search → **Expected**: All submissions visible again

#### ASM Review Page Filtering

4. **Login as ASM** (`asm@bajaj.com`)
5. **Test Status Filter**
   - Select "All Status" → **Expected**: All submissions visible
   - Select "Pending ASM Review" → **Expected**: Only pending submissions
   - Select "Approved" → **Expected**: Only ASM-approved submissions
   - Select "Rejected" → **Expected**: Only ASM-rejected submissions

6. **Test Search**
   - Enter FAP number in search box
   - **Expected**: Matching submissions displayed

#### HQ Review Page Filtering

7. **Login as HQ** (`hq@bajaj.com`)
8. **Test Status Filter**
   - Select "All Status" → **Expected**: All submissions visible
   - Select "Pending HQ Review" → **Expected**: Only HQ-pending submissions
   - Select "Approved" → **Expected**: Only HQ-approved submissions
   - Select "Rejected" → **Expected**: Only HQ-rejected submissions

### Test Result: ✅ PASS / ❌ FAIL

---

## Test Scenario 5: Authorization and Security

### Objective
Verify that users can only access pages and actions appropriate for their role.

### Test Steps

#### Agency User Restrictions

1. **Login as Agency** (`agency@bajaj.com`)
2. **Try to access ASM page**
   - Manually navigate to `/asm/review` in browser
   - **Expected**: Redirected or access denied
3. **Try to access HQ page**
   - Manually navigate to `/hq/review` in browser
   - **Expected**: Redirected or access denied

#### ASM User Restrictions

4. **Login as ASM** (`asm@bajaj.com`)
5. **Verify Cannot Upload**
   - Check sidebar navigation
   - **Expected**: No "Upload" option visible
6. **Try to access HQ page**
   - Manually navigate to `/hq/review` in browser
   - **Expected**: Redirected or access denied

#### HQ User Restrictions

7. **Login as HQ** (`hq@bajaj.com`)
8. **Verify Cannot Upload**
   - Check sidebar navigation
   - **Expected**: No "Upload" option visible
9. **Verify Cannot Access ASM Actions**
   - Try to access ASM review page
   - **Expected**: Redirected or access denied

### Test Result: ✅ PASS / ❌ FAIL

---

## Test Scenario 6: UI/UX Validation

### Objective
Verify that the UI is user-friendly and displays information correctly.

### Test Steps

#### Visual Elements

1. **Login as any user**
2. **Check Branding**
   - **Expected**: Bajaj logo and colors (#003087, #00A3E0) used consistently
3. **Check Responsive Design**
   - Resize browser window
   - **Expected**: Layout adjusts appropriately
4. **Check Status Badges**
   - **Expected**: 
     - "Approved" = Green
     - "Rejected" = Red
     - "Pending" = Yellow/Orange
     - "Under Review" = Blue

#### Data Display

5. **Check Submission Details**
   - Open any submission detail
   - **Expected**: 
     - FAP number displayed correctly
     - Dates formatted properly (DD/MM/YYYY)
     - Document count accurate
     - Status label matches badge

6. **Check Confidence Scores**
   - Open ASM or HQ review detail page
   - **Expected**: 
     - Overall confidence score displayed (0-100%)
     - Document-level scores displayed
     - Visual indicators (progress bars or colors)

#### Error Handling

7. **Test Network Error**
   - Stop backend API
   - Try to load dashboard
   - **Expected**: 
     - Error message displayed
     - User-friendly message (not technical error)
     - Option to retry

8. **Test Invalid Login**
   - Enter wrong password
   - **Expected**: 
     - Error message: "Invalid credentials"
     - No sensitive information leaked

### Test Result: ✅ PASS / ❌ FAIL

---

## Test Results Summary

| Scenario | Status | Notes |
|----------|--------|-------|
| 1. Happy Path - Full Approval | ⬜ PASS / FAIL | |
| 2. ASM Rejection Flow | ⬜ PASS / FAIL | |
| 3. HQ Rejection Flow | ⬜ PASS / FAIL | |
| 4. Status Filtering and Search | ⬜ PASS / FAIL | |
| 5. Authorization and Security | ⬜ PASS / FAIL | |
| 6. UI/UX Validation | ⬜ PASS / FAIL | |

---

## Known Limitations (Expected Failures)

These are known missing features that should be documented but not considered test failures:

1. ❌ **Agency Cannot Resubmit Rejected Packages**
   - No "Resubmit" button on rejected submissions
   - Agency must create new submission

2. ❌ **ASM Cannot Resubmit to HQ After HQ Rejection**
   - No "Resubmit to HQ" button on HQ-rejected submissions
   - Package stays in `RejectedByHQ` state

3. ❌ **No Resubmission History**
   - Cannot see how many times a package was resubmitted
   - No history of previous rejections

4. ❌ **Cannot Edit Documents in Rejected Package**
   - Cannot replace specific documents
   - Must create entirely new submission

---

## Test Execution Checklist

- [ ] Backend API is running
- [ ] Frontend Flutter app is running
- [ ] Test users are created
- [ ] Test documents are prepared
- [ ] All 6 test scenarios executed
- [ ] Results documented
- [ ] Screenshots captured for failures
- [ ] Known limitations verified

---

## Tester Information

- **Tester Name**: ___________________________
- **Test Date**: ___________________________
- **Environment**: Development / Staging / Production
- **Browser**: Chrome / Edge / Firefox
- **Overall Result**: ⬜ PASS / ⬜ FAIL

---

## Additional Notes

_Use this space to document any additional observations, bugs, or suggestions:_

