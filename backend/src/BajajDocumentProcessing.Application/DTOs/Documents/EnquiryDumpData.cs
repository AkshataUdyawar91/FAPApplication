namespace BajajDocumentProcessing.Application.DTOs.Documents;

// CHANGE: New DTO for Enquiry Dump Excel extraction
/// <summary>
/// Enquiry Dump extracted data from Excel files
/// </summary>
public class EnquiryDumpData
{
    public string? State { get; set; }
    public List<EnquiryRecord> Records { get; set; } = new();
    public int TotalRecords { get; set; }
    public Dictionary<string, double> FieldConfidences { get; set; } = new();
    public bool IsFlaggedForReview { get; set; }
}

// CHANGE: New class for individual enquiry record
/// <summary>
/// Individual enquiry record from the dump
/// </summary>
public class EnquiryRecord
{
    public string? State { get; set; }
    public DateTime? Date { get; set; }
    public string? DealerCode { get; set; }
    public string? DealerName { get; set; }
    public string? District { get; set; }
    public string? Pincode { get; set; }
    public string? CustomerName { get; set; }
    public string? CustomerNumber { get; set; }
    public string? TestRideTaken { get; set; }
}
