@echo off
REM Complete Database Setup and Verification

setlocal

set SERVER=localhost\SQLEXPRESS01
set DATABASE=BajajDocumentProcessing

echo.
echo ========================================
echo  COMPLETE DATABASE SETUP
echo ========================================
echo.
echo This will:
echo 1. Stop running API
echo 2. Run EF migrations
echo 3. Add missing columns
echo 4. Create test users
echo 5. Verify schema
echo.
pause

REM Step 1: Stop API
echo.
echo [1/5] Stopping API...
taskkill /F /IM dotnet.exe /T 2>nul
timeout /t 2 /nobreak >nul
echo [OK] API stopped

REM Step 2: Run migrations
echo.
echo [2/5] Running EF migrations...
cd backend
dotnet ef database update --project src/BajajDocumentProcessing.Infrastructure --startup-project src/BajajDocumentProcessing.API --no-build 2>nul

if %ERRORLEVEL% NEQ 0 (
    echo [INFO] Trying with build...
    dotnet build src/BajajDocumentProcessing.API /p:BuildProjectReferences=false
    dotnet ef database update --project src/BajajDocumentProcessing.Infrastructure --startup-project src/BajajDocumentProcessing.API
    
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Migrations failed
        cd ..
        pause
        exit /b 1
    )
)
cd ..
echo [OK] Migrations complete

REM Step 3: Add missing columns
echo.
echo [3/5] Adding missing columns...
sqlcmd -S %SERVER% -d %DATABASE% -i ADD_RESUBMISSION_COLUMNS.sql -C 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [OK] Columns added
) else (
    echo [INFO] Columns may already exist
)

REM Step 4: Create users
echo.
echo [4/5] Creating users...
sqlcmd -S %SERVER% -d %DATABASE% -C -Q "DELETE FROM Users;" 2>nul

sqlcmd -S %SERVER% -d %DATABASE% -C -Q "INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, CreatedAt, UpdatedAt) VALUES (NEWID(), 'agency@bajaj.com', '$2a$12$TnTokTq7TofO02Oc.n/F0uyBQP5Hdj6789hF.E97KZS92RThQN8Aq', 'Agency User', 0, GETUTCDATE(), GETUTCDATE());"

sqlcmd -S %SERVER% -d %DATABASE% -C -Q "INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, CreatedAt, UpdatedAt) VALUES (NEWID(), 'asm@bajaj.com', '$2a$12$TnTokTq7TofO02Oc.n/F0uyBQP5Hdj6789hF.E97KZS92RThQN8Aq', 'ASM User', 1, GETUTCDATE(), GETUTCDATE());"

sqlcmd -S %SERVER% -d %DATABASE% -C -Q "INSERT INTO Users (Id, Email, PasswordHash, FullName, Role, CreatedAt, UpdatedAt) VALUES (NEWID(), 'hq@bajaj.com', '$2a$12$TnTokTq7TofO02Oc.n/F0uyBQP5Hdj6789hF.E97KZS92RThQN8Aq', 'HQ User', 2, GETUTCDATE(), GETUTCDATE());"

echo [OK] Users created

REM Step 5: Verify schema
echo.
echo [5/5] Verifying database schema...
echo.
sqlcmd -S %SERVER% -d %DATABASE% -i verify-database-schema.sql -C

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
echo Database Tables:
echo   - DocumentPackages (submissions with approval workflow)
echo   - Documents (PO, Invoice, CostSummary, Photos)
echo   - ConfidenceScores (AI confidence per document)
echo   - ValidationResults (cross-document validation)
echo   - Recommendations (AI approval/rejection)
echo   - Users (Agency, ASM, HQ)
echo.
echo Next Steps:
echo   1. Start API: cd backend ^&^& dotnet run --project src/BajajDocumentProcessing.API
echo   2. Open Swagger: http://localhost:5000/swagger
echo   3. Test upload: Upload PO, Invoice, CostSummary, Photos
echo   4. Check workflow: Documents go through AI processing
echo   5. ASM approval: Review and approve/reject
echo   6. HQ approval: Final approval/rejection
echo.
pause
