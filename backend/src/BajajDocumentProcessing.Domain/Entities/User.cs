using BajajDocumentProcessing.Domain.Common;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents a system user with role-based access (Agency, ASM, or HQ).
/// Manages authentication, authorization, and tracks user activity
/// </summary>
public class User : BaseEntity
{
    /// <summary>
    /// Gets or sets the user's email address (used for login and notifications)
    /// </summary>
    public string Email { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets the BCrypt hashed password for authentication
    /// </summary>
    public string PasswordHash { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets the user's full name for display purposes
    /// </summary>
    public string FullName { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets the user's role (Agency, ASM, or HQ) which determines access permissions
    /// </summary>
    public UserRole Role { get; set; }
    
    /// <summary>
    /// Gets or sets the user's phone number for contact purposes
    /// </summary>
    public string? PhoneNumber { get; set; }
    
    /// <summary>
    /// Gets or sets whether the user account is active and can log in
    /// </summary>
    public bool IsActive { get; set; } = true;
    
    /// <summary>
    /// Gets or sets the timestamp of the user's most recent login
    /// </summary>
    public DateTime? LastLoginAt { get; set; }

    /// <summary>
    /// Gets or sets the collection of document packages submitted by this user (Agency role)
    /// </summary>
    public ICollection<DocumentPackage> SubmittedPackages { get; set; } = new List<DocumentPackage>();
    
    /// <summary>
    /// Gets or sets the collection of document packages reviewed by this user (ASM or HQ role)
    /// </summary>
    public ICollection<DocumentPackage> ReviewedPackages { get; set; } = new List<DocumentPackage>();
    
    /// <summary>
    /// Gets or sets the collection of notifications sent to this user
    /// </summary>
    public ICollection<Notification> Notifications { get; set; } = new List<Notification>();
    
    /// <summary>
    /// Gets or sets the collection of audit log entries for actions performed by this user
    /// </summary>
    public ICollection<AuditLog> AuditLogs { get; set; } = new List<AuditLog>();

    /// <summary>
    /// Gets or sets the collection of device tokens registered by this user for push notifications
    /// </summary>
    public ICollection<DeviceToken> DeviceTokens { get; set; } = new List<DeviceToken>();

    /// <summary>
    /// Gets or sets the collection of notification preferences configured by this user
    /// </summary>
    public ICollection<NotificationPreference> NotificationPreferences { get; set; } = new List<NotificationPreference>();

    /// <summary>
    /// Gets or sets the collection of notification delivery logs for this user
    /// </summary>
    public ICollection<NotificationLog> NotificationLogs { get; set; } = new List<NotificationLog>();
}
