namespace BajajDocumentProcessing.Application.DTOs.Documents;

/// <summary>
/// Invoice extracted data
/// </summary>
public class InvoiceData
{
    // Basic invoice information
    public string InvoiceNumber { get; set; } = string.Empty;
    public DateTime InvoiceDate { get; set; }
    
    // Agency information
    public string AgencyName { get; set; } = string.Empty;
    public string AgencyAddress { get; set; } = string.Empty;
    public string AgencyCode { get; set; } = string.Empty;
    
    // Billing information
    public string BillingName { get; set; } = string.Empty;
    public string BillingAddress { get; set; } = string.Empty;
    
    // Vendor information
    public string VendorName { get; set; } = string.Empty;
    public string VendorCode { get; set; } = string.Empty;
    
    // State and tax information
    public string StateName { get; set; } = string.Empty;
    public string StateCode { get; set; } = string.Empty;
    public string GSTNumber { get; set; } = string.Empty;
    public decimal GSTPercentage { get; set; }
    
    // HSN/SAC code
    public string HSNSACCode { get; set; } = string.Empty;
    
    // PO reference
    public string PONumber { get; set; } = string.Empty;
    
    // Line items and amounts
    public List<InvoiceLineItem> LineItems { get; set; } = new();
    public decimal SubTotal { get; set; }
    public decimal TaxAmount { get; set; }
    public decimal TotalAmount { get; set; }
    
    // Confidence and review flags
    public Dictionary<string, double> FieldConfidences { get; set; } = new();
    public bool IsFlaggedForReview { get; set; }
}

/// <summary>
/// Invoice line item
/// </summary>
public class InvoiceLineItem
{
    public string ItemCode { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal LineTotal { get; set; }
}
