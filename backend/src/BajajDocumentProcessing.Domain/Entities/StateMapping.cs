using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Maps a state to its assigned Circle Head (ASM) and RA (HQ) users.
/// One record per state. Used for auto-assignment when a submission is created.
/// </summary>
public class StateMapping : BaseEntity
{
    /// <summary>
    /// Indian state name (e.g., "Maharashtra"). Unique per record.
    /// </summary>
    public string State { get; set; } = string.Empty;

    /// <summary>
    /// The Circle Head (ASM) user assigned to this state.
    /// Assigned to DocumentPackage.AssignedCircleHeadUserId at submission time.
    /// </summary>
    public Guid? CircleHeadUserId { get; set; }

    /// <summary>
    /// The RA (HQ) user assigned to this state.
    /// Assigned to DocumentPackage.AssignedRAUserId when Circle Head approves.
    /// </summary>
    public Guid? RAUserId { get; set; }

    /// <summary>
    /// Whether this mapping is active.
    /// </summary>
    public bool IsActive { get; set; } = true;
}
