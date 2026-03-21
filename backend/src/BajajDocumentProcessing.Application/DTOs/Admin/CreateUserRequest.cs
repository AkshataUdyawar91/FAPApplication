using System.ComponentModel.DataAnnotations;

namespace BajajDocumentProcessing.Application.DTOs.Admin;

/// <summary>Request DTO for creating a new user.</summary>
public class CreateUserRequest
{
    [Required, EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required, MinLength(8)]
    public string Password { get; set; } = string.Empty;

    [Required]
    public string FullName { get; set; } = string.Empty;

    [Required, Range(1, 4)]
    public int Role { get; set; }

    public string? PhoneNumber { get; set; }

    public bool IsActive { get; set; } = true;
}
