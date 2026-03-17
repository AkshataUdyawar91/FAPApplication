@echo off
echo ========================================
echo Enhanced Validation Report - Quick Test
echo ========================================
echo.

echo Step 1: Testing Backend API...
echo --------------------------------
powershell -ExecutionPolicy Bypass -File test-validation-report.ps1

echo.
echo ========================================
echo Backend test complete!
echo ========================================
echo.
echo Next steps:
echo 1. Review the test results above
echo 2. If successful, start the frontend:
echo    cd frontend
echo    flutter run -d chrome
echo.
echo 3. Login as ASM (asm@bajaj.com / ASM@123)
echo 4. Click "View AI Report" button
echo 5. Verify the validation report displays
echo.
pause
