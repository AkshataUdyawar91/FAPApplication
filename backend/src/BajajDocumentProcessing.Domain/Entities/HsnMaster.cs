using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// HSN/SAC code reference data
/// </summary>
public class HsnMaster : BaseEntity
{
    /// <summary>
    /// HSN or SAC code (e.g., "8703", "995411")
    /// </summary>
    public string Code { get; set; } = string.Empty;

    /// <summary>
    /// Description of the HSN/SAC code
    /// </summary>
    public string Description { get; set; } = string.Empty;

    /// <summary>
    /// Whether this record is active
    /// </summary>
    public bool IsActive { get; set; } = true;
}
