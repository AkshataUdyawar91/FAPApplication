using BajajDocumentProcessing.Domain.Common;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents an AI-generated recommendation for document package approval, rejection, or further review.
/// Includes evidence and validation issues to support the recommendation
/// </summary>
public class Recommendation : BaseEntity
{
    /// <summary>
    /// Gets or sets the unique identifier of the document package this recommendation is for
    /// </summary>
    public Guid PackageId { get; set; }
    
    /// <summary>
    /// Gets or sets the type of recommendation (Approve, Reject, RequestMoreInfo, FlagForReview)
    /// </summary>
    public RecommendationType Type { get; set; }
    
    /// <summary>
    /// Gets or sets the AI-generated evidence supporting this recommendation
    /// </summary>
    public string Evidence { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets the JSON representation of validation issues found during analysis
    /// </summary>
    public string? ValidationIssuesJson { get; set; }
    
    /// <summary>
    /// Gets or sets the overall confidence score (0-100) for this recommendation
    /// </summary>
    public double ConfidenceScore { get; set; }

    /// <summary>
    /// Gets or sets the document package this recommendation is for
    /// </summary>
    public DocumentPackage Package { get; set; } = null!;
}
