@echo off
echo === Testing Chat API ===
echo.

echo Step 1: Logging in as agency@bajaj.com...
curl -X POST "http://localhost:5000/api/auth/login" ^
  -H "Content-Type: application/json" ^
  -d "{\"email\":\"agency@bajaj.com\",\"password\":\"Password123!\"}" ^
  -s -o login-temp.json

echo.
echo Login response saved. Extracting token...

REM Extract token using PowerShell
for /f "delims=" %%i in ('powershell -Command "(Get-Content login-temp.json | ConvertFrom-Json).token"') do set TOKEN=%%i

if "%TOKEN%"=="" (
    echo ERROR: Could not extract token
    type login-temp.json
    del login-temp.json
    exit /b 1
)

echo Token extracted: %TOKEN:~0,20%...
echo.

echo Step 2: Sending chat message "Show me pending submissions"...
echo.

curl -X POST "http://localhost:5000/api/chat/message" ^
  -H "Content-Type: application/json" ^
  -H "Authorization: Bearer %TOKEN%" ^
  -d "{\"message\":\"Show me pending submissions\"}" ^
  -s -o chat-response.json

echo.
echo === CHAT RESPONSE ===
type chat-response.json
echo.
echo.

echo Response saved to chat-response.json
echo.

REM Check if response contains error message
findstr /C:"AI chat service will be available" /C:"not available" /C:"not configured" chat-response.json >nul
if %ERRORLEVEL%==0 (
    echo.
    echo WARNING: Response appears to be an error message!
    echo This means ChatService is not properly initialized.
) else (
    echo.
    echo SUCCESS: Response appears to be from real Azure OpenAI!
)

echo.
echo Cleaning up...
del login-temp.json

echo.
echo === Test Complete ===
