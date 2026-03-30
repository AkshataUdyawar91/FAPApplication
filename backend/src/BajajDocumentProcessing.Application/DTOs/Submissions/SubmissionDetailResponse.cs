using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Submissions;

/// <summary>
/// Detailed information about a single submission
/// </summary>
public class SubmissionDetailResponse
{
    /// <summary>
    /// Unique identifier of the submission
    /// </summary>
    [JsonPropertyName("id")]
    public required Guid Id { get; init; }
    
    /// <summary>
    /// Current state of the submission
    /// </summary>
    [JsonPropertyName("state")]
    public required string State { get; init; }
    
    /// <summary>
    /// UTC timestamp when the submission was created
    /// </summary>
    [JsonPropertyName("createdAt")]
    public required DateTime CreatedAt { get; init; }
    
    /// <summary>
    /// UTC timestamp when the submission was last updated
    /// </summary>
    [JsonPropertyName("updatedAt")]
    public DateTime? UpdatedAt { get; init; }
    
    /// <summary>
    /// UTC timestamp when ASM reviewed the submission
    /// </summary>
    [JsonPropertyName("asmReviewedAt")]
    public DateTime? ASMReviewedAt { get; init; }
    
    /// <summary>
    /// ASM review notes
    /// </summary>
    [JsonPropertyName("asmReviewNotes")]
    public string? ASMReviewNotes { get; init; }
    
    /// <summary>
    /// UTC timestamp when HQ reviewed the submission
    /// </summary>
    [JsonPropertyName("hqReviewedAt")]
    public DateTime? HQReviewedAt { get; init; }
    
    /// <summary>
    /// HQ review notes
    /// </summary>
    [JsonPropertyName("hqReviewNotes")]
    public string? HQReviewNotes { get; init; }
    
    /// <summary>
    /// Legacy: UTC timestamp when the submission was reviewed
    /// </summary>
    [JsonPropertyName("reviewedAt")]
    public DateTime? ReviewedAt { get; init; }
    
    /// <summary>
    /// Legacy: Review notes
    /// </summary>
    [JsonPropertyName("reviewNotes")]
    public string? ReviewNotes { get; init; }
    
    /// <summary>
    /// List of documents in the submission
    /// </summary>
    [JsonPropertyName("documents")]
    public required List<SubmissionDocumentDto> Documents { get; init; }
    
    /// <summary>
    /// Hierarchical campaign data (teams with invoices, photos, cost/activity summaries)
    /// </summary>
    [JsonPropertyName("campaigns")]
    public List<CampaignDto>? Campaigns { get; init; }
    
    /// <summary>
    /// Package-level Cost Summary filename (for draft mode when no campaigns exist)
    /// </summary>
    [JsonPropertyName("costSummaryFileName")]
    public string? CostSummaryFileName { get; init; }
    
    /// <summary>
    /// Package-level Activity Summary filename (for draft mode when no campaigns exist)
    /// </summary>
    [JsonPropertyName("activitySummaryFileName")]
    public string? ActivitySummaryFileName { get; init; }
    
    /// <summary>
    /// Package-level Enquiry Document filename (for draft mode when no campaigns exist)
    /// </summary>
    [JsonPropertyName("enquiryDocFileName")]
    public string? EnquiryDocFileName { get; init; }
    
    /// <summary>
    /// Validation results
    /// </summary>
    [JsonPropertyName("validationResult")]
    public ValidationResultDto? ValidationResult { get; init; }
    
    /// <summary>
    /// PO validation result
    /// </summary>
    [JsonPropertyName("poValidation")]
    public ValidationResultDto? POValidation { get; init; }
    
    /// <summary>
    /// Invoice validation results (one per invoice)
    /// </summary>
    [JsonPropertyName("invoiceValidations")]
    public List<DocumentValidationDto>? InvoiceValidations { get; init; }
    
    /// <summary>
    /// Cost Summary validation result
    /// </summary>
    [JsonPropertyName("costSummaryValidation")]
    public ValidationResultDto? CostSummaryValidation { get; init; }
    
    /// <summary>
    /// Activity Summary validation result
    /// </summary>
    [JsonPropertyName("activityValidation")]
    public ValidationResultDto? ActivityValidation { get; init; }
    
    /// <summary>
    /// Enquiry Document validation result
    /// </summary>
    [JsonPropertyName("enquiryValidation")]
    public ValidationResultDto? EnquiryValidation { get; init; }
    
    /// <summary>
    /// Photo validation results (one per photo)
    /// </summary>
    [JsonPropertyName("photoValidations")]
    public List<DocumentValidationDto>? PhotoValidations { get; init; }
    
    /// <summary>
    /// Confidence scores
    /// </summary>
    [JsonPropertyName("confidenceScore")]
    public ConfidenceScoreDto? ConfidenceScore { get; init; }
    
    /// <summary>
    /// AI recommendation
    /// </summary>
    [JsonPropertyName("recommendation")]
    public RecommendationDto? Recommendation { get; init; }

    /// <summary>
    /// Agency ID that submitted this package
    /// </summary>
    [JsonPropertyName("agencyId")]
    public Guid? AgencyId { get; init; }

    /// <summary>
    /// Agency/supplier name
    /// </summary>
    [JsonPropertyName("agencyName")]
    public string? AgencyName { get; init; }

    /// <summary>
    /// Current version number of the submission
    /// </summary>
    [JsonPropertyName("versionNumber")]
    public int VersionNumber { get; init; } = 1;

    /// <summary>
    /// Approval history entries for this submission
    /// </summary>
    [JsonPropertyName("approvalHistory")]
    public List<ApprovalHistoryItemDto>? ApprovalHistory { get; init; }

    /// <summary>
    /// Comments on this submission
    /// </summary>
    [JsonPropertyName("comments")]
    public List<CommentItemDto>? Comments { get; init; }

    /// <summary>
    /// Current step in the conversational submission flow (0-10)
    /// </summary>
    [JsonPropertyName("currentStep")]
    public int CurrentStep { get; init; }

    /// <summary>
    /// Submission number in CIQ-YYYY-XXXXX format
    /// </summary>
    [JsonPropertyName("submissionNumber")]
    public string? SubmissionNumber { get; init; }

    /// <summary>
    /// Assigned CIRCLE HEAD user ID for review
    /// </summary>
    [JsonPropertyName("assignedCircleHeadUserId")]
    public Guid? AssignedCircleHeadUserId { get; init; }

    /// <summary>
    /// Activity state/region where the work was performed
    /// </summary>
    [JsonPropertyName("activityState")]
    public string? ActivityState { get; init; }

    /// <summary>
    /// Selected PO ID from conversational flow
    /// </summary>
    [JsonPropertyName("selectedPOId")]
    public Guid? SelectedPOId { get; init; }

    /// <summary>
    /// Selected PO Number from conversational flow (for frontend PO selection matching)
    /// </summary>
    [JsonPropertyName("selectedPONumber")]
    public string? SelectedPONumber { get; init; }
}

/// <summary>
/// Document information within a submission detail response
/// </summary>
public class SubmissionDocumentDto
{
    /// <summary>
    /// Unique identifier of the document
    /// </summary>
    [JsonPropertyName("id")]
    public required Guid Id { get; init; }
    
    /// <summary>
    /// Type of document
    /// </summary>
    [JsonPropertyName("type")]
    public required string Type { get; init; }
    
    /// <summary>
    /// Original filename
    /// </summary>
    [JsonPropertyName("filename")]
    public required string Filename { get; init; }
    
    /// <summary>
    /// Blob storage URL
    /// </summary>
    [JsonPropertyName("blobUrl")]
    public required string BlobUrl { get; init; }
    
    /// <summary>
    /// Extraction confidence score
    /// </summary>
    [JsonPropertyName("extractionConfidence")]
    public double? ExtractionConfidence { get; init; }
    
    /// <summary>
    /// Extracted data as JSON string
    /// </summary>
    [JsonPropertyName("extractedData")]
    public string? ExtractedData { get; init; }
}

/// <summary>
/// Validation result information
/// </summary>
public class ValidationResultDto
{
    /// <summary>
    /// The document ID this validation belongs to
    /// </summary>
    [JsonPropertyName("documentId")]
    public Guid? DocumentId { get; init; }

    /// <summary>
    /// Whether all validations passed
    /// </summary>
    [JsonPropertyName("allValidationsPassed")]
    public required bool AllValidationsPassed { get; init; }
    
    /// <summary>
    /// Failure reason if validations failed
    /// </summary>
    [JsonPropertyName("failureReason")]
    public string? FailureReason { get; init; }
    
    /// <summary>
    /// SAP verification passed
    /// </summary>
    [JsonPropertyName("sapVerificationPassed")]
    public bool SapVerificationPassed { get; init; }
    
    /// <summary>
    /// Amount consistency passed
    /// </summary>
    [JsonPropertyName("amountConsistencyPassed")]
    public bool AmountConsistencyPassed { get; init; }
    
    /// <summary>
    /// Line item matching passed
    /// </summary>
    [JsonPropertyName("lineItemMatchingPassed")]
    public bool LineItemMatchingPassed { get; init; }
    
    /// <summary>
    /// Completeness check passed
    /// </summary>
    [JsonPropertyName("completenessCheckPassed")]
    public bool CompletenessCheckPassed { get; init; }
    
    /// <summary>
    /// Date validation passed
    /// </summary>
    [JsonPropertyName("dateValidationPassed")]
    public bool DateValidationPassed { get; init; }
    
    /// <summary>
    /// Vendor matching passed
    /// </summary>
    [JsonPropertyName("vendorMatchingPassed")]
    public bool VendorMatchingPassed { get; init; }
    
    /// <summary>
    /// Rule results JSON (proactive validation rules)
    /// </summary>
    [JsonPropertyName("ruleResultsJson")]
    public string? RuleResultsJson { get; init; }
    
    /// <summary>
    /// Detailed validation results with proactive, reactive, and checks
    /// </summary>
    [JsonPropertyName("validationDetailsJson")]
    public string? ValidationDetailsJson { get; init; }
}

/// <summary>
/// Confidence score information
/// </summary>
public class ConfidenceScoreDto
{
    /// <summary>
    /// Overall confidence score (0-100)
    /// </summary>
    [JsonPropertyName("overallConfidence")]
    public required double OverallConfidence { get; init; }
    
    /// <summary>
    /// PO document confidence score
    /// </summary>
    [JsonPropertyName("poConfidence")]
    public double? PoConfidence { get; init; }
    
    /// <summary>
    /// Invoice document confidence score
    /// </summary>
    [JsonPropertyName("invoiceConfidence")]
    public double? InvoiceConfidence { get; init; }
    
    /// <summary>
    /// Cost summary document confidence score
    /// </summary>
    [JsonPropertyName("costSummaryConfidence")]
    public double? CostSummaryConfidence { get; init; }
    
    /// <summary>
    /// Activity document confidence score
    /// </summary>
    [JsonPropertyName("activityConfidence")]
    public double? ActivityConfidence { get; init; }
    
    /// <summary>
    /// Photos confidence score
    /// </summary>
    [JsonPropertyName("photosConfidence")]
    public double? PhotosConfidence { get; init; }
}

/// <summary>
/// Recommendation information
/// </summary>
public class RecommendationDto
{
    /// <summary>
    /// Recommendation type (Approve, Review, Reject)
    /// </summary>
    [JsonPropertyName("type")]
    public required string Type { get; init; }
    
    /// <summary>
    /// Evidence supporting the recommendation
    /// </summary>
    [JsonPropertyName("evidence")]
    public string? Evidence { get; init; }
}

/// <summary>
/// Campaign (team) data within a submission
/// </summary>
public class CampaignDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; init; }
    
    [JsonPropertyName("campaignName")]
    public string? CampaignName { get; init; }
    
    [JsonPropertyName("teamCode")]
    public string? TeamCode { get; init; }
    
    [JsonPropertyName("startDate")]
    public DateTime? StartDate { get; init; }
    
    [JsonPropertyName("endDate")]
    public DateTime? EndDate { get; init; }
    
    [JsonPropertyName("workingDays")]
    public int? WorkingDays { get; init; }
    
    [JsonPropertyName("dealershipName")]
    public string? DealershipName { get; init; }
    
    [JsonPropertyName("dealershipAddress")]
    public string? DealershipAddress { get; init; }
    
    [JsonPropertyName("totalCost")]
    public decimal? TotalCost { get; init; }
    
    [JsonPropertyName("costSummaryFileName")]
    public string? CostSummaryFileName { get; init; }
    
    [JsonPropertyName("costSummaryBlobUrl")]
    public string? CostSummaryBlobUrl { get; init; }
    
    [JsonPropertyName("activitySummaryFileName")]
    public string? ActivitySummaryFileName { get; init; }
    
    [JsonPropertyName("activitySummaryBlobUrl")]
    public string? ActivitySummaryBlobUrl { get; init; }
    
    [JsonPropertyName("photos")]
    public List<CampaignPhotoDto> Photos { get; init; } = new();

    [JsonPropertyName("invoices")]
    public List<CampaignInvoiceDto> Invoices { get; init; } = new();
}

/// <summary>
/// Invoice data within a campaign response
/// </summary>
public class CampaignInvoiceDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; init; }

    [JsonPropertyName("invoiceNumber")]
    public string? InvoiceNumber { get; init; }

    [JsonPropertyName("vendorName")]
    public string? VendorName { get; init; }

    [JsonPropertyName("invoiceDate")]
    public DateTime? InvoiceDate { get; init; }

    [JsonPropertyName("gstNumber")]
    public string? GSTNumber { get; init; }

    [JsonPropertyName("totalAmount")]
    public decimal? TotalAmount { get; init; }

    [JsonPropertyName("fileName")]
    public string FileName { get; init; } = "";

    [JsonPropertyName("blobUrl")]
    public string BlobUrl { get; init; } = "";

    [JsonPropertyName("createdAt")]
    public DateTime CreatedAt { get; init; }

    [JsonPropertyName("updatedAt")]
    public DateTime? UpdatedAt { get; init; }
}

/// <summary>
/// Photo within a campaign
/// </summary>
public class CampaignPhotoDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; init; }
    
    [JsonPropertyName("fileName")]
    public string FileName { get; init; } = "";
    
    [JsonPropertyName("blobUrl")]
    public string BlobUrl { get; init; } = "";
    
    [JsonPropertyName("caption")]
    public string? Caption { get; init; }

    [JsonPropertyName("photoTimestamp")]
    public DateTime? PhotoTimestamp { get; init; }

    [JsonPropertyName("photoDateOverlay")]
    public string? PhotoDateOverlay { get; init; }
}

/// <summary>
/// Inline DTO for approval history items in submission detail response.
/// </summary>
public class ApprovalHistoryItemDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; init; }

    [JsonPropertyName("approverName")]
    public string? ApproverName { get; init; }

    [JsonPropertyName("approverRole")]
    public required string ApproverRole { get; init; }

    [JsonPropertyName("action")]
    public required string Action { get; init; }

    [JsonPropertyName("comments")]
    public string? Comments { get; init; }

    [JsonPropertyName("actionDate")]
    public DateTime ActionDate { get; init; }

    [JsonPropertyName("versionNumber")]
    public int VersionNumber { get; init; }
}

/// <summary>
/// Inline DTO for comment items in submission detail response.
/// </summary>
public class CommentItemDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; init; }

    [JsonPropertyName("userName")]
    public string? UserName { get; init; }

    [JsonPropertyName("userRole")]
    public required string UserRole { get; init; }

    [JsonPropertyName("commentText")]
    public required string CommentText { get; init; }

    [JsonPropertyName("commentDate")]
    public DateTime CommentDate { get; init; }

    [JsonPropertyName("versionNumber")]
    public int VersionNumber { get; init; }
}
