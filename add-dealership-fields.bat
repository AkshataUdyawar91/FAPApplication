@echo off
echo Adding Dealership Fields to Database...
echo.

sqlcmd -S localhost\SQLEXPRESS -d BajajDocumentProcessing -E -C -i ADD_DEALERSHIP_FIELDS.sql

echo.
echo Done!
pause
