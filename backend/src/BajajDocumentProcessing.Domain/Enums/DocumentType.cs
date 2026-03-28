namespace BajajDocumentProcessing.Domain.Enums;

/// <summary>
/// Types of documents in the system for ValidationResult polymorphic relationships
/// </summary>
public enum DocumentType
{
    PO = 1,
    Invoice = 2,
    CostSummary = 3,
    ActivitySummary = 4,
    EnquiryDocument = 5,
    TeamPhoto = 6,
    AdditionalDocument = 7
}
