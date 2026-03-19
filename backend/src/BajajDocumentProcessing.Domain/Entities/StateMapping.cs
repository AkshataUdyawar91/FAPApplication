using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Maps Indian states/UTs to dealers and CIRCLE HEAD users.
/// Used for dealer typeahead in conversational submission and CIRCLE HEAD auto-assignment at submit time.
/// Supports soft-delete via BaseEntity.IsDeleted.
/// </summary>
public class StateMapping : BaseEntity
{
    /// <summary>
    /// Indian state or union territory name (e.g., Maharashtra, Gujarat).
    /// </summary>
    public string State { get; set; } = string.Empty;

    /// <summary>
    /// Dealer code for the dealer in this state.
    /// </summary>
    public string DealerCode { get; set; } = string.Empty;

    /// <summary>
    /// Dealer name for display in typeahead results.
    /// </summary>
    public string DealerName { get; set; } = string.Empty;

    /// <summary>
    /// City where the dealer is located.
    /// </summary>
    public string? City { get; set; }

    /// <summary>
    /// CIRCLE HEAD user assigned to this state for submission review.
    /// </summary>
    public Guid? CircleHeadUserId { get; set; }

    /// <summary>
    /// RA user assigned to this state for second-level submission review.
    /// RA user assigned to this state for HQ-level review.
    /// </summary>
    public Guid? RAUserId { get; set; }

    /// <summary>
    /// Whether this mapping is active. Inactive mappings are excluded from queries.
    /// </summary>
    public bool IsActive { get; set; } = true;
}
