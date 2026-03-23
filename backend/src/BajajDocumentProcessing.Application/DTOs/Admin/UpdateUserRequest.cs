using System.ComponentModel.DataAnnotations;

namespace BajajDocumentProcessing.Application.DTOs.Admin;

/// <summary>Request DTO for updating an existing user.</summary>
public class UpdateUserRequest
{
    [Required]
    public string FullName { get; set; } = string.Empty;

    [Required, Range(1, 4)]
    public int Role { get; set; }

    public string? PhoneNumber { get; set; }

    public bool IsActive { get; set; }

    /// <summary>Leave null to keep existing password.</summary>
    public string? Password { get; set; }
}
