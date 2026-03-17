namespace BajajDocumentProcessing.Application.DTOs.Documents;

/// <summary>
/// Purchase Order extracted data
/// </summary>
public class POData
{
    /// <summary>
    /// Purchase Order number
    /// </summary>
    public string PONumber { get; set; } = string.Empty;
    
    /// <summary>
    /// Type of Purchase Order
    /// </summary>
    public string POType { get; set; } = string.Empty;
    
    /// <summary>
    /// Agency code identifier
    /// </summary>
    public string AgencyCode { get; set; } = string.Empty;
    
    /// <summary>
    /// Agency name
    /// </summary>
    public string AgencyName { get; set; } = string.Empty;
    
    /// <summary>
    /// Agency address
    /// </summary>
    public string AgencyAddress { get; set; } = string.Empty;
    
    /// <summary>
    /// Vendor name
    /// </summary>
    public string VendorName { get; set; } = string.Empty;
    
    /// <summary>
    /// Vendor code identifier
    /// </summary>
    public string VendorCode { get; set; } = string.Empty;
    
    /// <summary>
    /// Vendor address
    /// </summary>
    public string VendorAddress { get; set; } = string.Empty;
    
    /// <summary>
    /// Buyer name
    /// </summary>
    public string BuyerName { get; set; } = string.Empty;
    
    /// <summary>
    /// Purchasing organization
    /// </summary>
    public string PurchasingOrg { get; set; } = string.Empty;
    
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
    /// Delivery terms
    /// </summary>
    public string DeliveryTerms { get; set; } = string.Empty;
    
    /// <summary>
    /// Payment terms
    /// </summary>
    public string PaymentTerms { get; set; } = string.Empty;
    
    /// <summary>
    /// Purchase Order date
    /// </summary>
    public DateTime PODate { get; set; }
    
    /// <summary>
    /// List of line items in the Purchase Order
    /// </summary>
    public List<POLineItem> LineItems { get; set; } = new();
    
    /// <summary>
    /// Total Purchase Order amount
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
/// Purchase Order line item
/// </summary>
public class POLineItem
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
    
    /// <summary>
    /// Plant or facility code
    /// </summary>
    public string Plant { get; set; } = string.Empty;
    
    /// <summary>
    /// Tax code applied to this line item
    /// </summary>
    public string TaxCode { get; set; } = string.Empty;
    
    /// <summary>
    /// Currency code (e.g., "INR", "USD")
    /// </summary>
    public string Currency { get; set; } = string.Empty;
    
    /// <summary>
    /// HSN/SAC code for this line item
    /// </summary>
    public string HSNSACCode { get; set; } = string.Empty;
}
