@echo off
echo ========================================
echo Adding Campaign Fields to Database
echo ========================================
echo.

sqlcmd -S localhost\SQLEXPRESS -d BajajDocumentProcessing -E -C -Q "ALTER TABLE DocumentPackages ADD CampaignStartDate DATETIME2 NULL, CampaignEndDate DATETIME2 NULL, CampaignWorkingDays INT NULL"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo Campaign fields added successfully!
    echo ========================================
) else (
    echo.
    echo ========================================
    echo Note: If you see 'column already exists' error, that's OK
    echo ========================================
)

echo.
echo Verifying columns exist...
sqlcmd -S localhost\SQLEXPRESS -d BajajDocumentProcessing -E -C -Q "SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME IN ('CampaignStartDate', 'CampaignEndDate', 'CampaignWorkingDays')"
