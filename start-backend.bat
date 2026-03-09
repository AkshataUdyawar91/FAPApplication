@echo off
echo ========================================
echo Starting Backend API
echo ========================================
echo.

cd backend
echo Current directory: %CD%
echo.
echo Starting .NET API...
dotnet run --project src/BajajDocumentProcessing.API

pause
