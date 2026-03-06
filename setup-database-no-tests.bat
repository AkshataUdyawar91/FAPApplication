@echo off
REM Database Setup - Skip Tests

setlocal

set SERVER=localhost\SQLEXPRESS01
set DATABASE=BajajDocumentProcessing

echo.
echo ========================================
echo  DATABASE SETUP (Skip Tests)
echo ========================================
echo.

echo Step 1: Stopping API...
echo.

taskkill /F /IM dotnet.exe /T 2>nul
timeout /t 2 /nobreak >nul

echo.
echo Step 2: Running migrations (API only)...
echo.

cd backend

REM Use --no-build flag to skip building, or build only API project
dotnet build src/BajajDocumentProcessing.API --no-dependencies

dotnet ef database update --project src/BajajDocumentProcessing.Infrastructure --startup-project src/BajajDocumentProcessing.API --no-build

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Migration failed - trying without no-build flag...
    dotnet ef database update --project src/BajajDocumentProcessing.Infrastructure --startup-project src/BajajDocumentProcessing.API
    
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Migration still failed
        cd ..
        pause
        exit /b 1
    )
)

cd ..

echo [OK] Migrations completed
echo.

echo Step 3: Adding missing columns...
echo.

sqlcmd -S %SERVER% -d %DATABASE% -i ADD_RESUBMISSION_COLUMNS.sql -C

echo.
echo Step 4: Creating users...
echo.

sqlcmd -S %SERVER% -d %DATABASE% -C -Q "DELETE FROM Users;"

sqlcmd -S %SERVER% -d %DATABASE% -C -Q "INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, CreatedAt, UpdatedAt) VALUES (NEWID(), 'agency@bajaj.com', '$2a$12$TnTokTq7TofO02Oc.n/F0uyBQP5Hdj6789hF.E97KZS92RThQN8Aq', 'Agency User', 0, GETUTCDATE(), GETUTCDATE());"

sqlcmd -S %SERVER% -d %DATABASE% -C -Q "INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, CreatedAt, UpdatedAt) VALUES (NEWID(), 'asm@bajaj.com', '$2a$12$TnTokTq7TofO02Oc.n/F0uyBQP5Hdj6789hF.E97KZS92RThQN8Aq', 'ASM User', 1, GETUTCDATE(), GETUTCDATE());"

sqlcmd -S %SERVER% -d %DATABASE% -C -Q "INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, CreatedAt, UpdatedAt) VALUES (NEWID(), 'hq@bajaj.com', '$2a$12$TnTokTq7TofO02Oc.n/F0uyBQP5Hdj6789hF.E97KZS92RThQN8Aq', 'HQ User', 2, GETUTCDATE(), GETUTCDATE());"

echo.
echo [OK] Users created
echo.

echo Verifying...
echo.

sqlcmd -S %SERVER% -d %DATABASE% -C -Q "SELECT Email, FullName, CASE Role WHEN 0 THEN 'Agency' WHEN 1 THEN 'ASM' WHEN 2 THEN 'HQ' END AS RoleName FROM Users;"

echo.
echo ========================================
echo SETUP COMPLETE!
echo ========================================
echo.
echo Credentials:
echo   agency@bajaj.com / Password123!
echo   asm@bajaj.com / Password123!
echo   hq@bajaj.com / Password123!
echo.
echo Start API:
echo   cd backend
echo   dotnet run --project src/BajajDocumentProcessing.API
echo.
pause
