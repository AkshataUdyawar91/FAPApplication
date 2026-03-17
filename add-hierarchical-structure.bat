@echo off
echo =============================================
echo Adding Hierarchical Structure Tables
echo FAP -^> PO -^> Invoices -^> Campaigns -^> Photos
echo =============================================
echo.

sqlcmd -S localhost\SQLEXPRESS -d BajajDocumentProcessing -E -C -i ADD_HIERARCHICAL_STRUCTURE.sql

echo.
echo =============================================
echo Migration Complete!
echo =============================================
pause
