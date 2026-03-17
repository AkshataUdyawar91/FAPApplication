using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents AI-generated confidence scores for document extraction and validation quality.
/// Scores are weighted: PO (30%), Invoice (30%), Cost Summary (20%), Activity (10%), Photos (10%)
/// </summary>
public class ConfidenceScore : BaseEntity
{
    /// <summary>
    /// Gets or sets the unique identifier of the document package this score belongs to
    /// </summary>
    public Guid PackageId { get; set; }
    
    /// <summary>
    /// Gets or sets the confidence score for Purchase Order extraction (0-100, weighted 30%)
    /// </summary>
    public double PoConfidence { get; set; }
    
    /// <summary>
    /// Gets or sets the confidence score for Invoice extraction (0-100, weighted 30%)
    /// </summary>
    public double InvoiceConfidence { get; set; }
    
    /// <summary>
    /// Gets or sets the confidence score for Cost Summary extraction (0-100, weighted 20%)
    /// </summary>
    public double CostSummaryConfidence { get; set; }
    
    /// <summary>
    /// Gets or sets the confidence score for Activity document extraction (0-100, weighted 10%)
    /// </summary>
    public double ActivityConfidence { get; set; }
    
    /// <summary>
    /// Gets or sets the confidence score for Photos extraction (0-100, weighted 10%)
    /// </summary>
    public double PhotosConfidence { get; set; }
    
    /// <summary>
    /// Gets or sets the weighted overall confidence score (0-100) calculated from individual document scores
    /// </summary>
    public double OverallConfidence { get; set; }
    
    /// <summary>
    /// Gets or sets whether this package is flagged for manual review due to low confidence scores
    /// </summary>
    public bool IsFlaggedForReview { get; set; }

    /// <summary>
    /// Gets or sets the document package this confidence score belongs to
    /// </summary>
    public DocumentPackage Package { get; set; } = null!;
}
