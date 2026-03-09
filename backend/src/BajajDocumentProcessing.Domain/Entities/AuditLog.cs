using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents an audit log entry that tracks user actions and system events for compliance and security monitoring
/// </summary>
public class AuditLog : BaseEntity
{
    /// <summary>
    /// Gets or sets the unique identifier of the user who performed the action
    /// </summary>
    public Guid UserId { get; set; }
    
    /// <summary>
    /// Gets or sets the action performed (e.g., "Login", "SubmitPackage", "ApproveSubmission")
    /// </summary>
    public string Action { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets the type of entity affected by the action (e.g., "DocumentPackage", "User")
    /// </summary>
    public string EntityType { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets the unique identifier of the entity affected by the action, if applicable
    /// </summary>
    public Guid? EntityId { get; set; }
    
    /// <summary>
    /// Gets or sets the JSON representation of the entity's state before the action
    /// </summary>
    public string? OldValuesJson { get; set; }
    
    /// <summary>
    /// Gets or sets the JSON representation of the entity's state after the action
    /// </summary>
    public string? NewValuesJson { get; set; }
    
    /// <summary>
    /// Gets or sets the IP address from which the action was performed
    /// </summary>
    public string IpAddress { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets the user agent string of the client that performed the action
    /// </summary>
    public string UserAgent { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the user who performed the action
    /// </summary>
    public User User { get; set; } = null!;
}
