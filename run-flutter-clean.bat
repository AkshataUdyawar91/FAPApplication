@echo off
echo ========================================
echo Cleaning and Running Flutter
echo ========================================

REM Kill any processes that might be locking files
echo Killing any processes that might lock files...
taskkill /F /IM dart.exe 2>nul
taskkill /F /IM chrome.exe 2>nul
timeout /t 3 /nobreak >nul

REM Try to delete build directories manually
echo Removing build directories...
if exist "frontend\build" rmdir /s /q "frontend\build" 2>nul
if exist "frontend\.dart_tool" rmdir /s /q "frontend\.dart_tool" 2>nul

REM Set execution policy for this session and run Flutter
echo.
echo Setting PowerShell execution policy and running Flutter...
powershell -ExecutionPolicy Bypass -Command "cd frontend; flutter pub get; flutter run -d chrome"

pause
