@echo off
REM Stop API and Setup Database

echo.
echo ========================================
echo  STOP API AND SETUP DATABASE
echo ========================================
echo.

echo Step 1: Stopping any running API processes...
echo.

REM Kill any dotnet processes running the API
taskkill /F /IM dotnet.exe /T 2>nul

if %ERRORLEVEL% EQU 0 (
    echo [OK] API processes stopped
    timeout /t 2 /nobreak >nul
) else (
    echo [INFO] No API processes were running
)

echo.
echo Step 2: Running database setup...
echo.

call setup-database-simple.bat

echo.
echo ========================================
echo COMPLETE!
echo ========================================
echo.
echo You can now start the API:
echo   cd backend
echo   dotnet run --project src/BajajDocumentProcessing.API
echo.
pause
