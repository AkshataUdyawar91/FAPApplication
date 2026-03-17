using BajajDocumentProcessing.Domain.Common;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents comments on document package submissions with versioning support.
/// Tracks communication history across resubmissions for audit and collaboration purposes.
/// </summary>
public class RequestComments : BaseEntity
{
    /// <summary>
    /// Foreign key to the document package this comment belongs to.
    /// </summary>
    public Guid PackageId { get; set; }

    /// <summary>
    /// Foreign key to the user who created this comment.
    /// </summary>
    public Guid UserId { get; set; }

    /// <summary>
    /// Role of the user at the time of commenting (Agency, ASM, RA, Admin).
    /// </summary>
    public UserRole UserRole { get; set; }

    /// <summary>
    /// The text content of the comment.
    /// </summary>
    public string CommentText { get; set; } = string.Empty;

    /// <summary>
    /// Date and time when this comment was created.
    /// </summary>
    public DateTime CommentDate { get; set; }

    /// <summary>
    /// Version number of the package when this comment was made.
    /// Used to track comments across resubmissions.
    /// </summary>
    public int VersionNumber { get; set; }

    // Navigation properties

    /// <summary>
    /// Navigation property to the document package this comment belongs to.
    /// </summary>
    public DocumentPackage DocumentPackage { get; set; } = null!;

    /// <summary>
    /// Navigation property to the user who created this comment.
    /// </summary>
    public User User { get; set; } = null!;
}
