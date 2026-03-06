namespace BajajDocumentProcessing.Application.DTOs.Documents;

/// <summary>
/// Purchase Order extracted data
/// </summary>
public class POData
{
    public string PONumber { get; set; } = string.Empty;
    // CHANGE: Added all new fields to match Invoice-level extraction
    public string POType { get; set; } = string.Empty;
    public string AgencyCode { get; set; } = string.Empty;
    public string AgencyName { get; set; } = string.Empty;
    public string AgencyAddress { get; set; } = string.Empty;
    public string VendorName { get; set; } = string.Empty;
    public string VendorCode { get; set; } = string.Empty;
    public string VendorAddress { get; set; } = string.Empty;
    public string BuyerName { get; set; } = string.Empty;
    public string PurchasingOrg { get; set; } = string.Empty;
    public string StateName { get; set; } = string.Empty;
    public string StateCode { get; set; } = string.Empty;
    public string GSTNumber { get; set; } = string.Empty;
    public decimal GSTPercentage { get; set; }
    public string HSNSACCode { get; set; } = string.Empty;
    public string DeliveryTerms { get; set; } = string.Empty;
    public string PaymentTerms { get; set; } = string.Empty;
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
    // CHANGE: Added new line item fields
    public string Plant { get; set; } = string.Empty;
    public string TaxCode { get; set; } = string.Empty;
    public string Currency { get; set; } = string.Empty;
    public string HSNSACCode { get; set; } = string.Empty;
}
