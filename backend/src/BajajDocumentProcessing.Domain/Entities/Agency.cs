using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents an agency/supplier entity with unique supplier code.
/// Agencies submit document packages and are linked to users, POs, and packages.
/// </summary>
public class Agency : BaseEntity
{
    /// <summary>
    /// Gets or sets the unique supplier code identifier for the agency
    /// </summary>
    public string SupplierCode { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets the agency/supplier name
    /// </summary>
    public string SupplierName { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the collection of users belonging to this agency
    /// </summary>
    public ICollection<User> Users { get; set; } = new List<User>();
    
    /// <summary>
    /// Gets or sets the collection of document packages submitted by this agency
    /// </summary>
    public ICollection<DocumentPackage> DocumentPackages { get; set; } = new List<DocumentPackage>();
    
    // TODO: Uncomment when PO entity is created in Task 1.3
    // /// <summary>
    // /// Gets or sets the collection of purchase orders linked to this agency
    // /// </summary>
    // public ICollection<PO> POs { get; set; } = new List<PO>();
}
