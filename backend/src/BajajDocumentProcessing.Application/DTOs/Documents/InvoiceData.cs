namespace BajajDocumentProcessing.Application.DTOs.Documents;

/// <summary>
/// Invoice extracted data
/// </summary>
public class InvoiceData
{
    /// <summary>
    /// Invoice number
    /// </summary>
    public string InvoiceNumber { get; set; } = string.Empty;
    
    /// <summary>
    /// Invoice date
    /// </summary>
    public DateTime InvoiceDate { get; set; }
    
    /// <summary>
    /// Agency name
    /// </summary>
    public string AgencyName { get; set; } = string.Empty;
    
    /// <summary>
    /// Agency address
    /// </summary>
    public string AgencyAddress { get; set; } = string.Empty;
    
    /// <summary>
    /// Agency code identifier
    /// </summary>
    public string AgencyCode { get; set; } = string.Empty;
    
    /// <summary>
    /// Billing entity name
    /// </summary>
    public string BillingName { get; set; } = string.Empty;
    
    /// <summary>
    /// Billing entity address
    /// </summary>
    public string BillingAddress { get; set; } = string.Empty;
    
    /// <summary>
    /// Vendor name
    /// </summary>
    public string VendorName { get; set; } = string.Empty;
    
    /// <summary>
    /// Vendor code identifier
    /// </summary>
    public string VendorCode { get; set; } = string.Empty;
    
    /// <summary>
    /// State name
    /// </summary>
    public string StateName { get; set; } = string.Empty;
    
    /// <summary>
    /// State code
    /// </summary>
    public string StateCode { get; set; } = string.Empty;
    
    /// <summary>
    /// GST registration number
    /// </summary>
    public string GSTNumber { get; set; } = string.Empty;
    
    /// <summary>
    /// GST percentage applied
    /// </summary>
    public decimal GSTPercentage { get; set; }
    
    /// <summary>
    /// HSN/SAC code for tax classification
    /// </summary>
    public string HSNSACCode { get; set; } = string.Empty;
    
    /// <summary>
    /// Purchase Order number referenced by this invoice
    /// </summary>
    public string PONumber { get; set; } = string.Empty;
    
    /// <summary>
    /// List of line items in the invoice
    /// </summary>
    public List<InvoiceLineItem> LineItems { get; set; } = new();
    
    /// <summary>
    /// Subtotal before tax
    /// </summary>
    public decimal SubTotal { get; set; }
    
    /// <summary>
    /// Total tax amount
    /// </summary>
    public decimal TaxAmount { get; set; }
    
    /// <summary>
    /// Total invoice amount including tax
    /// </summary>
    public decimal TotalAmount { get; set; }
    
    /// <summary>
    /// AI confidence scores for each extracted field (0-100)
    /// </summary>
    public Dictionary<string, double> FieldConfidences { get; set; } = new();
    
    /// <summary>
    /// Whether this document has been flagged for manual review
    /// </summary>
    public bool IsFlaggedForReview { get; set; }
}

/// <summary>
/// Invoice line item
/// </summary>
public class InvoiceLineItem
{
    /// <summary>
    /// Item code or SKU
    /// </summary>
    public string ItemCode { get; set; } = string.Empty;
    
    /// <summary>
    /// Item description
    /// </summary>
    public string Description { get; set; } = string.Empty;
    
    /// <summary>
    /// Quantity ordered
    /// </summary>
    public int Quantity { get; set; }
    
    /// <summary>
    /// Price per unit
    /// </summary>
    public decimal UnitPrice { get; set; }
    
    /// <summary>
    /// Total amount for this line item (Quantity × UnitPrice)
    /// </summary>
    public decimal LineTotal { get; set; }
}
