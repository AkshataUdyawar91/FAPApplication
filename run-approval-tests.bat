@echo off
REM Bajaj Document Processing - Approval Flow Test Runner
REM This script runs the automated approval flow tests

echo.
echo ========================================
echo  BAJAJ APPROVAL FLOW TEST RUNNER
echo ========================================
echo.

REM Check if API is running
echo Checking if API is running...
curl -s http://localhost:5000/api/health >nul 2>&1
if errorlevel 1 (
    echo.
    echo ERROR: API is not running on http://localhost:5000
    echo Please start the API first using: run-api-dev.ps1
    echo.
    pause
    exit /b 1
)

echo API is running!
echo.

REM Run the PowerShell test script
echo Starting approval flow tests...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0test-approval-flow.ps1'"

echo.
echo ========================================
echo  TEST EXECUTION COMPLETE
echo ========================================
echo.
pause
