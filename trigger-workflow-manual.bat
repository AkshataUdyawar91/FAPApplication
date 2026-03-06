@echo off
REM Manually trigger workflow for a submission

echo.
echo ========================================
echo  MANUALLY TRIGGER WORKFLOW
echo ========================================
echo.
echo This script will trigger the workflow for a submission
echo that is stuck in "Uploaded" state.
echo.

set /p submissionId="Enter Submission ID: "
set /p token="Enter Agency Token: "

if "%submissionId%"=="" (
    echo [ERROR] No submission ID provided
    pause
    exit /b 1
)

if "%token%"=="" (
    echo [ERROR] No token provided
    pause
    exit /b 1
)

echo.
echo Triggering workflow for submission: %submissionId%
echo.

curl -X POST http://localhost:5000/api/submissions/%submissionId%/process-now ^
  -H "Authorization: Bearer %token%" ^
  -H "Content-Type: application/json"

echo.
echo.
echo Workflow triggered. Check the submission state again in a few seconds.
echo Run: check-submission-state.bat
echo.
pause
