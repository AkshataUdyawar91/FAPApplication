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
    /// Gets or sets the unique identifier of the agency user who submitted this package
    /// </summary>
    public Guid SubmittedByUserId { get; set; }
    
    /// <summary>
    /// Gets or sets the unique identifier of the user who reviewed this package (legacy field, use ASMReviewedByUserId or HQReviewedByUserId)
    /// </summary>
    public Guid? ReviewedByUserId { get; set; }
    
    /// <summary>
    /// Gets or sets the current state of the package in the workflow (Uploaded, Extracting, Validating, etc.)
    /// </summary>
    public PackageState State { get; set; } = PackageState.Uploaded;
    
    /// <summary>
    /// Gets or sets the timestamp when the package was reviewed (legacy field)
    /// </summary>
    public DateTime? ReviewedAt { get; set; }
    
    /// <summary>
    /// Gets or sets the review notes provided by the reviewer (legacy field)
    /// </summary>
    public string? ReviewNotes { get; set; }
    
    /// <summary>
    /// Gets or sets the unique identifier of the ASM (Area Sales Manager) who reviewed this package
    /// </summary>
    public Guid? ASMReviewedByUserId { get; set; }
    
    /// <summary>
    /// Gets or sets the timestamp when the ASM reviewed this package
    /// </summary>
    public DateTime? ASMReviewedAt { get; set; }
    
    /// <summary>
    /// Gets or sets the review notes provided by the ASM
    /// </summary>
    public string? ASMReviewNotes { get; set; }
    
    /// <summary>
    /// Gets or sets the unique identifier of the HQ user who reviewed this package
    /// </summary>
    public Guid? HQReviewedByUserId { get; set; }
    
    /// <summary>
    /// Gets or sets the timestamp when the HQ user reviewed this package
    /// </summary>
    public DateTime? HQReviewedAt { get; set; }
    
    /// <summary>
    /// Gets or sets the review notes provided by the HQ reviewer
    /// </summary>
    public string? HQReviewNotes { get; set; }
    
    /// <summary>
    /// Gets or sets the number of times this package has been resubmitted after ASM rejection
    /// </summary>
    public int? ResubmissionCount { get; set; } = 0;
    
    /// <summary>
    /// Gets or sets the number of times this package has been resubmitted after HQ rejection
    /// </summary>
    public int? HQResubmissionCount { get; set; } = 0;
    
    /// <summary>
    /// Gets or sets the campaign start date
    /// </summary>
    public DateTime? CampaignStartDate { get; set; }
    
    /// <summary>
    /// Gets or sets the campaign end date
    /// </summary>
    public DateTime? CampaignEndDate { get; set; }
    
    /// <summary>
    /// Gets or sets the number of working days for the campaign (excluding weekends)
    /// </summary>
    public int? CampaignWorkingDays { get; set; }
    
    /// <summary>
    /// Gets or sets the dealership/dealer name where the activity took place
    /// </summary>
    public string? DealershipName { get; set; }
    
    /// <summary>
    /// Gets or sets the full address of the dealership
    /// </summary>
    public string? DealershipAddress { get; set; }
    
    /// <summary>
    /// Gets or sets the GPS coordinates of the dealership location
    /// </summary>
    public string? GPSLocation { get; set; }

    // ============ Additional Documents (at PO level) ============
    
    /// <summary>
    /// Gets or sets the original filename of the enquiry document
    /// </summary>
    public string? EnquiryDocFileName { get; set; }
    
    /// <summary>
    /// Gets or sets the Azure Blob Storage URL for the enquiry document
    /// </summary>
    public string? EnquiryDocBlobUrl { get; set; }
    
    /// <summary>
    /// Gets or sets the MIME content type of the enquiry document
    /// </summary>
    public string? EnquiryDocContentType { get; set; }
    
    /// <summary>
    /// Gets or sets the file size in bytes of the enquiry document
    /// </summary>
    public long? EnquiryDocFileSizeBytes { get; set; }
    
    /// <summary>
    /// Gets or sets the JSON representation of extracted enquiry document data
    /// </summary>
    public string? EnquiryDocExtractedDataJson { get; set; }
    
    /// <summary>
    /// Gets or sets the AI confidence score for enquiry document extraction
    /// </summary>
    public double? EnquiryDocExtractionConfidence { get; set; }

    /// <summary>
    /// Gets or sets the agency user who submitted this package
    /// </summary>
    public User SubmittedBy { get; set; } = null!;
    
    /// <summary>
    /// Gets or sets the user who reviewed this package (legacy navigation property)
    /// </summary>
    public User? ReviewedBy { get; set; }
    
    /// <summary>
    /// Gets or sets the ASM user who reviewed this package
    /// </summary>
    public User? ASMReviewedBy { get; set; }
    
    /// <summary>
    /// Gets or sets the HQ user who reviewed this package
    /// </summary>
    public User? HQReviewedBy { get; set; }
    
    /// <summary>
    /// Gets or sets the collection of documents in this package
    /// </summary>
    public ICollection<Document> Documents { get; set; } = new List<Document>();
    
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
    /// Gets or sets the collection of campaigns in this package (for easier querying)
    /// </summary>
    public ICollection<Campaign> Campaigns { get; set; } = new List<Campaign>();
    
    /// <summary>
    /// Gets or sets the collection of campaign photos in this package (for easier querying)
    /// </summary>
    public ICollection<CampaignPhoto> CampaignPhotos { get; set; } = new List<CampaignPhoto>();
    
    /// <summary>
    /// Gets or sets the collection of campaign invoices in this package (for easier querying)
    /// </summary>
    public ICollection<CampaignInvoice> CampaignInvoices { get; set; } = new List<CampaignInvoice>();
    
    /// <summary>
    /// Gets or sets the collection of approval workflow actions (approve, reject, resubmit) for this package's audit trail
    /// </summary>
    public ICollection<ApprovalAction> ApprovalActions { get; set; } = new List<ApprovalAction>();
}
