#!/usr/bin/env dotnet-script
#r "nuget: BCrypt.Net-Next, 4.0.3"

using BCrypt.Net;

// Generate BCrypt hash for "Password123!"
string password = "Password123!";
string hash = BCrypt.Net.BCrypt.HashPassword(password, 11);

Console.WriteLine("Password: " + password);
Console.WriteLine("BCrypt Hash: " + hash);
Console.WriteLine();
Console.WriteLine("SQL Update Statement:");
Console.WriteLine("UPDATE Users SET PasswordHash = '" + hash + "' WHERE Email IN ('agency@bajaj.com', 'asm@bajaj.com', 'hq@bajaj.com');");
