using System;
using BCrypt.Net;

var password = "Password123!";
var hash = BCrypt.HashPassword(password, 12);
Console.WriteLine(hash);
