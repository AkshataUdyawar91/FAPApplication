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
    
    // ASM Approval tracking
    public Guid? ASMReviewedByUserId { get; set; }
    public DateTime? ASMReviewedAt { get; set; }
    public string? ASMReviewNotes { get; set; }
    
    // HQ Approval tracking
    public Guid? HQReviewedByUserId { get; set; }
    public DateTime? HQReviewedAt { get; set; }
    public string? HQReviewNotes { get; set; }
    
    // Resubmission tracking
    public int? ResubmissionCount { get; set; } = 0;
    public int? HQResubmissionCount { get; set; } = 0;

    // Navigation properties
    public User SubmittedBy { get; set; } = null!;
    public User? ReviewedBy { get; set; }
    public User? ASMReviewedBy { get; set; }
    public User? HQReviewedBy { get; set; }
    public ICollection<Document> Documents { get; set; } = new List<Document>();
    public ValidationResult? ValidationResult { get; set; }
    public ConfidenceScore? ConfidenceScore { get; set; }
    public Recommendation? Recommendation { get; set; }
    public ICollection<Notification> Notifications { get; set; } = new List<Notification>();
}
