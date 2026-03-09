@echo off
echo ========================================
echo Enhanced Validation Report API Test
echo ========================================
echo.
echo This script will test the validation report API endpoint
echo.
echo Prerequisites:
echo - Backend API must be running on http://localhost:5000
echo - Database must have test submissions
echo.
pause

echo.
echo Testing API endpoint...
echo.

REM Test with curl if available
where curl >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo Using curl to test API...
    echo.
    
    REM Login as ASM
    echo Step 1: Login as ASM user...
    curl -X POST "http://localhost:5000/api/auth/login" ^
         -H "Content-Type: application/json" ^
         -d "{\"email\":\"asm@bajaj.com\",\"password\":\"ASM@123\"}" ^
         -o login-response.json
    
    echo.
    echo Login response saved to login-response.json
    echo.
    echo Step 2: Get submissions...
    echo Note: You'll need to extract the token from login-response.json
    echo       and manually test the validation report endpoint
    echo.
    echo Example:
    echo curl -X GET "http://localhost:5000/api/submissions/{id}/validation-report" ^
    echo      -H "Authorization: Bearer {token}"
    echo.
) else (
    echo curl not found. Please use PowerShell script instead:
    echo   powershell -ExecutionPolicy Bypass -File test-validation-report.ps1
    echo.
)

echo.
echo ========================================
echo Test script complete
echo ========================================
echo.
echo Next steps:
echo 1. If backend is not running, start it:
echo    cd backend
echo    dotnet run
echo.
echo 2. Run the PowerShell test script for detailed testing:
echo    powershell -ExecutionPolicy Bypass -File test-validation-report.ps1
echo.
echo 3. Or start the frontend to test the UI:
echo    cd frontend
echo    flutter run -d chrome
echo.
pause
