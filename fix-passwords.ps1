# Fix User Passwords - Generate correct BCrypt hash and update database
# This script uses the backend API's BCrypt library to generate the correct hash

Write-Host "Generating BCrypt hash for 'Password123!'..." -ForegroundColor Cyan

# Create a temporary C# file to generate the hash
$csCode = @"
using System;
using BCrypt.Net;

class Program
{
    static void Main()
    {
        string password = "Password123!";
        string hash = BCrypt.Net.BCrypt.HashPassword(password, 11);
        Console.WriteLine(hash);
    }
}
"@

# Save to temp file
$tempFile = "TempHashGenerator.cs"
Set-Content -Path $tempFile -Value $csCode

# Compile and run
Write-Host "Compiling hash generator..." -ForegroundColor Yellow
$output = dotnet script eval "
#r `"nuget: BCrypt.Net-Next, 4.0.3`"
using BCrypt.Net;
var hash = BCrypt.Net.BCrypt.HashPassword(`"Password123!`", 11);
Console.WriteLine(hash);
" 2>&1

# Check if dotnet-script is available
if ($LASTEXITCODE -ne 0) {
    Write-Host "dotnet-script not found. Using alternative method..." -ForegroundColor Yellow
    
    # Alternative: Use the backend project to generate hash
    $projectPath = "backend/src/BajajDocumentProcessing.Infrastructure"
    
    # Create a simple console app
    $tempDir = "TempHashGen"
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    
    Set-Location $tempDir
    
    dotnet new console -f net8.0 -n HashGen | Out-Null
    Set-Location HashGen
    
    dotnet add package BCrypt.Net-Next --version 4.0.3 | Out-Null
    
    $programCs = @"
using System;
using BCrypt.Net;

var hash = BCrypt.Net.BCrypt.HashPassword("Password123!", 11);
Console.WriteLine(hash);
"@
    
    Set-Content -Path "Program.cs" -Value $programCs
    
    Write-Host "Generating hash..." -ForegroundColor Yellow
    $hash = dotnet run --verbosity quiet
    
    Set-Location ../..
    Remove-Item -Recurse -Force $tempDir
    
    Write-Host ""
    Write-Host "Generated BCrypt Hash:" -ForegroundColor Green
    Write-Host $hash -ForegroundColor White
    Write-Host ""
    
    # Create SQL update script
    $sqlScript = @"
-- Update User Passwords with correct BCrypt hash
USE BajajDocumentProcessing;
GO

UPDATE Users
SET PasswordHash = '$hash'
WHERE Email IN ('agency@bajaj.com', 'asm@bajaj.com', 'hq@bajaj.com');
GO

SELECT 
    Email,
    FullName,
    CASE Role
        WHEN 0 THEN 'Agency'
        WHEN 1 THEN 'ASM'
        WHEN 2 THEN 'HQ'
    END as RoleName,
    IsActive
FROM Users
WHERE IsDeleted = 0
ORDER BY Role;
GO

PRINT 'Passwords updated successfully!';
PRINT 'All users now have password: Password123!';
GO
"@
    
    Set-Content -Path "UPDATE_PASSWORDS.sql" -Value $sqlScript
    
    Write-Host "SQL script created: UPDATE_PASSWORDS.sql" -ForegroundColor Green
    Write-Host ""
    Write-Host "Executing SQL script..." -ForegroundColor Cyan
    
    # Execute the SQL script
    sqlcmd -S "localhost\SQLEXPRESS" -d "BajajDocumentProcessing" -i "UPDATE_PASSWORDS.sql" -C
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✓ Passwords updated successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "You can now login with:" -ForegroundColor Cyan
        Write-Host "  Email: agency@bajaj.com" -ForegroundColor White
        Write-Host "  Password: Password123!" -ForegroundColor White
        Write-Host ""
        Write-Host "Test at: http://localhost:5000/swagger" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "✗ Failed to update passwords" -ForegroundColor Red
        Write-Host "Please run UPDATE_PASSWORDS.sql manually" -ForegroundColor Yellow
    }
}

# Cleanup
if (Test-Path $tempFile) {
    Remove-Item $tempFile
}
