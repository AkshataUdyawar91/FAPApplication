using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents an Area Sales Manager (ASM) entity.
/// ASMs are tracked with their name and location for assignment and approval tracking.
/// </summary>
public class ASM : BaseEntity
{
    /// <summary>
    /// Gets or sets the full name of the ASM
    /// </summary>
    public string Name { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets the geographic area/region assigned to this ASM
    /// </summary>
    public string Location { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets the optional user account ID linked to this ASM.
    /// Nullable to support ASMs without user accounts.
    /// </summary>
    public Guid? UserId { get; set; }

    /// <summary>
    /// Gets or sets the optional user account linked to this ASM
    /// </summary>
    public User? User { get; set; }
    
    // TODO: Uncomment when RequestApprovalHistory entity is created in Task 1.8
    // /// <summary>
    // /// Gets or sets the collection of approval history entries for this ASM
    // /// Many-to-many relationship with DocumentPackages via RequestApprovalHistory
    // /// </summary>
    // public ICollection<RequestApprovalHistory> ApprovalHistory { get; set; } = new List<RequestApprovalHistory>();
}
