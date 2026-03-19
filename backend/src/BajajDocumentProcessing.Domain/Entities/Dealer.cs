using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents a dealer/dealership.
/// Currently standalone; will be linked to Agency and StateMapping in future.
/// One state can have many dealers. One agency can have many dealers.
/// </summary>
public class Dealer : BaseEntity
{
    /// <summary>
    /// Unique dealer code (e.g., "DL001").
    /// </summary>
    public string DealerCode { get; set; } = string.Empty;

    /// <summary>
    /// Display name of the dealer.
    /// </summary>
    public string DealerName { get; set; } = string.Empty;

    /// <summary>
    /// State this dealer belongs to. Used to filter dealers when an agency selects a state.
    /// </summary>
    public string State { get; set; } = string.Empty;

    /// <summary>
    /// City where the dealer is located.
    /// </summary>
    public string? City { get; set; }

    /// <summary>
    /// Whether this dealer is active.
    /// </summary>
    public bool IsActive { get; set; } = true;
}
