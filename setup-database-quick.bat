@echo off
REM Quick Database Setup - Fixes missing columns issue

echo.
echo ========================================
echo  QUICK DATABASE SETUP
echo ========================================
echo.

set server=localhost\SQLEXPRESS01
set database=BajajDocumentProcessing

echo Step 1: Running EF migrations...
echo.

cd backend
dotnet ef database update --project src\BajajDocumentProcessing.Infrastructure --startup-project src\BajajDocumentProcessing.API

if errorlevel 1 (
    echo [ERROR] Migrations failed
    cd ..
    pause
    exit /b 1
)
cd ..

echo [OK] Migrations complete
echo.

echo Step 2: Adding missing columns...
echo.

sqlcmd -S %server% -d %database% -i ADD_RESUBMISSION_COLUMNS.sql -C

if errorlevel 1 (
    echo [ERROR] Failed to add columns
    pause
    exit /b 1
)

echo [OK] Columns added
echo.

echo Step 3: Creating/updating users...
echo.

REM Delete existing users
sqlcmd -S %server% -d %database% -Q "DELETE FROM Users;" -C

REM Create users with correct password hash
sqlcmd -S %server% -d %database% -Q "INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, CreatedAt, UpdatedAt) VALUES (NEWID(), 'agency@bajaj.com', '$2a$12$TnTokTq7TofO02Oc.n/F0uyBQP5Hdj6789hF.E97KZS92RThQN8Aq', 'Agency User', 0, GETUTCDATE(), GETUTCDATE());" -C

sqlcmd -S %server% -d %database% -Q "INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, CreatedAt, UpdatedAt) VALUES (NEWID(), 'asm@bajaj.com', '$2a$12$TnTokTq7TofO02Oc.n/F0uyBQP5Hdj6789hF.E97KZS92RThQN8Aq', 'ASM User', 1, GETUTCDATE(), GETUTCDATE());" -C

sqlcmd -S %server% -d %database% -Q "INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, CreatedAt, UpdatedAt) VALUES (NEWID(), 'hq@bajaj.com', '$2a$12$TnTokTq7TofO02Oc.n/F0uyBQP5Hdj6789hF.E97KZS92RThQN8Aq', 'HQ User', 2, GETUTCDATE(), GETUTCDATE());" -C

echo [OK] Users created
echo.

echo Step 4: Verifying setup...
echo.

sqlcmd -S %server% -d %database% -Q "SELECT Email, FullName, Role FROM Users;" -C

echo.
echo ========================================
echo SETUP COMPLETE!
echo ========================================
echo.
echo Users:
echo - agency@bajaj.com / Password123!
echo - asm@bajaj.com / Password123!
echo - hq@bajaj.com / Password123!
echo.
echo Next: Start API and test
echo.
pause
