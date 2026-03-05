#!/usr/bin/env dotnet-script
#r "nuget: BCrypt.Net-Next, 4.0.3"

using BCrypt.Net;

var password = "Password123!";
var storedHash = "$2a$12$LQv3c1yqBWEFRqvCpnGH.OMJmkImpbefqqHQXSNTLUpbRS2uKU/Iy";

Console.WriteLine($"Testing password: {password}");
Console.WriteLine($"Against hash: {storedHash}");
Console.WriteLine();

var isValid = BCrypt.Verify(password, storedHash);
Console.WriteLine($"Password verification result: {isValid}");

if (!isValid)
{
    Console.WriteLine();
    Console.WriteLine("Generating a new hash...");
    var newHash = BCrypt.HashPassword(password, BCrypt.GenerateSalt(12));
    Console.WriteLine($"New hash: {newHash}");
    Console.WriteLine();
    Console.WriteLine("SQL to update:");
    Console.WriteLine($"UPDATE Users SET PasswordHash = '{newHash}' WHERE Email IN ('agency@bajaj.com', 'asm@bajaj.com', 'hq@bajaj.com');");
}
