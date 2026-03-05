# PowerShell script to fix user passwords
# This generates a proper BCrypt hash for "Password123!" and updates all users

$password = "Password123!"

# Create a temporary C# program to generate BCrypt hash
$code = @"
using System;
using BCrypt.Net;

class Program
{
    static void Main()
    {
        var password = "$password";
        var hash = BCrypt.HashPassword(password, BCrypt.GenerateSalt(12));
        Console.WriteLine(hash);
    }
}
"@

# Save to temp file
$tempDir = [System.IO.Path]::GetTempPath()
$tempFile = Join-Path $tempDir "HashGenerator.cs"
$tempProject = Join-Path $tempDir "HashGenerator.csproj"

# Create project file
$projectContent = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="BCrypt.Net-Next" Version="4.0.3" />
  </ItemGroup>
</Project>
"@

Set-Content -Path $tempProject -Value $projectContent
Set-Content -Path $tempFile -Value $code

# Build and run
Write-Host "Generating BCrypt hash for password: $password"
Push-Location $tempDir
$hash = dotnet run --project HashGenerator.csproj 2>&1 | Select-Object -Last 1
Pop-Location

Write-Host "Generated hash: $hash"
Write-Host ""
Write-Host "Updating database..."

# Update database
$sql = "UPDATE Users SET PasswordHash = '$hash' WHERE Email IN ('agency@bajaj.com', 'asm@bajaj.com', 'hq@bajaj.com');"
sqlcmd -S localhost\SQLEXPRESS -d BajajDocumentProcessing -C -Q $sql

Write-Host ""
Write-Host "Password updated successfully for all users!"
Write-Host "You can now login with:"
Write-Host "  Email: agency@bajaj.com, asm@bajaj.com, or hq@bajaj.com"
Write-Host "  Password: $password"

# Cleanup
Remove-Item $tempFile -ErrorAction SilentlyContinue
Remove-Item $tempProject -ErrorAction SilentlyContinue
