@echo off
echo ========================================
echo Starting Flutter Frontend
echo ========================================

REM Kill any existing Flutter/Dart processes
taskkill /F /IM dart.exe 2>nul
taskkill /F /IM flutter.exe 2>nul

REM Wait a moment for processes to fully terminate
timeout /t 2 /nobreak >nul

REM Clean the build directory if it exists
if exist "frontend\build" (
    echo Cleaning build directory...
    rmdir /s /q "frontend\build" 2>nul
)

REM Change to frontend directory and run Flutter
cd frontend
echo.
echo Running flutter clean...
call flutter clean
echo.
echo Running flutter pub get...
call flutter pub get
echo.
echo Starting Flutter on Chrome...
call flutter run -d chrome

pause
