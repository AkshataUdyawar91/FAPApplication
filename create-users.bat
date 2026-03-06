@echo off
REM Create Users in Database - Batch Script

echo.
echo ========================================
echo  Creating Users in Database
echo ========================================
echo.

REM Try to find sqlcmd
set SQLCMD_PATH=sqlcmd

REM Check if sqlcmd is available
where sqlcmd >nul 2>&1
if errorlevel 1 (
    echo sqlcmd not found in PATH, trying common locations...
    
    REM Try SQL Server 2022
    if exist "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe" (
        set SQLCMD_PATH="C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe"
        echo Found sqlcmd in SQL Server 2022 location
    ) else if exist "C:\Program Files\Microsoft SQL Server\150\Tools\Binn\sqlcmd.exe" (
        set SQLCMD_PATH="C:\Program Files\Microsoft SQL Server\150\Tools\Binn\sqlcmd.exe"
        echo Found sqlcmd in SQL Server 2019 location
    ) else if exist "C:\Program Files\Microsoft SQL Server\140\Tools\Binn\sqlcmd.exe" (
        set SQLCMD_PATH="C:\Program Files\Microsoft SQL Server\140\Tools\Binn\sqlcmd.exe"
        echo Found sqlcmd in SQL Server 2017 location
    ) else if exist "C:\Program Files\Microsoft SQL Server\130\Tools\Binn\sqlcmd.exe" (
        set SQLCMD_PATH="C:\Program Files\Microsoft SQL Server\130\Tools\Binn\sqlcmd.exe"
        echo Found sqlcmd in SQL Server 2016 location
    ) else (
        echo.
        echo ERROR: Could not find sqlcmd.exe
        echo.
        echo Please install SQL Server Command Line Tools or use SQL Server Management Studio
        echo Download from: https://aka.ms/sqlcmd
        echo.
        echo Alternative: Open CREATE_USERS.sql in SQL Server Management Studio and execute it
        echo.
        pause
        exit /b 1
    )
)

echo.
echo Using sqlcmd at: %SQLCMD_PATH%
echo.

REM Get the directory where this batch file is located
set SCRIPT_DIR=%~dp0

REM Execute the SQL script
echo Executing CREATE_USERS.sql...
echo.

%SQLCMD_PATH% -S localhost\SQLEXPRESS -d BajajDocumentProcessing -E -C -i "%SCRIPT_DIR%CREATE_USERS.sql"

if errorlevel 1 (
    echo.
    echo ========================================
    echo  ERROR: Failed to create users
    echo ========================================
    echo.
    echo Possible issues:
    echo 1. SQL Server is not running
    echo 2. Database 'BajajDocumentProcessing' does not exist
    echo 3. You don't have permission to access the database
    echo.
    echo Solutions:
    echo - Make sure SQL Server is running
    echo - Run database migrations: dotnet ef database update
    echo - Use SQL Server Management Studio to run CREATE_USERS.sql manually
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo  SUCCESS: Users created!
echo ========================================
echo.
echo You can now login with:
echo.
echo Agency User:
echo   Email: agency@bajaj.com
echo   Password: Password123!
echo.
echo ASM User:
echo   Email: asm@bajaj.com
echo   Password: Password123!
echo.
echo HQ User:
echo   Email: hq@bajaj.com
echo   Password: Password123!
echo.
echo ========================================
echo.

REM Verify users were created
echo Verifying users...
echo.
%SQLCMD_PATH% -S localhost\SQLEXPRESS -d BajajDocumentProcessing -E -C -Q "SELECT Email, FullName, CASE Role WHEN 0 THEN 'Agency' WHEN 1 THEN 'ASM' WHEN 2 THEN 'HQ' END as RoleName FROM Users WHERE IsDeleted = 0 ORDER BY Role"

echo.
pause
