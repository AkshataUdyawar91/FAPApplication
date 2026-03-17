@echo off
echo ========================================
echo Adding Campaign Fields to Database
echo ========================================
echo.
echo This will add the following columns to DocumentPackages table:
echo - CampaignStartDate (DATETIME2)
echo - CampaignEndDate (DATETIME2)
echo - CampaignWorkingDays (INT)
echo.
echo Press any key to continue or Ctrl+C to cancel...
pause > nul

sqlcmd -S localhost\SQLEXPRESS -d BajajDocumentProcessing -E -Q "ALTER TABLE DocumentPackages ADD CampaignStartDate DATETIME2 NULL, CampaignEndDate DATETIME2 NULL, CampaignWorkingDays INT NULL"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo Campaign fields added successfully!
    echo ========================================
    echo.
    echo Verifying columns...
    sqlcmd -S localhost\SQLEXPRESS -d BajajDocumentProcessing -E -Q "SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME IN ('CampaignStartDate', 'CampaignEndDate', 'CampaignWorkingDays')"
) else (
    echo.
    echo ========================================
    echo Error adding campaign fields
    echo Note: If columns already exist, this is expected
    echo ========================================
)

echo.
pause
