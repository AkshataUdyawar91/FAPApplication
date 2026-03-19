using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Master data mapping Indian states/UTs to their cities.
/// One state has many cities.
/// Used for city dropdowns in submission forms.
/// </summary>
public class StateCity : BaseEntity
{
    /// <summary>
    /// Indian state or union territory name (e.g., "Maharashtra").
    /// </summary>
    public string State { get; set; } = string.Empty;

    /// <summary>
    /// City name within the state (e.g., "Pune").
    /// </summary>
    public string City { get; set; } = string.Empty;

    /// <summary>
    /// Whether this record is active.
    /// </summary>
    public bool IsActive { get; set; } = true;
}
