@echo off
echo ============================================
echo Fixing Database Schema for Hierarchical Structure
echo ============================================
echo.

sqlcmd -S "localhost\SQLEXPRESS" -d BajajDocumentProcessing -E -C -i "FIX_MIGRATION_AND_ADD_TEAMSJSON.sql"

echo.
echo ============================================
echo Done! Press any key to exit...
pause > nul
