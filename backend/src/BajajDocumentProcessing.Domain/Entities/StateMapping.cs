using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Maps a state to its assigned Circle Head (ASM) and RA (HQ) users.
/// One record per state. Used for auto-assignment when a submission is created.
/// </summary>
public class StateMapping : BaseEntity
{
    public string State { get; set; } = string.Empty;

    public string? DealerCode { get; set; }

    public string? DealerName { get; set; }

    public string? City { get; set; }

    public Guid? CircleHeadUserId { get; set; }

    public Guid? RAUserId { get; set; }

    public bool IsActive { get; set; } = true;
}
