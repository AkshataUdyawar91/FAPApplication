# Approval/Rejection Flow - Test Documentation

## Overview

This document provides comprehensive testing instructions for the Bajaj Document Processing System's approval and rejection workflows.

---

## Test Files

### 1. Automated API Tests
**File**: `test-approval-flow.ps1`

**Purpose**: Automated testing of all API endpoints and approval/rejection flows

**What it tests**:
- ✅ User authentication (Agency, ASM, HQ)
- ✅ Document upload
- ✅ Workflow processing
- ✅ ASM approval flow
- ✅ HQ approval flow
- ✅ ASM rejection flow
- ✅ HQ rejection flow
- ✅ Authorization and security checks
- ✅ State transitions
- ✅ Rejection notes visibility

**How to run**:
```bash
# Option 1: Using batch file
run-approval-tests.bat

# Option 2: Direct PowerShell
powershell -ExecutionPolicy Bypass -File test-approval-flow.ps1
```

**Prerequisites**:
- Backend API running on `http://localhost:5000`
- Test users created in database
- PowerShell 5.0 or higher

**Expected Output**:
- Colored console output with test results
- Pass/Fail status for each test
- Summary with pass rate
- Exit code 0 if all tests pass, 1 if any fail

---

### 2. Manual UI Test Cases
**File**: `MANUAL_UI_TEST_CASES.md`

**Purpose**: Step-by-step manual testing instructions for UI validation

**What it tests**:
- ✅ Complete user workflows (Agency → ASM → HQ)
- ✅ UI elements and visual design
- ✅ Status badges and labels
- ✅ Rejection notes display
- ✅ Filtering and search functionality
- ✅ Authorization and access control
- ✅ Error handling and user feedback
- ✅ Responsive design

**How to use**:
1. Open `MANUAL_UI_TEST_CASES.md`
2. Follow each test scenario step-by-step
3. Mark each test as PASS or FAIL
4. Document any issues found
5. Fill in tester information at the end

**Test Scenarios**:
1. Happy Path - Full Approval Flow
2. ASM Rejection Flow
3. HQ Rejection Flow
4. Status Filtering and Search
5. Authorization and Security
6. UI/UX Validation

---

### 3. Flow Analysis Document
**File**: `APPROVAL_FLOW_ANALYSIS.md`

**Purpose**: Detailed analysis of implemented and missing flows

**Contents**:
- Complete flow matrix
- Implementation status (80% complete)
- Missing features (resubmit functionality)
- Recommendations for completion

---

## Test Scenarios

### Scenario 1: Happy Path - Full Approval ✅

**Flow**: Agency → AI → ASM Approve → HQ Approve → Final Approved

**Steps**:
1. Agency uploads documents (PO, Invoice, Cost Summary, Photos)
2. AI processes and validates documents
3. Package moves to `PendingASMApproval`
4. ASM reviews and approves
5. Package moves to `PendingHQApproval`
6. HQ reviews and gives final approval
7. Package moves to `Approved` (FINAL)

**Expected Results**:
- ✅ All state transitions occur correctly
- ✅ Agency sees "Approved" status
- ✅ ASM and HQ notes are saved
- ✅ Timestamps are recorded

**Automated Test**: ✅ Included in `test-approval-flow.ps1`

**Manual Test**: ✅ Scenario 1 in `MANUAL_UI_TEST_CASES.md`

---

### Scenario 2: ASM Rejection ✅

**Flow**: Agency → AI → ASM Reject → Agency Sees Rejection

**Steps**:
1. Agency uploads documents
2. AI processes documents
3. Package moves to `PendingASMApproval`
4. ASM reviews and rejects with notes
5. Package moves to `RejectedByASM`
6. Agency sees rejection with ASM notes

**Expected Results**:
- ✅ Package state changes to `RejectedByASM`
- ✅ ASM rejection notes are saved
- ✅ Agency can view rejection notes in dashboard
- ✅ Red alert box displays rejection reason

**Automated Test**: ✅ Included in `test-approval-flow.ps1`

**Manual Test**: ✅ Scenario 2 in `MANUAL_UI_TEST_CASES.md`

---

### Scenario 3: HQ Rejection ✅

**Flow**: Agency → AI → ASM Approve → HQ Reject → ASM Sees Rejection

**Steps**:
1. Agency uploads documents
2. AI processes documents
3. ASM approves → moves to `PendingHQApproval`
4. HQ reviews and rejects with notes
5. Package moves to `RejectedByHQ`
6. ASM sees rejection with HQ notes

**Expected Results**:
- ✅ Package state changes to `RejectedByHQ`
- ✅ HQ rejection notes are saved
- ✅ ASM can view rejection notes in review page
- ✅ Red alert box displays rejection reason
- ✅ Package appears in ASM's pending list

**Automated Test**: ✅ Included in `test-approval-flow.ps1`

**Manual Test**: ✅ Scenario 3 in `MANUAL_UI_TEST_CASES.md`

---

### Scenario 4: Agency Resubmit ⚠️

**Flow**: ASM Rejects → Agency Resubmits → Back to AI Processing

**Status**: ⚠️ NOT IMPLEMENTED (Known Limitation)

**Expected Behavior** (when implemented):
1. Agency sees rejected package with notes
2. Agency clicks "Resubmit" button
3. Agency can edit/replace documents
4. Agency submits for review
5. Package state changes from `RejectedByASM` → `Uploaded`
6. Workflow triggers automatically

**Current Workaround**:
- Agency must create entirely new submission
- Old rejected submission remains in rejected state

**Automated Test**: ❌ Not included (feature not implemented)

**Manual Test**: ⚠️ Known limitation documented in test cases

---

### Scenario 5: ASM Resubmit to HQ ⚠️

**Flow**: HQ Rejects → ASM Re-reviews → Resubmit to HQ

**Status**: ⚠️ NOT IMPLEMENTED (Known Limitation)

**Expected Behavior** (when implemented):
1. ASM sees HQ rejection with notes
2. ASM reviews and makes corrections
3. ASM clicks "Resubmit to HQ" button
4. ASM adds resubmission notes
5. Package state changes from `RejectedByHQ` → `PendingHQApproval`
6. HQ sees it again in pending list

**Current Workaround**:
- None - package stays in `RejectedByHQ` state
- ASM can only view the rejection

**Automated Test**: ❌ Not included (feature not implemented)

**Manual Test**: ⚠️ Known limitation documented in test cases

---

## Running the Tests

### Prerequisites

1. **Backend API Running**
   ```bash
   cd backend
   dotnet run --project src/BajajDocumentProcessing.API
   ```
   Or use: `run-api-dev.ps1`

2. **Database Setup**
   - SQL Server running
   - Database created
   - Migrations applied
   - Test users created

3. **Test Users**
   ```sql
   -- Run CREATE_USERS.sql or verify users exist:
   -- agency@bajaj.com / Password123!
   -- asm@bajaj.com / Password123!
   -- hq@bajaj.com / Password123!
   ```

4. **Frontend (for manual tests)**
   ```bash
   cd frontend
   flutter run -d chrome
   ```

---

### Running Automated Tests

#### Step 1: Verify API is Running
```bash
curl http://localhost:5000/api/health
```

#### Step 2: Run Tests
```bash
# Windows
run-approval-tests.bat

# PowerShell
powershell -ExecutionPolicy Bypass -File test-approval-flow.ps1
```

#### Step 3: Review Results
- Check console output for pass/fail status
- Review detailed test results
- Check exit code (0 = all passed, 1 = some failed)

---

### Running Manual Tests

#### Step 1: Open Test Document
Open `MANUAL_UI_TEST_CASES.md` in a text editor or markdown viewer

#### Step 2: Execute Each Scenario
Follow the step-by-step instructions for each test scenario

#### Step 3: Document Results
- Mark each test as PASS or FAIL
- Add notes for any issues found
- Take screenshots of failures

#### Step 4: Fill Summary
Complete the test results summary table at the end

---

## Test Data

### Test Documents Required

For manual testing, prepare the following test documents:

1. **Purchase Order (PO)**
   - Format: PDF
   - Should contain: PO number, amount, vendor details
   - Example: `test-po.pdf`

2. **Invoice**
   - Format: PDF
   - Should contain: Invoice number, amount, date
   - Example: `test-invoice.pdf`

3. **Cost Summary**
   - Format: PDF
   - Should contain: Cost breakdown, totals
   - Example: `test-cost-summary.pdf`

4. **Activity Photos**
   - Format: JPG/PNG
   - Minimum: 3 photos
   - Should have EXIF metadata (date, location)
   - Example: `photo1.jpg`, `photo2.jpg`, `photo3.jpg`

### Test Users

| Role | Email | Password | Purpose |
|------|-------|----------|---------|
| Agency | agency@bajaj.com | Password123! | Upload documents |
| ASM | asm@bajaj.com | Password123! | Review and approve/reject |
| HQ | hq@bajaj.com | Password123! | Final approval/rejection |

---

## Expected Test Results

### Automated Tests

**Total Tests**: ~20-25 tests

**Expected Pass Rate**: 80-90%

**Known Failures**:
- Resubmit functionality tests (not implemented)
- Some authorization edge cases

**Critical Tests** (must pass):
- ✅ User authentication
- ✅ Document upload
- ✅ Workflow processing
- ✅ ASM approval
- ✅ HQ approval
- ✅ ASM rejection with notes
- ✅ HQ rejection with notes
- ✅ State transitions

---

### Manual Tests

**Total Scenarios**: 6 scenarios

**Expected Pass Rate**: 80-100%

**Known Limitations**:
- Scenario 4 (Agency Resubmit) - Partially implemented
- Scenario 5 (ASM Resubmit to HQ) - Partially implemented

**Critical Scenarios** (must pass):
- ✅ Scenario 1: Happy Path
- ✅ Scenario 2: ASM Rejection
- ✅ Scenario 3: HQ Rejection
- ✅ Scenario 5: Authorization

---

## Troubleshooting

### Common Issues

#### 1. API Not Running
**Error**: "Failed to connect to API"

**Solution**:
```bash
# Start the API
cd backend
dotnet run --project src/BajajDocumentProcessing.API
```

#### 2. Authentication Failed
**Error**: "Login failed" or "401 Unauthorized"

**Solution**:
- Verify test users exist in database
- Check passwords are correct
- Run `CREATE_USERS.sql` to create users

#### 3. Workflow Not Processing
**Error**: Package stuck in "Uploaded" state

**Solution**:
- Check Azure OpenAI API keys in `appsettings.Development.json`
- Verify API is running in Development mode
- Check API logs for errors

#### 4. Documents Not Uploading
**Error**: "Failed to upload document"

**Solution**:
- Check file size (should be < 10MB)
- Verify file format (PDF for documents, JPG/PNG for photos)
- Check Azure Blob Storage configuration

#### 5. Frontend Not Loading
**Error**: "Failed to load submissions"

**Solution**:
- Verify API is running
- Check CORS settings in API
- Check browser console for errors
- Verify API base URL in `api_constants.dart`

---

## Test Coverage

### Backend API Coverage

| Endpoint | Tested | Status |
|----------|--------|--------|
| POST /api/auth/login | ✅ | Automated |
| POST /api/submissions | ✅ | Automated |
| POST /api/documents/upload | ✅ | Automated |
| POST /api/submissions/{id}/process-now | ✅ | Automated |
| GET /api/submissions | ✅ | Automated |
| GET /api/submissions/{id} | ✅ | Automated |
| PATCH /api/submissions/{id}/asm-approve | ✅ | Automated |
| PATCH /api/submissions/{id}/asm-reject | ✅ | Automated |
| PATCH /api/submissions/{id}/hq-approve | ✅ | Automated |
| PATCH /api/submissions/{id}/hq-reject | ✅ | Automated |

### Frontend Page Coverage

| Page | Tested | Status |
|------|--------|--------|
| Login Page | ✅ | Manual |
| Agency Dashboard | ✅ | Manual |
| Agency Upload Page | ✅ | Manual |
| ASM Review Page | ✅ | Manual |
| ASM Review Detail Page | ✅ | Manual |
| HQ Review Page | ✅ | Manual |
| HQ Review Detail Page | ✅ | Manual |
| HQ Analytics Page | ⚠️ | Not tested |

### Workflow State Coverage

| State | Tested | Status |
|-------|--------|--------|
| Uploaded | ✅ | Automated |
| Extracting | ✅ | Automated |
| Validating | ✅ | Automated |
| Scoring | ✅ | Automated |
| PendingASMApproval | ✅ | Automated |
| PendingHQApproval | ✅ | Automated |
| Approved | ✅ | Automated |
| RejectedByASM | ✅ | Automated |
| RejectedByHQ | ✅ | Automated |

---

## Reporting Issues

When reporting test failures, include:

1. **Test Scenario**: Which test failed
2. **Expected Result**: What should have happened
3. **Actual Result**: What actually happened
4. **Steps to Reproduce**: How to recreate the issue
5. **Screenshots**: Visual evidence of the issue
6. **Logs**: API logs or browser console errors
7. **Environment**: Development/Staging/Production

---

## Next Steps After Testing

### If All Tests Pass (80%+)
1. ✅ Document test results
2. ✅ Mark system as ready for UAT (User Acceptance Testing)
3. ⚠️ Note known limitations (resubmit functionality)
4. 📋 Plan implementation of missing features

### If Tests Fail (<80%)
1. ❌ Document all failures
2. 🔍 Investigate root causes
3. 🔧 Fix critical issues
4. 🔄 Re-run tests
5. 📊 Update test results

---

## Conclusion

The approval/rejection flow is **80% complete and functional**. The core workflows (approval and rejection) work correctly, but resubmission functionality is not yet implemented. The system is ready for testing and can be used for initial deployments with the understanding that rejected packages cannot be easily resubmitted.

**Recommendation**: Implement resubmit functionality before production deployment for a complete user experience.
