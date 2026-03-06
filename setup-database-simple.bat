@echo off
REM Simple Database Setup Script
REM Run this from the project root directory

setlocal

set SERVER=localhost\SQLEXPRESS01
set DATABASE=BajajDocumentProcessing

echo.
echo ========================================
echo  DATABASE SETUP
echo ========================================
echo.
echo Server: %SERVER%
echo Database: %DATABASE%
echo.
pause

echo.
echo [1/4] Running EF Core migrations...
echo.

cd backend

call dotnet ef database update --project src/BajajDocumentProcessing.Infrastructure --startup-project src/BajajDocumentProcessing.API

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Migration failed!
    cd ..
    pause
    exit /b 1
)

cd ..

echo.
echo [OK] Migrations completed
echo.

echo [2/4] Adding missing columns...
echo.

sqlcmd -S %SERVER% -d %DATABASE% -i ADD_RESUBMISSION_COLUMNS.sql -C

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [WARNING] Could not add columns - they may already exist
)

echo.
echo [3/4] Clearing old users...
echo.

sqlcmd -S %SERVER% -d %DATABASE% -Q "DELETE FROM Users;" -C

echo.
echo [4/4] Creating test users...
echo.

REM Agency User
sqlcmd -S %SERVER% -d %DATABASE% -C -Q "INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, CreatedAt, UpdatedAt) VALUES (NEWID(), 'agency@bajaj.com', '$2a$12$TnTokTq7TofO02Oc.n/F0uyBQP5Hdj6789hF.E97KZS92RThQN8Aq', 'Agency User', 0, GETUTCDATE(), GETUTCDATE());"

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to create agency user
    pause
    exit /b 1
)

REM ASM User
sqlcmd -S %SERVER% -d %DATABASE% -C -Q "INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, CreatedAt, UpdatedAt) VALUES (NEWID(), 'asm@bajaj.com', '$2a$12$TnTokTq7TofO02Oc.n/F0uyBQP5Hdj6789hF.E97KZS92RThQN8Aq', 'ASM User', 1, GETUTCDATE(), GETUTCDATE());"

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to create ASM user
    pause
    exit /b 1
)

REM HQ User
sqlcmd -S %SERVER% -d %DATABASE% -C -Q "INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, CreatedAt, UpdatedAt) VALUES (NEWID(), 'hq@bajaj.com', '$2a$12$TnTokTq7TofO02Oc.n/F0uyBQP5Hdj6789hF.E97KZS92RThQN8Aq', 'HQ User', 2, GETUTCDATE(), GETUTCDATE());"

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to create HQ user
    pause
    exit /b 1
)

echo.
echo [OK] Users created
echo.

echo Verifying users...
echo.

sqlcmd -S %SERVER% -d %DATABASE% -C -Q "SELECT Email, FullName, CASE Role WHEN 0 THEN 'Agency' WHEN 1 THEN 'ASM' WHEN 2 THEN 'HQ' END AS RoleName FROM Users;"

echo.
echo ========================================
echo SETUP COMPLETE!
echo ========================================
echo.
echo Test Credentials:
echo   agency@bajaj.com / Password123!
echo   asm@bajaj.com / Password123!
echo   hq@bajaj.com / Password123!
echo.
echo Next Steps:
echo   1. Start API: cd backend ^&^& dotnet run --project src/BajajDocumentProcessing.API
echo   2. Test login in Swagger: http://localhost:5000/swagger
echo.
pause
