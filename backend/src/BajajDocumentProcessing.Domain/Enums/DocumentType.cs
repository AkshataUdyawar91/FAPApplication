namespace BajajDocumentProcessing.Domain.Enums;

/// <summary>
/// Types of documents in the system
/// </summary>
public enum DocumentType
{
    PO = 1,
    Invoice = 2,
    CostSummary = 3,
    Activity = 4,
    Photo = 5,
    AdditionalDocument = 6,
    // CHANGE: Added EnquiryDump document type for Enquiry Dump Excel files
    EnquiryDump = 7
}
