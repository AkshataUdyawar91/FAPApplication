namespace BajajDocumentProcessing.Application.DTOs.Documents;

/// <summary>
/// Purchase Order extracted data
/// </summary>
public class POData
{
    public string PONumber { get; set; } = string.Empty;
    public string AgencyCode { get; set; } = string.Empty;
    public string VendorName { get; set; } = string.Empty;
    public DateTime PODate { get; set; }
    public List<POLineItem> LineItems { get; set; } = new();
    public decimal TotalAmount { get; set; }
    public Dictionary<string, double> FieldConfidences { get; set; } = new();
    public bool IsFlaggedForReview { get; set; }
}

/// <summary>
/// Purchase Order line item
/// </summary>
public class POLineItem
{
    public string ItemCode { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal LineTotal { get; set; }
}
