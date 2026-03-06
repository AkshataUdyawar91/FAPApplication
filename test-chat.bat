@echo off
echo Testing chat endpoint...
echo.

REM First login to get token
curl -X POST "http://localhost:5000/api/auth/login" ^
  -H "Content-Type: application/json" ^
  -d "{\"email\":\"agency@bajaj.com\",\"password\":\"Password123!\"}" ^
  -o login-response.json

echo.
echo Login response saved to login-response.json
echo.
echo Please extract the token from login-response.json and run:
echo curl -X POST "http://localhost:5000/api/chat/message" -H "Content-Type: application/json" -H "Authorization: Bearer YOUR_TOKEN" -d "{\"message\":\"Hello\"}"
