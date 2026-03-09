@echo off
echo ========================================
echo Running Flutter (Bypassing PS Policy)
echo ========================================

REM Kill any locking processes
taskkill /F /IM dart.exe 2>nul
timeout /t 2 /nobreak >nul

REM Run flutter directly
echo Running flutter pub get...
flutter pub get

echo.
echo Starting Flutter on Chrome...
flutter run -d chrome
