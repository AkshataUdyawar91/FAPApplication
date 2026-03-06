@echo off
REM Complete Database Setup Script
REM This script will recreate the database from scratch with all migrations and users

echo.
echo ========================================
echo  COMPLETE DATABASE SETUP
echo ========================================
echo.
echo This script will:
echo 1. Drop existing database (if exists)
echo 2. Create new database with EF migrations
echo 3. Create test users with correct passwords
echo.
echo WARNING: This will delete all existing data!
echo.
pause

set server=localhost\SQLEXPRESS
set database=BajajDocumentProcessing

echo.
echo ========================================
echo Step 1: Dropping existing database
echo ========================================
echo.

sqlcmd -S %server% -Q "IF EXISTS (SELECT name FROM sys.databases WHERE name = '%database%') DROP DATABASE %database%;" -C

if errorlevel 1 (
    echo [WARNING] Could not drop database - it may not exist
) else (
    echo [OK] Database dropped successfully
)

echo.
echo ========================================
echo Step 2: Running EF Core migrations
echo ========================================
echo.
echo This will create the database and all tables...
echo.

cd backend
dotnet ef database update --project src\BajajDocumentProcessing.Infrastructure --startup-project src\BajajDocumentProcessing.API

if errorlevel 1 (
    echo [ERROR] Failed to run migrations
    cd ..
    pause
    exit /b 1
)

cd ..
echo [OK] Database created with migrations

echo.
echo ========================================
echo Step 3: Creating test users
echo ========================================
echo.

REM Create users with correct BCrypt hash for "Password123!"
sqlcmd -S %server% -d %database% -Q "DELETE FROM Users;" -C

sqlcmd -S %server% -d %database% -Q "INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, CreatedAt, UpdatedAt) VALUES (NEWID(), 'agency@bajaj.com', '$2a$12$TnTokTq7TofO02Oc.n/F0uyBQP5Hdj6789hF.E97KZS92RThQN8Aq', 'Agency User', 0, GETUTCDATE(), GETUTCDATE());" -C

sqlcmd -S %server% -d %database% -Q "INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, CreatedAt, UpdatedAt) VALUES (NEWID(), 'asm@bajaj.com', '$2a$12$TnTokTq7TofO02Oc.n/F0uyBQP5Hdj6789hF.E97KZS92RThQN8Aq', 'ASM User', 1, GETUTCDATE(), GETUTCDATE());" -C

sqlcmd -S %server% -d %database% -Q "INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, CreatedAt, UpdatedAt) VALUES (NEWID(), 'hq@bajaj.com', '$2a$12$TnTokTq7TofO02Oc.n/F0uyBQP5Hdj6789hF.E97KZS92RThQN8Aq', 'HQ User', 2, GETUTCDATE(), GETUTCDATE());" -C

if errorlevel 1 (
    echo [ERROR] Failed to create users
    pause
    exit /b 1
)

echo [OK] Users created successfully

echo.
echo ========================================
echo Step 4: Verifying setup
echo ========================================
echo.

sqlcmd -S %server% -d %database% -Q "SELECT Email, FullName, Role FROM Users;" -C

echo.
echo ========================================
echo SETUP COMPLETE!
echo ========================================
echo.
echo Database: %database%
echo Server: %server%
echo.
echo Test Users Created:
echo - agency@bajaj.com / Password123! (Role: Agency)
echo - asm@bajaj.com / Password123! (Role: ASM)
echo - hq@bajaj.com / Password123! (Role: HQ)
echo.
echo Next Steps:
echo 1. Start the API: cd backend ^&^& dotnet run --project src\BajajDocumentProcessing.API
echo 2. Test login: curl -X POST http://localhost:5000/api/auth/login -H "Content-Type: application/json" -d "{\"email\":\"agency@bajaj.com\",\"password\":\"Password123!\"}"
echo 3. Run approval flow tests: test-approval-simple.bat
echo.
pause
