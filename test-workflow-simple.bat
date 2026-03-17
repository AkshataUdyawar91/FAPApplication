@echo off
echo ==================================================
echo Testing Workflow Fix
echo ==================================================
echo.

set PACKAGE_ID=48c7854b-fca6-41e7-84e8-3075c880d536

echo Step 1: Login...
curl -X POST "http://localhost:5000/api/Auth/login" -H "Content-Type: application/json" -d "{\"email\":\"agency@example.com\",\"password\":\"Agency@123\"}" > login.json 2>nul
echo Done
echo.

echo Step 2: Extract token...
for /f "tokens=2 delims=:," %%a in ('type login.json ^| findstr /C:"token"') do set TOKEN=%%a
set TOKEN=%TOKEN:"=%
set TOKEN=%TOKEN: =%
echo Token extracted
echo.

echo Step 3: Process package (wait 30-60 seconds)...
curl -X POST "http://localhost:5000/api/Submissions/%PACKAGE_ID%/process-now" -H "Authorization: Bearer %TOKEN%" -H "Content-Type: application/json" > process.json 2>nul
echo Done
echo.

echo Step 4: Get package details...
curl -X GET "http://localhost:5000/api/Submissions/%PACKAGE_ID%" -H "Authorization: Bearer %TOKEN%" -H "Content-Type: application/json" > result.json 2>nul
echo Done
echo.

echo ==================================================
echo RESULTS:
echo ==================================================
echo.
echo Process Response:
type process.json
echo.
echo.
echo Package Details:
type result.json
echo.
echo ==================================================
echo.

echo Files saved: login.json, process.json, result.json
echo You can open these files to see full details
echo.
pause
