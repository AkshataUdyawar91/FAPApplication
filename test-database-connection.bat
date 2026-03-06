@echo off
REM Test Database Connection Script

setlocal

set SERVER=localhost\SQLEXPRESS
set DATABASE=BajajDocumentProcessing

echo.
echo ========================================
echo  DATABASE CONNECTION TEST
echo ========================================
echo.
echo Server: %SERVER%
echo Database: %DATABASE%
echo.

echo [1/3] Testing SQL Server connection...
sqlcmd -S %SERVER% -C -Q "SELECT @@VERSION" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Cannot connect to SQL Server
    pause
    exit /b 1
)
echo [OK] SQL Server is accessible

echo.
echo [2/3] Testing database access...
sqlcmd -S %SERVER% -d %DATABASE% -C -Q "SELECT 1" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Cannot access database
    pause
    exit /b 1
)
echo [OK] Database is accessible

echo.
echo [3/3] Verifying schema...
echo.
echo Tables:
sqlcmd -S %SERVER% -d %DATABASE% -C -Q "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE' ORDER BY TABLE_NAME"

echo.
echo Users:
sqlcmd -S %SERVER% -d %DATABASE% -C -Q "SELECT Email, FullName, CASE Role WHEN 0 THEN 'Agency' WHEN 1 THEN 'ASM' WHEN 2 THEN 'HQ' END AS RoleName FROM Users"

echo.
echo DocumentPackages columns:
sqlcmd -S %SERVER% -d %DATABASE% -C -Q "SELECT COUNT(*) as ColumnCount FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages'"

echo.
echo ========================================
echo CONNECTION TEST COMPLETE!
echo ========================================
echo.
echo Database is ready for use.
echo.
echo Test Credentials:
echo   agency@bajaj.com / Password123!
echo   asm@bajaj.com / Password123!
echo   hq@bajaj.com / Password123!
echo.
echo Next Steps:
echo   1. Start API: cd backend ^&^& dotnet run --project src/BajajDocumentProcessing.API
echo   2. Open Swagger: http://localhost:5000/swagger
echo   3. Test login with credentials above
echo.
pause
