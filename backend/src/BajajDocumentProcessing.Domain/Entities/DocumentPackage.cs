using BajajDocumentProcessing.Domain.Common;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents a document submission package containing multiple documents (PO, Invoice, Cost Summary, Activity, Photos).
/// Tracks the complete lifecycle from submission through validation, scoring, recommendation, and multi-level approval
/// </summary>
public class DocumentPackage : BaseEntity
{
    /// <summary>
    /// Gets or sets the unique identifier of the agency that submitted this package
    /// </summary>
    public Guid AgencyId { get; set; }
    
    /// <summary>
    /// Gets or sets the unique identifier of the agency user who submitted this package
    /// </summary>
    public Guid SubmittedByUserId { get; set; }
    
    /// <summary>
    /// Gets or sets the version number for tracking resubmissions (starts at 1, increments on resubmission)
    /// </summary>
    public int VersionNumber { get; set; } = 1;
    
    /// <summary>
    /// Gets or sets the current state of the package in the workflow (Draft, Uploaded, Extracting, Validating, etc.)
    /// </summary>
    public PackageState State { get; set; } = PackageState.Uploaded;

    /// <summary>
    /// Gets or sets the activity region/state where the work was performed (e.g., Maharashtra, Gujarat).
    /// Nullable until submit time when it becomes required.
    /// </summary>
    public string? ActivityState { get; set; }

    /// <summary>
    /// Gets or sets the submission number in CIQ-YYYY-XXXXX format (e.g., CIQ-2026-00042).
    /// Generated at submit time.
    /// </summary>
    public string? SubmissionNumber { get; set; }

    /// <summary>
    /// Gets or sets the current step in the conversational submission flow (0-9).
    /// Used for session resume.
    /// </summary>
    public int CurrentStep { get; set; } = 0;

    /// <summary>
    /// Gets or sets the unique identifier of the CIRCLE HEAD user assigned to review this submission.
    /// Auto-assigned at submit time via StateMapping.
    /// </summary>
    public Guid? AssignedCircleHeadUserId { get; set; }

    /// <summary>
    /// Gets or sets the unique identifier of the RA user assigned to review this submission.
    /// Auto-assigned at ASM approval time via StateMapping.
    /// Gets or sets the RA user assigned to review this package at HQ level.
    /// Auto-assigned when ASM approves via StateMapping.
    /// </summary>
    public Guid? AssignedRAUserId { get; set; }

    /// <summary>
    /// Gets or sets the unique identifier of the PO selected during conversational submission (Step 2).
    /// </summary>
    public Guid? SelectedPOId { get; set; }
    
    // ============ DEPRECATED FIELDS - TO BE REMOVED IN FUTURE MIGRATION ============
    // These fields are replaced by RequestApprovalHistory table
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the unique identifier of the user who reviewed this package (legacy field, use RequestApprovalHistory)
    // /// </summary>
    // public Guid? ReviewedByUserId { get; set; }
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the timestamp when the package was reviewed (legacy field, use RequestApprovalHistory)
    // /// </summary>
    // public DateTime? ReviewedAt { get; set; }
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the review notes provided by the reviewer (legacy field, use RequestApprovalHistory)
    // /// </summary>
    // public string? ReviewNotes { get; set; }
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the unique identifier of the ASM (Area Sales Manager) who reviewed this package (use RequestApprovalHistory)
    // /// </summary>
    // public Guid? ASMReviewedByUserId { get; set; }
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the timestamp when the ASM reviewed this package (use RequestApprovalHistory)
    // /// </summary>
    // public DateTime? ASMReviewedAt { get; set; }
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the review notes provided by the ASM (use RequestApprovalHistory)
    // /// </summary>
    // public string? ASMReviewNotes { get; set; }
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the unique identifier of the HQ user who reviewed this package (use RequestApprovalHistory)
    // /// </summary>
    // public Guid? HQReviewedByUserId { get; set; }
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the timestamp when the HQ user reviewed this package (use RequestApprovalHistory)
    // /// </summary>
    // public DateTime? HQReviewedAt { get; set; }
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the review notes provided by the HQ reviewer (use RequestApprovalHistory)
    // /// </summary>
    // public string? HQReviewNotes { get; set; }
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the number of times this package has been resubmitted after ASM rejection (use VersionNumber)
    // /// </summary>
    // public int? ResubmissionCount { get; set; } = 0;
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the number of times this package has been resubmitted after HQ rejection (use VersionNumber)
    // /// </summary>
    // public int? HQResubmissionCount { get; set; } = 0;
    
    // ============ DEPRECATED CAMPAIGN FIELDS - MOVED TO Teams TABLE ============
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the campaign start date (moved to Teams table)
    // /// </summary>
    // public DateTime? CampaignStartDate { get; set; }
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the campaign end date (moved to Teams table)
    // /// </summary>
    // public DateTime? CampaignEndDate { get; set; }
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the number of working days for the campaign (moved to Teams table)
    // /// </summary>
    // public int? CampaignWorkingDays { get; set; }
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the dealership/dealer name where the activity took place (moved to Teams table)
    // /// </summary>
    // public string? DealershipName { get; set; }
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the full address of the dealership (moved to Teams table)
    // /// </summary>
    // public string? DealershipAddress { get; set; }
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the GPS coordinates of the dealership location (moved to Teams table)
    // /// </summary>
    // public string? GPSLocation { get; set; }

    // ============ DEPRECATED ENQUIRY DOCUMENT FIELDS - MOVED TO EnquiryDocument TABLE ============
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the original filename of the enquiry document (moved to EnquiryDocument table)
    // /// </summary>
    // public string? EnquiryDocFileName { get; set; }
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the Azure Blob Storage URL for the enquiry document (moved to EnquiryDocument table)
    // /// </summary>
    // public string? EnquiryDocBlobUrl { get; set; }
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the MIME content type of the enquiry document (moved to EnquiryDocument table)
    // /// </summary>
    // public string? EnquiryDocContentType { get; set; }
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the file size in bytes of the enquiry document (moved to EnquiryDocument table)
    // /// </summary>
    // public long? EnquiryDocFileSizeBytes { get; set; }
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the JSON representation of extracted enquiry document data (moved to EnquiryDocument table)
    // /// </summary>
    // public string? EnquiryDocExtractedDataJson { get; set; }
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the AI confidence score for enquiry document extraction (moved to EnquiryDocument table)
    // /// </summary>
    // public double? EnquiryDocExtractionConfidence { get; set; }

    // ============ NAVIGATION PROPERTIES ============
    
    /// <summary>
    /// Gets or sets the agency that submitted this package
    /// </summary>
    public Agency Agency { get; set; } = null!;
    
    /// <summary>
    /// Gets or sets the agency user who submitted this package
    /// </summary>
    public User SubmittedBy { get; set; } = null!;
    
    // DEPRECATED NAVIGATION PROPERTIES - TO BE REMOVED
    // /// <summary>
    // /// DEPRECATED: Gets or sets the user who reviewed this package (legacy navigation property, use RequestApprovalHistory)
    // /// </summary>
    // public User? ReviewedBy { get; set; }
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the ASM user who reviewed this package (use RequestApprovalHistory)
    // /// </summary>
    // public User? ASMReviewedBy { get; set; }
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the HQ user who reviewed this package (use RequestApprovalHistory)
    // /// </summary>
    // public User? HQReviewedBy { get; set; }
    
    /// <summary>
    /// Gets or sets the Purchase Order document (one-to-one relationship)
    /// </summary>
    public PO? PO { get; set; }
    
    /// <summary>
    /// Gets or sets the Cost Summary document (one-to-one relationship)
    /// </summary>
    public CostSummary? CostSummary { get; set; }
    
    /// <summary>
    /// Gets or sets the Activity Summary document (one-to-one relationship)
    /// </summary>
    public ActivitySummary? ActivitySummary { get; set; }
    
    /// <summary>
    /// Gets or sets the Enquiry document (one-to-one relationship)
    /// </summary>
    public EnquiryDocument? EnquiryDocument { get; set; }
    
    /// <summary>
    /// Gets or sets the collection of additional supporting documents in this package
    /// </summary>
    public ICollection<AdditionalDocument> AdditionalDocuments { get; set; } = new List<AdditionalDocument>();
    
    /// <summary>
    /// Gets or sets the validation result for this package
    /// </summary>
    public ValidationResult? ValidationResult { get; set; }
    
    /// <summary>
    /// Gets or sets the AI-generated confidence score for this package
    /// </summary>
    public ConfidenceScore? ConfidenceScore { get; set; }
    
    /// <summary>
    /// Gets or sets the AI-generated approval recommendation for this package
    /// </summary>
    public Recommendation? Recommendation { get; set; }
    
    /// <summary>
    /// Gets or sets the collection of notifications related to this package
    /// </summary>
    public ICollection<Notification> Notifications { get; set; } = new List<Notification>();
    
    /// <summary>
    /// Gets or sets the collection of invoices in this package (hierarchical structure)
    /// </summary>
    public ICollection<Invoice> Invoices { get; set; } = new List<Invoice>();
    
    /// <summary>
    /// Gets or sets the collection of teams in this package (for easier querying)
    /// </summary>
    public ICollection<Teams> Teams { get; set; } = new List<Teams>();
    
    /// <summary>
    /// Gets or sets the collection of team photos in this package (for easier querying)
    /// </summary>
    public ICollection<TeamPhotos> TeamPhotos { get; set; } = new List<TeamPhotos>();
    
    /// <summary>
    /// Gets or sets the collection of approval history records for this package
    /// </summary>
    public ICollection<RequestApprovalHistory> RequestApprovalHistory { get; set; } = new List<RequestApprovalHistory>();
    
    /// <summary>
    /// Gets or sets the collection of comments on this package with versioning support
    /// </summary>
    public ICollection<RequestComments> RequestComments { get; set; } = new List<RequestComments>();
}
