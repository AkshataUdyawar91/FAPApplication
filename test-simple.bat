@echo off
REM Simple Approval Flow Test - Shows actual API responses

set baseUrl=http://localhost:5000/api

echo.
echo ========================================
echo  SIMPLE APPROVAL FLOW TEST
echo ========================================
echo.

REM Check if API is running
echo Checking API...
curl -s %baseUrl%/health
if errorlevel 1 (
    echo ERROR: API is not running
    pause
    exit /b 1
)
echo.

REM ============================================================================
REM Test 1: Login as Agency
REM ============================================================================
echo ========================================
echo Test 1: Login as Agency
echo ========================================
echo.

curl -X POST %baseUrl%/auth/login ^
  -H "Content-Type: application/json" ^
  -d "{\"email\":\"agency@bajaj.com\",\"password\":\"Password123!\"}"

echo.
echo.
echo Copy the token from above and paste it here:
set /p agencyToken="Agency Token: "

if "%agencyToken%"=="" (
    echo No token provided. Exiting.
    pause
    exit /b 1
)

echo.
echo ========================================
echo Test 2: Login as ASM
echo ========================================
echo.

curl -X POST %baseUrl%/auth/login ^
  -H "Content-Type: application/json" ^
  -d "{\"email\":\"asm@bajaj.com\",\"password\":\"Password123!\"}"

echo.
echo.
echo Copy the token from above and paste it here:
set /p asmToken="ASM Token: "

if "%asmToken%"=="" (
    echo No token provided. Exiting.
    pause
    exit /b 1
)

echo.
echo ========================================
echo Test 3: Login as HQ
echo ========================================
echo.

curl -X POST %baseUrl%/auth/login ^
  -H "Content-Type: application/json" ^
  -d "{\"email\":\"hq@bajaj.com\",\"password\":\"Password123!\"}"

echo.
echo.
echo Copy the token from above and paste it here:
set /p hqToken="HQ Token: "

if "%hqToken%"=="" (
    echo No token provided. Exiting.
    pause
    exit /b 1
)

echo.
echo ========================================
echo Test 4: Create Submission
echo ========================================
echo.

curl -X POST %baseUrl%/submissions ^
  -H "Authorization: Bearer %agencyToken%" ^
  -H "Content-Type: application/json" ^
  -d "{}"

echo.
echo.
echo Copy the submission ID from above and paste it here:
set /p packageId="Package ID: "

if "%packageId%"=="" (
    echo No package ID provided. Exiting.
    pause
    exit /b 1
)

echo.
echo ========================================
echo Test 5: ASM Approve Submission
echo ========================================
echo.

curl -X PATCH %baseUrl%/submissions/%packageId%/asm-approve ^
  -H "Authorization: Bearer %asmToken%" ^
  -H "Content-Type: application/json" ^
  -d "{\"notes\":\"Approved by ASM for testing\"}"

echo.
echo.
echo Should show state: PendingHQApproval
pause

echo.
echo ========================================
echo Test 6: HQ Final Approval
echo ========================================
echo.

curl -X PATCH %baseUrl%/submissions/%packageId%/hq-approve ^
  -H "Authorization: Bearer %hqToken%" ^
  -H "Content-Type: application/json" ^
  -d "{\"notes\":\"Final approval by HQ\"}"

echo.
echo.
echo Should show state: Approved
echo.
echo ========================================
echo Test 7: Create Another Submission for Rejection Test
echo ========================================
echo.

curl -X POST %baseUrl%/submissions ^
  -H "Authorization: Bearer %agencyToken%" ^
  -H "Content-Type: application/json" ^
  -d "{}"

echo.
echo.
echo Copy the submission ID from above:
set /p packageId2="Package ID: "

if "%packageId2%"=="" (
    echo No package ID provided. Skipping rejection test.
    goto :end
)

echo.
echo ========================================
echo Test 8: ASM Reject Submission
echo ========================================
echo.

curl -X PATCH %baseUrl%/submissions/%packageId2%/asm-reject ^
  -H "Authorization: Bearer %asmToken%" ^
  -H "Content-Type: application/json" ^
  -d "{\"reason\":\"Invoice amount does not match PO. Please correct and resubmit.\"}"

echo.
echo.
echo Should show state: RejectedByASM
echo.

echo.
echo ========================================
echo Test 9: Agency Views Rejection
echo ========================================
echo.

curl -X GET %baseUrl%/submissions/%packageId2% ^
  -H "Authorization: Bearer %agencyToken%"

echo.
echo.
echo Should show rejection notes from ASM
echo.

:end
echo.
echo ========================================
echo ALL TESTS COMPLETE
echo ========================================
echo.
echo Summary:
echo - Test 1-3: User authentication
echo - Test 4: Create submission
echo - Test 5: ASM approval
echo - Test 6: HQ final approval
echo - Test 7: Create submission for rejection
echo - Test 8: ASM rejection
echo - Test 9: Agency views rejection
echo.
pause
