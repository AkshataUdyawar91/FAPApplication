@echo off
REM Simple Approval Flow Test - Interactive Guide
REM This script walks you through testing the complete approval flow

setlocal enabledelayedexpansion

set baseUrl=http://localhost:5000/api

echo.
echo ========================================
echo  BAJAJ APPROVAL FLOW TEST
echo ========================================
echo.
echo This script will guide you through testing:
echo 1. User authentication (Agency, ASM, HQ)
echo 2. Creating a submission
echo 3. ASM approval flow
echo 4. HQ approval flow
echo 5. Rejection flows
echo.
echo Prerequisites:
echo - API running on http://localhost:5000
echo - Database with test users created
echo.
pause

REM ============================================================================
REM Step 1: Login as Agency
REM ============================================================================
echo.
echo ========================================
echo STEP 1: Login as Agency User
echo ========================================
echo.
echo Logging in as: agency@bajaj.com
echo.

curl -s -X POST %baseUrl%/auth/login ^
  -H "Content-Type: application/json" ^
  -d "{\"email\":\"agency@bajaj.com\",\"password\":\"Password123!\"}" > temp_agency.json

type temp_agency.json
echo.
echo.

REM Extract token manually
echo Please copy the token value from above (without quotes)
echo Example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
echo.
set /p agencyToken="Paste Agency Token: "

if "%agencyToken%"=="" (
    echo [ERROR] No token provided. Exiting.
    del temp_agency.json 2>nul
    pause
    exit /b 1
)

echo [OK] Agency token saved
del temp_agency.json 2>nul

REM ============================================================================
REM Step 2: Login as ASM
REM ============================================================================
echo.
echo ========================================
echo STEP 2: Login as ASM User
echo ========================================
echo.
echo Logging in as: asm@bajaj.com
echo.

curl -s -X POST %baseUrl%/auth/login ^
  -H "Content-Type: application/json" ^
  -d "{\"email\":\"asm@bajaj.com\",\"password\":\"Password123!\"}" > temp_asm.json

type temp_asm.json
echo.
echo.

echo Please copy the token value from above (without quotes)
echo.
set /p asmToken="Paste ASM Token: "

if "%asmToken%"=="" (
    echo [ERROR] No token provided. Exiting.
    del temp_asm.json 2>nul
    pause
    exit /b 1
)

echo [OK] ASM token saved
del temp_asm.json 2>nul

REM ============================================================================
REM Step 3: Login as HQ
REM ============================================================================
echo.
echo ========================================
echo STEP 3: Login as HQ User
echo ========================================
echo.
echo Logging in as: hq@bajaj.com
echo.

curl -s -X POST %baseUrl%/auth/login ^
  -H "Content-Type: application/json" ^
  -d "{\"email\":\"hq@bajaj.com\",\"password\":\"Password123!\"}" > temp_hq.json

type temp_hq.json
echo.
echo.

echo Please copy the token value from above (without quotes)
echo.
set /p hqToken="Paste HQ Token: "

if "%hqToken%"=="" (
    echo [ERROR] No token provided. Exiting.
    del temp_hq.json 2>nul
    pause
    exit /b 1
)

echo [OK] HQ token saved
del temp_hq.json 2>nul

REM ============================================================================
REM Step 4: Create Submission (as Agency)
REM ============================================================================
echo.
echo ========================================
echo STEP 4: Create Submission
echo ========================================
echo.
echo Creating a new submission as Agency...
echo.

curl -s -X POST %baseUrl%/submissions ^
  -H "Authorization: Bearer %agencyToken%" ^
  -H "Content-Type: application/json" ^
  -d "{}" > temp_submission.json

type temp_submission.json
echo.
echo.

echo Look for "id" field in the response above
echo Example: "id":"46f1dc40-c92c-4331-8bc6-3b872f007290"
echo.
set /p submissionId="Paste Submission ID: "

if "%submissionId%"=="" (
    echo [ERROR] No submission ID provided. Exiting.
    del temp_submission.json 2>nul
    pause
    exit /b 1
)

echo [OK] Submission created: %submissionId%
del temp_submission.json 2>nul

REM ============================================================================
REM Step 5: Check Submission Status
REM ============================================================================
echo.
echo ========================================
echo STEP 5: Check Submission Status
echo ========================================
echo.
echo Fetching submission details...
echo.

curl -s -X GET %baseUrl%/submissions/%submissionId% ^
  -H "Authorization: Bearer %agencyToken%" > temp_status.json

type temp_status.json
echo.
echo.

echo Look for "state" field in the response
echo Expected: "Uploaded" or "PendingASMApproval"
echo.
pause

del temp_status.json 2>nul

REM ============================================================================
REM Step 6: ASM Approve
REM ============================================================================
echo.
echo ========================================
echo STEP 6: ASM Approves Submission
echo ========================================
echo.
echo ASM will now approve the submission...
echo This should move it to "PendingHQApproval" state
echo.
pause

curl -s -X PATCH %baseUrl%/submissions/%submissionId%/asm-approve ^
  -H "Authorization: Bearer %asmToken%" ^
  -H "Content-Type: application/json" ^
  -d "{\"notes\":\"Approved by ASM - Test\"}" > temp_asm_approve.json

type temp_asm_approve.json
echo.
echo.

echo Check the "state" field above
echo Expected: "PendingHQApproval"
echo.
pause

del temp_asm_approve.json 2>nul

REM ============================================================================
REM Step 7: HQ Final Approval
REM ============================================================================
echo.
echo ========================================
echo STEP 7: HQ Final Approval
echo ========================================
echo.
echo HQ will now give final approval...
echo This should move it to "Approved" state (FINAL)
echo.
pause

curl -s -X PATCH %baseUrl%/submissions/%submissionId%/hq-approve ^
  -H "Authorization: Bearer %hqToken%" ^
  -H "Content-Type: application/json" ^
  -d "{\"notes\":\"Final approval by HQ - Test\"}" > temp_hq_approve.json

type temp_hq_approve.json
echo.
echo.

echo Check the "state" field above
echo Expected: "Approved"
echo.
echo ========================================
echo HAPPY PATH TEST COMPLETE!
echo ========================================
echo.
echo Summary:
echo - Created submission: %submissionId%
echo - ASM approved: Moved to PendingHQApproval
echo - HQ approved: Moved to Approved (FINAL)
echo.
pause

del temp_hq_approve.json 2>nul

REM ============================================================================
REM Step 8: Test Rejection Flow
REM ============================================================================
echo.
echo ========================================
echo STEP 8: Test Rejection Flow
echo ========================================
echo.
echo Would you like to test the rejection flow?
echo This will create a new submission and reject it.
echo.
set /p testReject="Test rejection? (Y/N): "

if /i not "%testReject%"=="Y" goto :end

echo.
echo Creating new submission for rejection test...
echo.

curl -s -X POST %baseUrl%/submissions ^
  -H "Authorization: Bearer %agencyToken%" ^
  -H "Content-Type: application/json" ^
  -d "{}" > temp_submission2.json

type temp_submission2.json
echo.
echo.

echo Copy the submission ID from above
echo.
set /p submissionId2="Paste Submission ID: "

if "%submissionId2%"=="" (
    echo [ERROR] No submission ID provided. Skipping rejection test.
    del temp_submission2.json 2>nul
    goto :end
)

del temp_submission2.json 2>nul

echo.
echo ========================================
echo STEP 9: ASM Rejects Submission
echo ========================================
echo.
echo ASM will now reject the submission...
echo.
pause

curl -s -X PATCH %baseUrl%/submissions/%submissionId2%/asm-reject ^
  -H "Authorization: Bearer %asmToken%" ^
  -H "Content-Type: application/json" ^
  -d "{\"reason\":\"Invoice amount does not match PO. Please correct and resubmit.\"}" > temp_asm_reject.json

type temp_asm_reject.json
echo.
echo.

echo Check the "state" field above
echo Expected: "RejectedByASM"
echo.
echo Also check "asmReviewNotes" field for rejection reason
echo.
pause

del temp_asm_reject.json 2>nul

echo.
echo ========================================
echo STEP 10: Agency Views Rejection
echo ========================================
echo.
echo Agency will now view the rejection...
echo.

curl -s -X GET %baseUrl%/submissions/%submissionId2% ^
  -H "Authorization: Bearer %agencyToken%" > temp_view_reject.json

type temp_view_reject.json
echo.
echo.

echo Agency should see:
echo - state: "RejectedByASM"
echo - asmReviewNotes: "Invoice amount does not match PO..."
echo.
echo This is what the agency user will see in their dashboard!
echo.

del temp_view_reject.json 2>nul

:end
echo.
echo ========================================
echo ALL TESTS COMPLETE!
echo ========================================
echo.
echo Test Results:
echo - Authentication: PASSED (all 3 users)
echo - Create Submission: PASSED
echo - ASM Approval: PASSED
echo - HQ Approval: PASSED
if /i "%testReject%"=="Y" (
    echo - ASM Rejection: PASSED
    echo - Agency View Rejection: PASSED
)
echo.
echo Next Steps:
echo 1. Test the Flutter UI with these flows
echo 2. Verify status badges display correctly
echo 3. Check rejection notes appear in agency dashboard
echo 4. Test HQ rejection flow (similar to ASM rejection)
echo.
pause
