@echo off
setlocal enabledelayedexpansion

echo ==================================================
echo Testing Workflow Fix for Package
echo ==================================================
echo.

set PACKAGE_ID=48c7854b-fca6-41e7-84e8-3075c880d536

echo [1/3] Logging in...
curl -s -X POST "http://localhost:5000/api/Auth/login" ^
  -H "Content-Type: application/json" ^
  -d "{\"email\":\"agency@example.com\",\"password\":\"Agency@123\"}" ^
  -o login_response.json

if errorlevel 1 (
    echo ERROR: Login failed
    exit /b 1
)

echo Login successful
echo.

echo [2/3] Processing package (this may take 30-60 seconds)...
echo Please wait...

for /f "tokens=2 delims=:," %%a in ('type login_response.json ^| findstr /C:"token"') do (
    set TOKEN=%%a
    set TOKEN=!TOKEN:"=!
    set TOKEN=!TOKEN: =!
)

curl -s -X POST "http://localhost:5000/api/Submissions/%PACKAGE_ID%/process-now" ^
  -H "Authorization: Bearer !TOKEN!" ^
  -H "Content-Type: application/json" ^
  -o process_response.json

echo Process request completed
echo.

echo [3/3] Getting package details...
curl -s -X GET "http://localhost:5000/api/Submissions/%PACKAGE_ID%" ^
  -H "Authorization: Bearer !TOKEN!" ^
  -H "Content-Type: application/json" ^
  -o package_details.json

echo.
echo ==================================================
echo PACKAGE STATUS
echo ==================================================
type package_details.json
echo.
echo ==================================================

del login_response.json process_response.json package_details.json 2>nul

echo.
echo Test completed. Check the JSON output above.
echo If "state" is "PendingApproval" and "recommendation" is not null, the fix worked!
echo.
pause
