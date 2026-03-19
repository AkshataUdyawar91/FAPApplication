using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Maps Indian states/UTs to CIRCLE HEAD and RA users for approval routing.
/// Used for CIRCLE HEAD auto-assignment at submit time.
/// Dealer data has been moved to the Dealers table.
/// Supports soft-delete via BaseEntity.IsDeleted.
/// </summary>
public class StateMapping : BaseEntity
{
    /// <summary>
    /// Indian state or union territory name (e.g., Maharashtra, Gujarat).
    /// </summary>
    public string State { get; set; } = string.Empty;

    /// <summary>
    /// CIRCLE HEAD user assigned to this state for submission review.
    /// </summary>
    public Guid? CircleHeadUserId { get; set; }

    /// <summary>
    /// RA user assigned to this state for second-level submission review.
    /// </summary>
    public Guid? RAUserId { get; set; }

    /// <summary>
    /// Whether this mapping is active. Inactive mappings are excluded from queries.
    /// </summary>
    public bool IsActive { get; set; } = true;
}
