using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents a vendor/supplier that appears on Purchase Orders.
/// Used to look up vendor contact emails for PO notification delivery.
/// </summary>
public class Vendor : BaseEntity
{
    /// <summary>
    /// Gets or sets the vendor code (e.g., "115287") — primary match key from PO extraction
    /// </summary>
    public string VendorCode { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the vendor name (e.g., "Swift Events") — secondary match key from PO extraction
    /// </summary>
    public string VendorName { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets whether this vendor is active
    /// </summary>
    public bool IsActive { get; set; } = true;

    /// <summary>
    /// Gets or sets the collection of contact emails for this vendor (1:many)
    /// </summary>
    public ICollection<VendorContact> Contacts { get; set; } = new List<VendorContact>();
}
