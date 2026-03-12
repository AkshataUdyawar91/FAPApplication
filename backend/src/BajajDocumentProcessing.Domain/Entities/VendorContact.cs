using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents a contact email address for a vendor.
/// Multiple contacts can exist per vendor (1:many relationship with Vendor).
/// </summary>
public class VendorContact : BaseEntity
{
    /// <summary>
    /// Gets or sets the vendor this contact belongs to
    /// </summary>
    public Guid VendorId { get; set; }

    /// <summary>
    /// Gets or sets the contact person's name
    /// </summary>
    public string ContactName { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the email address for this contact
    /// </summary>
    public string Email { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets whether this contact is active
    /// </summary>
    public bool IsActive { get; set; } = true;

    /// <summary>
    /// Navigation property to the parent vendor
    /// </summary>
    public Vendor Vendor { get; set; } = null!;
}
