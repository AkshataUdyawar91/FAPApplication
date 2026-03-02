using BajajDocumentProcessing.Domain.Common;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Document package entity representing a submission
/// </summary>
public class DocumentPackage : BaseEntity
{
    public Guid SubmittedByUserId { get; set; }
    public Guid? ReviewedByUserId { get; set; }
    public PackageState State { get; set; } = PackageState.Uploaded;
    public DateTime? ReviewedAt { get; set; }
    public string? ReviewNotes { get; set; }

    // Navigation properties
    public User SubmittedBy { get; set; } = null!;
    public User? ReviewedBy { get; set; }
    public ICollection<Document> Documents { get; set; } = new List<Document>();
    public ValidationResult? ValidationResult { get; set; }
    public ConfidenceScore? ConfidenceScore { get; set; }
    public Recommendation? Recommendation { get; set; }
    public ICollection<Notification> Notifications { get; set; } = new List<Notification>();
}
