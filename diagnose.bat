@echo off
echo.
echo ========================================
echo  DIAGNOSTIC CHECK
echo ========================================
echo.

echo Step 1: Check if API is running...
curl -s http://localhost:5000/api/health
if errorlevel 1 (
    echo [FAIL] API is not running
    pause
    exit /b 1
)
echo [PASS] API is running
echo.

echo Step 2: Check database connection...
sqlcmd -S localhost\SQLEXPRESS -d BajajDocumentProcessing -E -C -Q "SELECT @@VERSION" >nul 2>&1
if errorlevel 1 (
    echo [FAIL] Cannot connect to database
    pause
    exit /b 1
)
echo [PASS] Database connection OK
echo.

echo Step 3: Check if users exist...
sqlcmd -S localhost\SQLEXPRESS -d BajajDocumentProcessing -E -C -Q "SELECT COUNT(*) as UserCount FROM Users"
echo.

echo Step 4: Check password hash for agency user...
sqlcmd -S localhost\SQLEXPRESS -d BajajDocumentProcessing -E -C -Q "SELECT Email, LEFT(PasswordHash, 50) as PasswordHashPreview FROM Users WHERE Email = 'agency@bajaj.com'"
echo.

echo Step 5: Test login...
echo.
curl -X POST http://localhost:5000/api/auth/login -H "Content-Type: application/json" -d "{\"email\":\"agency@bajaj.com\",\"password\":\"Password123!\"}"
echo.
echo.

echo ========================================
echo If you see a token above, login works!
echo If you see "Invalid email or password", the hash is wrong.
echo ========================================
echo.
pause
