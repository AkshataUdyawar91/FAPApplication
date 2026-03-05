using System;

var password = "Password123!";
Console.WriteLine($"Generating BCrypt hash for: {password}");
Console.WriteLine();

// Generate hash with work factor 12
var hash = BCrypt.Net.BCrypt.HashPassword(password, 12);
Console.WriteLine($"Generated Hash:");
Console.WriteLine(hash);
Console.WriteLine();

// Verify it works
var isValid = BCrypt.Net.BCrypt.Verify(password, hash);
Console.WriteLine($"Verification test: {isValid}");
Console.WriteLine();

if (isValid)
{
    Console.WriteLine("SQL Update Statement:");
    Console.WriteLine($"UPDATE Users SET PasswordHash = '{hash}' WHERE Email IN ('agency@bajaj.com', 'asm@bajaj.com', 'hq@bajaj.com');");
}
