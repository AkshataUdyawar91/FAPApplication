namespace BajajDocumentProcessing.Application.DTOs.Documents;

/// <summary>
/// Invoice extracted data
/// </summary>
public class InvoiceData
{
    public string InvoiceNumber { get; set; } = string.Empty;
    public string VendorName { get; set; } = string.Empty;
    public DateTime InvoiceDate { get; set; }
    public List<InvoiceLineItem> LineItems { get; set; } = new();
    public decimal SubTotal { get; set; }
    public decimal TaxAmount { get; set; }
    public decimal TotalAmount { get; set; }
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
