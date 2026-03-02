using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Confidence score entity for document package
/// </summary>
public class ConfidenceScore : BaseEntity
{
    public Guid PackageId { get; set; }
    public double PoConfidence { get; set; }
    public double InvoiceConfidence { get; set; }
    public double CostSummaryConfidence { get; set; }
    public double ActivityConfidence { get; set; }
    public double PhotosConfidence { get; set; }
    public double OverallConfidence { get; set; }
    public bool IsFlaggedForReview { get; set; }

    // Navigation properties
    public DocumentPackage Package { get; set; } = null!;
}
