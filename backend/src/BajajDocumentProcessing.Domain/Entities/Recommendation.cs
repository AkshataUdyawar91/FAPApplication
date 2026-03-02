using BajajDocumentProcessing.Domain.Common;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Recommendation entity for document package approval
/// </summary>
public class Recommendation : BaseEntity
{
    public Guid PackageId { get; set; }
    public RecommendationType Type { get; set; }
    public string Evidence { get; set; } = string.Empty;
    public string? ValidationIssuesJson { get; set; }
    public double ConfidenceScore { get; set; }

    // Navigation properties
    public DocumentPackage Package { get; set; } = null!;
}
